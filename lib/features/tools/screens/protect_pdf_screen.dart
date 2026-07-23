import 'dart:io';

import 'package:flutter/material.dart';

import 'package:xscan/core/services/pdf_tools_service.dart';
import 'package:xscan/features/tools/widgets/pdf_source_picker.dart';
import 'package:xscan/features/tools/widgets/tool_result_sheet.dart';

/// Add or remove a password on a PDF.
class ProtectPdfScreen extends StatefulWidget {
  const ProtectPdfScreen({super.key});

  @override
  State<ProtectPdfScreen> createState() => _ProtectPdfScreenState();
}

class _ProtectPdfScreenState extends State<ProtectPdfScreen> {
  final _service = PdfToolsService();
  final _userPasswordController = TextEditingController();
  final _ownerPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _currentController = TextEditingController();
  String? _path;
  bool _remove = false;
  bool _busy = false;
  bool _obscure = true;
  bool _useOwnerPassword = false;
  bool _restrictPrinting = false;
  bool _restrictCopying = false;
  bool _restrictEditing = false;

  @override
  void dispose() {
    _userPasswordController.dispose();
    _ownerPasswordController.dispose();
    _confirmController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final path = await pickInAppPdf(context);
    if (path == null) return;
    setState(() => _path = path);
  }

  Future<void> _run() async {
    if (_path == null) return;
    setState(() => _busy = true);
    try {
      final String out;
      if (_remove) {
        out = await _service.removePassword(_path!, _currentController.text);
      } else {
        out = await _service.setPassword(
          _path!,
          _userPasswordController.text,
          ownerPassword: _useOwnerPassword && _ownerPasswordController.text.isNotEmpty
              ? _ownerPasswordController.text
              : null,
          currentPassword: _currentController.text.isEmpty
              ? null
              : _currentController.text,
          restrictPrint: _restrictPrinting,
          restrictCopy: _restrictCopying,
          restrictEdit: _restrictEditing,
        );
      }
      if (!mounted) return;
      setState(() => _busy = false);
      await showPdfResult(context, out);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed (wrong password?): $e')),
      );
    }
  }

  bool get _canRun {
    if (_path == null || _busy) return false;
    if (_remove) return _currentController.text.isNotEmpty;
    if (_userPasswordController.text.length < 4) return false;
    if (_userPasswordController.text != _confirmController.text) return false;
    if (_useOwnerPassword && _ownerPasswordController.text.isEmpty) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Protect PDF')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.file_open),
              label: Text(_path == null
                  ? 'Choose PDF'
                  : _path!.split(Platform.pathSeparator).last),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Set password')),
                ButtonSegment(value: true, label: Text('Remove password')),
              ],
              selected: {_remove},
              onSelectionChanged: (s) => setState(() => _remove = s.first),
            ),
            const SizedBox(height: 16),
            if (_remove)
              TextField(
                controller: _currentController,
                obscureText: _obscure,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Current password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              )
            else ...[
              // User (open) password
              TextField(
                controller: _userPasswordController,
                obscureText: _obscure,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Open password (min 4 chars)',
                  helperText: 'Required to open the PDF',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Confirm password
              TextField(
                controller: _confirmController,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  errorText: _confirmController.text.isNotEmpty &&
                          _confirmController.text != _userPasswordController.text
                      ? 'Passwords do not match'
                      : null,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Owner password toggle
              SwitchListTile(
                title: const Text('Set owner password'),
                subtitle: const Text('Controls permissions (print, copy, edit)',
                    style: TextStyle(fontSize: 12)),
                value: _useOwnerPassword,
                onChanged: (v) => setState(() => _useOwnerPassword = v),
                contentPadding: EdgeInsets.zero,
              ),
              if (_useOwnerPassword) ...[
                TextField(
                  controller: _ownerPasswordController,
                  obscureText: true,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Owner password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Permission restrictions
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Restrictions',
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: const Text('Restrict printing'),
                        value: _restrictPrinting,
                        onChanged: (v) =>
                            setState(() => _restrictPrinting = v ?? false),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        title: const Text('Restrict copying'),
                        value: _restrictCopying,
                        onChanged: (v) =>
                            setState(() => _restrictCopying = v ?? false),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        title: const Text('Restrict editing'),
                        value: _restrictEditing,
                        onChanged: (v) =>
                            setState(() => _restrictEditing = v ?? false),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),

              // Current password (if already protected)
              const SizedBox(height: 12),
              TextField(
                controller: _currentController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password (if already protected)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _canRun ? _run : null,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_remove ? Icons.lock_open : Icons.lock),
              label: Text(_remove ? 'Remove Password' : 'Protect PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
