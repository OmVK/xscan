import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xscan/core/services/app_storage.dart';
import 'package:xscan/features/tools/services/tool_io.dart';

class _HistoryEntry {
  _HistoryEntry({
    required this.content,
    required this.type,
    required this.name,
    required this.timestamp,
    this.thumbnailPath,
    this.fullPath,
  });

  String content;
  String type;
  String name;
  int timestamp;
  String? thumbnailPath;
  String? fullPath;

  Map<String, dynamic> toJson() => {
        'content': content,
        'type': type,
        'name': name,
        'timestamp': timestamp,
        'thumbnailPath': thumbnailPath,
        'fullPath': fullPath,
      };

  factory _HistoryEntry.fromJson(Map<String, dynamic> j) => _HistoryEntry(
        content: j['content'] ?? '',
        type: j['type'] ?? '',
        name: j['name'] ?? '',
        timestamp: j['timestamp'] ?? 0,
        thumbnailPath: j['thumbnailPath'],
        fullPath: j['fullPath'],
      );
}

class QrHistoryScreen extends StatefulWidget {
  const QrHistoryScreen({super.key});

  @override
  State<QrHistoryScreen> createState() => _QrHistoryScreenState();
}

class _QrHistoryScreenState extends State<QrHistoryScreen> {
  List<_HistoryEntry> _entries = [];
  List<_HistoryEntry> _filtered = [];
  bool _loading = true;
  String _search = '';
  String? _typeFilter;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<Directory> _historyDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/qr_history');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _load() async {
    final dir = await _historyDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));

    final entries = <_HistoryEntry>[];
    for (final f in files) {
      try {
        final json = jsonDecode(await f.readAsString());
        entries.add(_HistoryEntry.fromJson(json));
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
    _applyFilter();
  }

  void _applyFilter() {
    final q = _search.toLowerCase();
    setState(() {
      _filtered = _entries.where((e) {
        if (_typeFilter != null && e.type != _typeFilter) return false;
        if (q.isEmpty) return true;
        return e.name.toLowerCase().contains(q) || e.content.toLowerCase().contains(q);
      }).toList();
    });
  }

  Future<void> _delete(_HistoryEntry entry) async {
    final dir = await _historyDir();
    final files = dir.listSync().whereType<File>().where((f) {
      try {
        final json = jsonDecode(f.readAsStringSync());
        final e = _HistoryEntry.fromJson(json);
        return e.timestamp == entry.timestamp && e.name == entry.name;
      } catch (_) {
        return false;
      }
    }).toList();
    for (final f in files) {
      await f.delete();
    }
    if (entry.thumbnailPath != null) {
      final t = File(entry.thumbnailPath!);
      if (await t.exists()) await t.delete();
    }
    if (entry.fullPath != null) {
      final fp = File(entry.fullPath!);
      if (await fp.exists()) await fp.delete();
    }
    _load();
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'url':
        return 'URL';
      case 'text':
        return 'Text';
      case 'wifi':
        return 'Wi-Fi';
      case 'contact':
        return 'Contact';
      case 'email':
        return 'Email';
      case 'sms':
        return 'SMS';
      case 'phone':
        return 'Phone';
      case 'location':
        return 'Location';
      case 'event':
        return 'Event';
      case 'crypto':
        return 'Crypto';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = _entries.map((e) => e.type).toSet().toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('QR History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name or content...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                          _applyFilter();
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                setState(() => _search = v);
                _applyFilter();
              },
            ),
          ),
          if (types.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _typeFilter == null,
                    onSelected: (_) {
                      setState(() => _typeFilter = null);
                      _applyFilter();
                    },
                  ),
                  const SizedBox(width: 8),
                  ...types.map((t) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(_typeLabel(t)),
                          selected: _typeFilter == t,
                          onSelected: (_) {
                            setState(() => _typeFilter = t);
                            _applyFilter();
                          },
                        ),
                      )),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Text('No QR codes in history'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) {
                          final e = _filtered[i];
                          final dt = DateTime.fromMillisecondsSinceEpoch(e.timestamp);
                          final dateStr =
                              '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
                              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                          return Card(
                            child: ListTile(
                              leading: e.thumbnailPath != null &&
                                      File(e.thumbnailPath!).existsSync()
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.file(
                                        File(e.thumbnailPath!),
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Icon(Icons.qr_code_2, size: 48),
                              title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                '${_typeLabel(e.type)} - $dateStr',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) async {
                                  switch (action) {
                                    case 'share':
                                      if (e.fullPath != null &&
                                          File(e.fullPath!).existsSync()) {
                                        await ToolIO.share(e.fullPath!, text: e.name);
                                      }
                                      break;
                                    case 'download':
                                      if (e.fullPath != null &&
                                          File(e.fullPath!).existsSync()) {
                                        final messenger = ScaffoldMessenger.of(context);
                                        final bytes = await File(e.fullPath!).readAsBytes();
                                        await AppStorage.writeExport('${e.name}.png', bytes);
                                        if (mounted) {
                                          messenger.showSnackBar(
                                            const SnackBar(content: Text('Saved to exports')),
                                          );
                                        }
                                      }
                                      break;
                                    case 'delete':
                                      if (!mounted) return;
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete?'),
                                          content: Text('Delete "${e.name}"?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true && mounted) await _delete(e);
                                      break;
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'share', child: Text('Share')),
                                  const PopupMenuItem(value: 'download', child: Text('Download')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
