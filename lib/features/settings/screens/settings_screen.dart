import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xscan/core/providers/settings_provider.dart';
import 'package:xscan/core/services/backup_service.dart';
import 'package:xscan/core/services/biometric_service.dart';
import 'package:xscan/core/providers/document_provider.dart';
import 'package:xscan/features/scanner/services/ocr_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _showTextInputDialog(
    BuildContext context, 
    String title, 
    String? initialValue, 
    Function(String?) onSave,
    {bool isPassword = false}
  ) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: 'Value',
            helperText: 'Leave empty to disable',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      onSave(result.trim().isEmpty ? null : result.trim());
    }
  }

  Future<void> _backup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Creating backup...')));
    try {
      final zipPath = await BackupService.createBackup();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(zipPath)],
          text: 'XScan backup',
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    }
  }

  Future<void> _restore(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'This replaces your current documents and database with the '
          'contents of the backup. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    const group = XTypeGroup(label: 'Backup', extensions: ['zip']);
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Restoring...')));
    try {
      await BackupService.restoreBackup(file.path);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore complete'),
          content: const Text(
            'Please fully close and reopen XScan to load the restored data.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final pdfPassword = ref.watch(pdfPasswordProvider);
    final pdfWatermark = ref.watch(pdfWatermarkProvider);
    final appLock = ref.watch(appLockProvider);
    final dynamicColor = ref.watch(dynamicColorProvider);
    final ocrScript = ref.watch(ocrScriptProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Appearance',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Theme Mode'),
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              onChanged: (ThemeMode? newMode) {
                if (newMode != null) {
                  ref.read(themeModeProvider.notifier).setThemeMode(newMode);
                }
              },
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('System Default')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.palette),
            title: const Text('Dynamic Color'),
            subtitle: const Text('Match Android Material You wallpaper colors'),
            value: dynamicColor,
            onChanged: (value) =>
                ref.read(dynamicColorProvider.notifier).setEnabled(value),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Scanning',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.translate),
            title: const Text('Default OCR Script'),
            subtitle: const Text(
                'Text recognition script. Use Latin for English & most European languages.'),
            trailing: DropdownButton<String>(
              value: ocrScript,
              onChanged: (val) {
                if (val != null) {
                  ref.read(ocrScriptProvider.notifier).setScript(val);
                }
              },
              items: OcrService.scripts.keys
                  .map((k) => DropdownMenuItem(
                      value: k, child: Text(_ocrScriptLabel(k))))
                  .toList(),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Security',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Biometric App Lock'),
            subtitle: const Text('Require fingerprint / PIN to open XScan'),
            value: appLock,
            onChanged: (value) async {
              if (value) {
                final available = await BiometricService().isAvailable();
                if (!available) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No biometrics / device lock set up.'),
                      ),
                    );
                  }
                  return;
                }
              }
              ref.read(appLockProvider.notifier).setEnabled(value);
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Premium PDF Export Options',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('PDF Password Protection'),
            subtitle: Text(pdfPassword != null ? 'Enabled' : 'Disabled'),
            trailing: pdfPassword != null 
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () => ref.read(pdfPasswordProvider.notifier).setPassword(null),
                  )
                : null,
            onTap: () => _showTextInputDialog(
              context,
              'Set PDF Password',
              pdfPassword,
              (val) => ref.read(pdfPasswordProvider.notifier).setPassword(val),
              isPassword: true,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.branding_watermark),
            title: const Text('PDF Watermark'),
            subtitle: Text(pdfWatermark ?? 'Disabled'),
            trailing: pdfWatermark != null 
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () => ref.read(pdfWatermarkProvider.notifier).setWatermark(null),
                  )
                : null,
            onTap: () => _showTextInputDialog(
              context,
              'Set Watermark Text',
              pdfWatermark,
              (val) => ref.read(pdfWatermarkProvider.notifier).setWatermark(val),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Backup & Restore',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Back up data'),
            subtitle: const Text('Export scans, PDFs & database to a .zip'),
            onTap: () => _backup(context),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore data'),
            subtitle: const Text('Import from a backup .zip'),
            onTap: () => _restore(context),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Storage',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Empty Trash'),
            subtitle: const Text('Permanently delete & securely wipe trashed items'),
            onTap: () => _emptyTrash(context, ref),
          ),
        ],
      ),
    );
  }

  String _ocrScriptLabel(String key) {
    switch (key) {
      case 'Latin':
        return 'Latin (English & European)';
      default:
        return key;
    }
  }

  Future<void> _emptyTrash(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empty Trash?'),
        content: const Text(
            'This permanently deletes all trashed documents and securely wipes their files.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    await ref.read(isarServiceProvider).emptyTrash();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Trash emptied')));
  }
}
