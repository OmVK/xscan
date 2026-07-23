import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xscan/core/data/models/scan_document.dart';
import 'package:xscan/core/providers/document_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class BarcodeHistoryScreen extends ConsumerStatefulWidget {
  const BarcodeHistoryScreen({super.key});

  @override
  ConsumerState<BarcodeHistoryScreen> createState() =>
      _BarcodeHistoryScreenState();
}

class _BarcodeHistoryScreenState extends ConsumerState<BarcodeHistoryScreen> {
  String _search = '';
  String? _formatFilter;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(filteredDocumentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode History'),
        actions: [
          if (_search.isNotEmpty || _formatFilter != null)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () {
                setState(() {
                  _search = '';
                  _formatFilter = null;
                  _searchCtrl.clear();
                });
              },
              tooltip: 'Clear filters',
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search barcodes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _search = '';
                            _searchCtrl.clear();
                          });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _formatFilter == null,
                  onSelected: (_) => setState(() => _formatFilter = null),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                for (final fmt in [
                  'QR Code',
                  'EAN-13',
                  'UPC-A',
                  'Code 128',
                  'Code 39',
                  'ISBN',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(fmt),
                      selected: _formatFilter == fmt,
                      onSelected: (_) =>
                          setState(() => _formatFilter = fmt),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: docsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (docs) {
                final barcodes = docs
                    .where((d) =>
                        d.category == 'Barcodes' && d.fileType == 'barcode')
                    .where((d) {
                  if (_search.isNotEmpty) {
                    final matchesSearch = d.title
                            .toLowerCase()
                            .contains(_search) ||
                        (d.ocrText?.toLowerCase().contains(_search) ?? false) ||
                        (d.barcodeFormat?.toLowerCase().contains(_search) ??
                            false);
                    if (!matchesSearch) return false;
                  }
                  if (_formatFilter != null) {
                    if (d.barcodeFormat != _formatFilter) return false;
                  }
                  return true;
                }).toList()
                  ..sort((a, b) => b.dateCreated.compareTo(a.dateCreated));

                if (barcodes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code,
                            size: 80,
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Text(
                          _search.isNotEmpty || _formatFilter != null
                              ? 'No barcodes match your filters'
                              : 'No scanned barcodes yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: barcodes.length,
                  itemBuilder: (context, index) =>
                      _buildBarcodeCard(barcodes[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeCard(ScanDocument doc) {
    final value = doc.ocrText ?? '';
    final format = doc.barcodeFormat ?? 'Unknown';
    final date = doc.dateCreated;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.qr_code, color: scheme.onPrimaryContainer),
        ),
        title: Text(
          doc.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    format,
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleAction(action, doc),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'copy', child: Text('Copy value')),
            if (_isUrl(value))
              const PopupMenuItem(value: 'open', child: Text('Open link')),
            const PopupMenuItem(value: 'share', child: Text('Share')),
            const PopupMenuItem(
                value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  bool _isUrl(String value) {
    final lower = value.toLowerCase().trim();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  Future<void> _handleAction(String action, ScanDocument doc) async {
    final value = doc.ocrText ?? '';

    switch (action) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: value));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied to clipboard')),
          );
        }
        break;
      case 'open':
        final uri = Uri.parse(value);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        break;
      case 'share':
        await SharePlus.instance.share(ShareParams(text: value));
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete barcode?'),
            content: const Text('This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await ref.read(isarServiceProvider).deleteDocument(doc.id);
        }
        break;
    }
  }
}
