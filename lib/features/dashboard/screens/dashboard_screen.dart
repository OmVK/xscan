import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:xscan/core/services/incoming_share_service.dart';
import 'package:xscan/features/tools/widgets/incoming_actions_sheet.dart';

import 'package:xscan/features/scanner/screens/scanner_screen.dart';
import 'package:xscan/features/document/screens/document_detail_screen.dart';
import 'package:xscan/features/settings/screens/settings_screen.dart';
import 'package:xscan/features/tools/screens/pdf_editor_screen.dart';
import 'package:xscan/features/tools/screens/merge_pdf_screen.dart';
import 'package:xscan/features/tools/screens/page_manager_screen.dart';
import 'package:xscan/features/tools/screens/compress_pdf_screen.dart';
import 'package:xscan/features/tools/screens/images_to_pdf_screen.dart';
import 'package:xscan/features/tools/screens/searchable_pdf_screen.dart';
import 'package:xscan/features/tools/screens/watermark_screen.dart';
import 'package:xscan/features/tools/screens/protect_pdf_screen.dart';
import 'package:xscan/features/tools/screens/pdf_to_images_screen.dart';
import 'package:xscan/features/tools/screens/pdf_to_text_screen.dart';
import 'package:xscan/features/tools/screens/split_pdf_screen.dart';
import 'package:xscan/features/tools/screens/fill_forms_screen.dart';
import 'package:xscan/features/tools/screens/image_editor_screen.dart';
import 'package:xscan/features/tools/screens/convert_format_screen.dart';
import 'package:xscan/features/tools/screens/page_numbering_screen.dart';
import 'package:xscan/features/tools/screens/watermark_templates_screen.dart';
import 'package:xscan/features/tools/screens/redact_pdf_screen.dart';
import 'package:xscan/features/tools/screens/bookmark_manager_screen.dart';
import 'package:xscan/features/tools/screens/page_rotation_screen.dart';
import 'package:xscan/features/qr/screens/qr_generator_screen.dart';
import 'package:xscan/features/qr/screens/batch_qr_screen.dart';
import 'package:xscan/features/qr/screens/qr_history_screen.dart';
import 'package:xscan/features/qr/screens/pdf_to_qr_screen.dart';
import 'package:xscan/features/tools/widgets/pdf_source_picker.dart';
import 'package:xscan/core/providers/document_provider.dart';
import 'package:xscan/core/services/print_service.dart';
import 'package:xscan/core/services/pdf_tools_service.dart';
import 'package:xscan/core/services/biometric_service.dart';
import 'package:xscan/features/tools/widgets/tool_result_sheet.dart';
import 'package:xscan/core/widgets/confirm_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xscan/core/data/models/scan_document.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<List<IncomingFile>>? _shareSub;
  Timer? _searchDebounce;
  final Set<String> _fileExistsCache = {};

  @override
  void initState() {
    super.initState();
    _initShareHandling();
  }

  /// Checks file existence using a cache to avoid synchronous disk I/O on the UI thread.
  bool _fileExists(String path) {
    if (_fileExistsCache.contains(path)) return true;
    // First check is async-friendly via the cache; fallback to sync for correctness.
    final exists = File(path).existsSync();
    if (exists) _fileExistsCache.add(path);
    return exists;
  }

  void _rebuildFileCache(List<ScanDocument> docs) {
    for (final doc in docs) {
      if (doc.filePath.isNotEmpty) {
        File(doc.filePath).exists().then((exists) {
          if (exists) {
            _fileExistsCache.add(doc.filePath);
          } else {
            _fileExistsCache.remove(doc.filePath);
          }
        });
      }
    }
  }

  Future<void> _initShareHandling() async {
    try {
      final initial = await IncomingShareService.initial();
      if (initial.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showIncomingActions(context, initial);
          IncomingShareService.reset();
        });
      }
      _shareSub = IncomingShareService.stream().listen((files) {
        if (files.isNotEmpty && mounted) {
          showIncomingActions(context, files);
        }
      });
    } catch (_) {
      // Sharing not available (e.g. tests) — ignore.
    }
  }

  // Theme-aware glassmorphism helpers so the frosted UI stays legible in both
  // light and dark modes.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  // Tint used for the frosted panels themselves.
  Color get _glassFill => _isDark
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.white.withValues(alpha: 0.55);

  Color get _glassBorder => _isDark
      ? Colors.white.withValues(alpha: 0.20)
      : Colors.black.withValues(alpha: 0.08);

  // Foreground color for text/icons sitting on the glass.
  Color get _onGlass => Theme.of(context).colorScheme.onSurface;

  Color get _onGlassMuted => _onGlass.withValues(alpha: 0.55);

  // Top offset so scrollable content clears the floating (translucent) app bar
  // and the status bar instead of hiding behind it.
  double get _topContentInset => MediaQuery.of(context).padding.top + 88;

  @override
  void dispose() {
    _searchController.dispose();
    _shareSub?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // For floating bottom nav
      extendBodyBehindAppBar: true, // For floating app bar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: _buildFloatingAppBar(),
      ),
      body: _buildBody(),
      floatingActionButton: _buildGlowingFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildGlassBottomNav(),
    );
  }

  Widget _buildGlowingFAB() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ScannerScreen()),
          );
        },
        shape: const CircleBorder(),
        child: const Icon(Icons.document_scanner, size: 28),
      ),
    );
  }

  Widget _buildFloatingAppBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 60,
              decoration: BoxDecoration(
                color: _glassFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _glassBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _isSearching
                        ? TextField(
                            controller: _searchController,
                            autofocus: true,
                            style: TextStyle(color: _onGlass),
                            decoration: InputDecoration(
                              hintText: 'Search title or text...',
                              hintStyle: TextStyle(color: _onGlassMuted),
                              border: InputBorder.none,
                            ),
                            onChanged: (value) {
                              _searchDebounce?.cancel();
                              _searchDebounce = Timer(
                                const Duration(milliseconds: 300),
                                () {
                                  ref.read(searchQueryProvider.notifier).state = value;
                                },
                              );
                            },
                          )
                        : Text(
                            'XScan',
                            style: TextStyle(
                              color: _onGlass,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                  ),
                  IconButton(
                    icon: Icon(_isSearching ? Icons.close : Icons.search, color: _onGlass),
                    onPressed: () {
                      setState(() {
                        if (_isSearching) {
                          _isSearching = false;
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                        } else {
                          _isSearching = true;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassBottomNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: _isDark
                  ? Colors.black.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _glassBorder),
            ),
            child: Row(
              children: [
                Expanded(child: _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home')),
                Expanded(child: _buildNavItem(1, Icons.folder_outlined, Icons.folder, 'Files')),
                const SizedBox(width: 50), // Space for FAB
                Expanded(child: _buildNavItem(2, Icons.grid_view, Icons.grid_view_rounded, 'Tools')),
                Expanded(child: _buildNavItem(3, Icons.settings_outlined, Icons.settings, 'Settings')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? Theme.of(context).colorScheme.secondary : _onGlassMuted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          );
          return;
        }
        setState(() {
          _currentIndex = index;
        });
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSelected ? activeIcon : icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 1:
        return _buildFilesView();
      case 2:
        return _buildToolsView();
      default:
        return _buildHomeView();
    }
  }

  Widget _buildHomeView() {
    final docsAsyncValue = ref.watch(filteredDocumentsProvider);
    final selectedCategory = ref.watch(categoryFilterProvider);

    return Column(
      children: [
        // Add top padding to account for floating AppBar + status bar.
        SizedBox(height: _topContentInset),
        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: ['All', 'Receipts', 'Documents', 'Notes', 'Barcodes'].map((category) {
              final isSelected = selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: GestureDetector(
                  onTap: () {
                    ref.read(categoryFilterProvider.notifier).state = category;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2) 
                        : _glassFill,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected 
                          ? Theme.of(context).colorScheme.secondary 
                          : _glassBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Theme.of(context).colorScheme.secondary : _onGlass,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        
        // Documents Grid
        Expanded(
          child: docsAsyncValue.when(
            data: (filteredDocs) {
              if (filteredDocs.isEmpty) {
                return _buildEmptyState(selectedCategory);
              }

              _rebuildFileCache(filteredDocs);

              return MasonryGridView.count(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), // Bottom padding for nav bar
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final double randomHeight = (index % 3 == 0) ? 220 : 180;
                  final hasImage = doc.filePath.isNotEmpty && _fileExists(doc.filePath);

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DocumentDetailScreen(document: doc),
                        ),
                      );
                    },
                    child: Hero(
                      tag: doc.id.toString(),
                      child: Container(
                        height: hasImage ? null : randomHeight, // null lets image dictate height
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: hasImage ? null : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF2B2B36),
                              Color(0xFF1E1E26),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.passthrough,
                          children: [
                            if (hasImage)
                              Image.file(
                                File(doc.filePath),
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              )
                            else
                              Center(
                                child: Icon(
                                  doc.category == 'Barcodes' ? Icons.qr_code_2 : Icons.article,
                                  size: 60,
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              
                            // Glassmorphism title overlay at the bottom
                            Positioned(
                              bottom: 0, left: 0, right: 0,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      border: Border(
                                        top: BorderSide(
                                          color: Colors.white.withValues(alpha: 0.1),
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          doc.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          doc.category,
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.secondary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String category) {
    IconData emptyIcon;
    String emptyMessage;
    
    switch (category) {
      case 'Barcodes':
        emptyIcon = Icons.qr_code_scanner;
        emptyMessage = 'No saved barcodes';
        break;
      case 'Receipts':
        emptyIcon = Icons.receipt_long;
        emptyMessage = 'No saved receipts';
        break;
      case 'Documents':
        emptyIcon = Icons.file_copy_outlined;
        emptyMessage = 'No saved documents';
        break;
      case 'Notes':
        emptyIcon = Icons.note_alt_outlined;
        emptyMessage = 'No saved notes';
        break;
      default:
        emptyIcon = Icons.document_scanner;
        emptyMessage = 'No recent scans';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0.8, end: 1.2),
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Icon(
              emptyIcon, 
              size: 80, 
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
            ),
          ),
          const SizedBox(height: 24),
          Text(
            emptyMessage,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesView() {
    final view = ref.watch(documentViewProvider);
    final docsAsync = ref.watch(filteredDocumentsProvider);

    return Column(
      children: [
        SizedBox(height: _topContentInset),
        _buildShelfSelector(view),
        Expanded(
          child: docsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (docs) => _buildFilesList(docs, view),
          ),
        ),
      ],
    );
  }

  Widget _buildShelfSelector(DocumentView view) {
    final shelves = <(DocumentView, IconData, String)>[
      (DocumentView.library, Icons.folder, 'Library'),
      (DocumentView.favorites, Icons.star, 'Favorites'),
      (DocumentView.archive, Icons.archive, 'Archive'),
      (DocumentView.trash, Icons.delete, 'Trash'),
      (DocumentView.hidden, Icons.lock, 'Hidden'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: shelves.map((s) {
          final selected = view == s.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(s.$2,
                  size: 16,
                  color: selected
                      ? Theme.of(context).colorScheme.onPrimary
                      : _onGlassMuted),
              label: Text(s.$3),
              selected: selected,
              onSelected: (_) => _selectShelf(s.$1),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _selectShelf(DocumentView shelf) async {
    if (shelf == DocumentView.hidden &&
        !ref.read(hiddenUnlockedProvider)) {
      final ok = await _authenticateForHidden();
      if (!ok) return;
      ref.read(hiddenUnlockedProvider.notifier).state = true;
    }
    ref.read(documentViewProvider.notifier).state = shelf;
  }

  Future<bool> _authenticateForHidden() async {
    final service = BiometricService();
    if (!await service.isAvailable()) return true;
    return service.authenticate(reason: 'Unlock hidden documents');
  }

  Widget _buildFilesList(List<ScanDocument> docs, DocumentView view) {
    if (docs.isEmpty) {
      return _buildEmptyState('All');
    }

    if (view == DocumentView.trash) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: FilledButton.tonalIcon(
              onPressed: _emptyTrash,
              icon: const Icon(Icons.delete_forever),
              label: const Text('Empty Trash'),
            ),
          ),
          Expanded(child: _buildGroupedList(docs)),
        ],
      );
    }
    return _buildGroupedList(docs);
  }

  Future<void> _emptyTrash() async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Empty Trash?',
      content: 'This permanently deletes all trashed documents and securely wipes their files.',
      confirmLabel: 'Delete',
    );
    if (!confirm) return;
    await ref.read(isarServiceProvider).emptyTrash();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Trash emptied')));
  }

  Widget _buildGroupedList(List<ScanDocument> docs) {
    // Group documents by category.
    final Map<String, List<ScanDocument>> grouped = {};
    for (final doc in docs) {
      grouped.putIfAbsent(doc.category, () => []).add(doc);
    }
    final categories = grouped.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: categories.map((category) {
        final items = grouped[category]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '$category (${items.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
                ...items.map((doc) {
                  final hasImage =
                      doc.filePath.isNotEmpty && _fileExists(doc.filePath);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                      leading: hasImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(doc.filePath),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              ),
                            )
                      : Icon(
                          doc.category == 'Barcodes'
                              ? Icons.qr_code_2
                              : Icons.article,
                        ),
                  title: Text(
                    doc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    doc.dateCreated.toLocal().toString().split('.')[0],
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DocumentDetailScreen(document: doc),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  void _openScanner(ScanMode mode) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ScannerScreen(initialMode: mode)),
    );
  }

  Future<void> _openPdfEditor() async {
    final path = await pickInAppPdf(context);
    if (path == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PdfEditorScreen(pdfPath: path)),
    );
  }

  Future<void> _openImageEditor() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    final saved = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageEditorScreen(imagePath: file.path),
      ),
    );
    if (saved == null || !mounted) return;
    final doc = ScanDocument()
      ..title = 'Edited image ${DateTime.now().toLocal().toString().split('.')[0]}'
      ..filePath = saved
      ..dateCreated = DateTime.now()
      ..fileType = 'image'
      ..category = 'Documents';
    await ref.read(isarServiceProvider).saveDocument(doc);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved edited image to library')),
    );
  }

  Future<void> _printPdf() async {
    final path = await pickInAppPdf(context);
    if (path == null) return;
    await PrintService.printPdf(path);
  }

  Future<void> _flattenPdf() async {
    final path = await pickInAppPdf(context);
    if (path == null || !mounted) return;
    final out = await PdfToolsService().flatten(path);
    if (!mounted) return;
    await showPdfResult(context, out);
  }

  Future<void> _exportPdfA() async {
    final path = await pickInAppPdf(context);
    if (path == null || !mounted) return;
    final out = await PdfToolsService().exportPdfA(path);
    if (!mounted) return;
    await showPdfResult(context, out);
  }

  Widget _buildToolsView() {
    final scanTools = <(IconData, String, String, VoidCallback)>[
      (
        Icons.document_scanner,
        'Scan Document',
        'Auto edge-detect & multi-page',
        () => _openScanner(ScanMode.document),
      ),
      (
        Icons.qr_code_scanner,
        'Scan QR / Barcode',
        'Read codes and links',
        () => _openScanner(ScanMode.barcode),
      ),
      (
        Icons.text_fields,
        'Extract Text (OCR)',
        'Pull text from a page',
        () => _openScanner(ScanMode.ocr),
      ),
      (
        Icons.qr_code_2,
        'QR Generator',
        'Create QR codes',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const QrGeneratorScreen())),
      ),
      (
        Icons.qr_code_2,
        'Batch QR',
        'Generate from CSV',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const BatchQrScreen())),
      ),
      (
        Icons.history,
        'QR History',
        'View past QR codes',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const QrHistoryScreen())),
      ),
      (
        Icons.picture_as_pdf,
        'QR from PDF',
        'Extract text to QR',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PdfToQrScreen())),
      ),
    ];

    final mediaTools = <(IconData, String, String, VoidCallback)>[
      (
        Icons.tune,
        'Image Editor',
        'Crop, filters, adjust',
        _openImageEditor,
      ),
      (
        Icons.transform,
        'Convert Image',
        'PNG, JPG, TIFF, BMP',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ConvertFormatScreen())),
      ),
    ];

    final pdfTools = <(IconData, String, String, VoidCallback)>[
      (
        Icons.edit_document,
        'PDF Editor',
        'Sign, text, highlight, draw',
        _openPdfEditor,
      ),
      (
        Icons.merge_type,
        'Merge PDFs',
        'Combine files into one',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MergePdfScreen())),
      ),
      (
        Icons.auto_stories,
        'Organize Pages',
        'Reorder, rotate, delete',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PageManagerScreen())),
      ),
      (
        Icons.content_cut,
        'Split PDF',
        'By ranges or single pages',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SplitPdfScreen())),
      ),
      (
        Icons.compress,
        'Compress PDF',
        'Reduce file size',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CompressPdfScreen())),
      ),
      (
        Icons.picture_as_pdf,
        'Images to PDF',
        'Turn photos into a PDF',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ImagesToPdfScreen())),
      ),
      (
        Icons.manage_search,
        'Searchable PDF',
        'Add an OCR text layer',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SearchablePdfScreen())),
      ),
      (
        Icons.branding_watermark,
        'Watermark',
        'Stamp text on every page',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WatermarkScreen())),
      ),
      (
        Icons.dynamic_feed,
        'Watermark Templates',
        'Pre-built stamp watermarks',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WatermarkTemplatesScreen())),
      ),
      (
        Icons.format_list_numbered,
        'Page Numbers',
        'Add page numbers',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PageNumberingScreen())),
      ),
      (
        Icons.security,
        'Redact PDF',
        'Black out sensitive content',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const RedactPdfScreen())),
      ),
      (
        Icons.bookmark,
        'Bookmarks',
        'Edit table of contents',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const BookmarkManagerScreen())),
      ),
      (
        Icons.rotate_right,
        'Rotate Pages',
        'Per-page rotation',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PageRotationScreen())),
      ),
      (
        Icons.lock,
        'Protect PDF',
        'Add or remove a password',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProtectPdfScreen())),
      ),
      (
        Icons.image,
        'PDF to Images',
        'Export pages as PNGs',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PdfToImagesScreen())),
      ),
      (
        Icons.text_snippet,
        'PDF to Text',
        'Extract selectable text',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PdfToTextScreen())),
      ),
      (
        Icons.edit_note,
        'Fill Forms',
        'Complete PDF form fields',
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const FillFormsScreen())),
      ),
      (
        Icons.layers_clear,
        'Flatten PDF',
        'Bake in annotations',
        _flattenPdf,
      ),
      (
        Icons.archive_outlined,
        'PDF/A Archive',
        'Convert to PDF/A-1b',
        _exportPdfA,
      ),
      (
        Icons.print,
        'Print PDF',
        'Send to a printer',
        _printPdf,
      ),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(16, _topContentInset, 16, 120),
      children: [
        _buildToolsSection('Scan & Create', scanTools),
        const SizedBox(height: 24),
        _buildToolsSection('Image Tools', mediaTools),
        const SizedBox(height: 24),
        _buildToolsSection('PDF Tools', pdfTools),
      ],
    );
  }

  Widget _buildToolsSection(
    String title,
    List<(IconData, String, String, VoidCallback)> tools,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 4),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _onGlass,
            ),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.15,
          children: tools.map((tool) {
            return GestureDetector(
              onTap: tool.$4,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2B2B36), Color(0xFF1E1E26)],
                  ),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      tool.$1,
                      size: 34,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const Spacer(),
                    Text(
                      tool.$2,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tool.$3,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
