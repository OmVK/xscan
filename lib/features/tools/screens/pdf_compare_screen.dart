import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

import 'package:xscan/features/tools/widgets/pdf_source_picker.dart';

/// Side-by-side or page-by-page PDF comparison.
class PdfCompareScreen extends StatefulWidget {
  const PdfCompareScreen({super.key});

  @override
  State<PdfCompareScreen> createState() => _PdfCompareScreenState();
}

class _PdfCompareScreenState extends State<PdfCompareScreen> {
  String? _pathA;
  String? _pathB;
  pdfx.PdfDocument? _docA;
  pdfx.PdfDocument? _docB;
  int _pageIndexA = 0;
  int _pageIndexB = 0;
  pdfx.PdfController? _controllerA;
  pdfx.PdfController? _controllerB;
  bool _syncScroll = true;
  bool _loading = false;
  String _viewMode = 'side'; // 'side' or 'stack'

  @override
  void dispose() {
    _controllerA?.dispose();
    _controllerB?.dispose();
    _docA?.close();
    _docB?.close();
    super.dispose();
  }

  int? get _pagesA => _docA?.pagesCount;
  int? get _pagesB => _docB?.pagesCount;
  int get _maxPages => (_pagesA ?? 0) > (_pagesB ?? 0) ? (_pagesA ?? 0) : (_pagesB ?? 0);

  Future<void> _pickA() async {
    final path = await pickInAppPdf(context);
    if (path == null) return;
    setState(() => _loading = true);
    _docA?.close();
    _controllerA?.dispose();
    final doc = await pdfx.PdfDocument.openFile(path);
    _controllerA = pdfx.PdfController(document: Future.value(doc));
    setState(() {
      _pathA = path;
      _docA = doc;
      _pageIndexA = 0;
      _loading = false;
    });
  }

  Future<void> _pickB() async {
    final path = await pickInAppPdf(context);
    if (path == null) return;
    setState(() => _loading = true);
    _docB?.close();
    _controllerB?.dispose();
    final doc = await pdfx.PdfDocument.openFile(path);
    _controllerB = pdfx.PdfController(document: Future.value(doc));
    setState(() {
      _pathB = path;
      _docB = doc;
      _pageIndexB = 0;
      _loading = false;
    });
  }

  String _fileName(String? path) {
    if (path == null) return 'Not selected';
    return path.split(Platform.pathSeparator).last;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasBoth = _docA != null && _docB != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare PDFs'),
        actions: [
          if (hasBoth) ...[
            IconButton(
              icon: Icon(_viewMode == 'side' ? Icons.view_column : Icons.view_agenda),
              onPressed: () => setState(() => _viewMode = _viewMode == 'side' ? 'stack' : 'side'),
              tooltip: _viewMode == 'side' ? 'Stack view' : 'Side-by-side',
            ),
            IconButton(
              icon: Icon(_syncScroll ? Icons.sync : Icons.sync_disabled),
              onPressed: () => setState(() => _syncScroll = !_syncScroll),
              tooltip: _syncScroll ? 'Unsync scroll' : 'Sync scroll',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // File selectors
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _fileSelector('Document A', _pathA, _pickA, theme),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.compare_arrows, size: 28),
                ),
                Expanded(
                  child: _fileSelector('Document B', _pathB, _pickB, theme),
                ),
              ],
            ),
          ),

          // Page navigation
          if (hasBoth) _buildPageNav(theme),

          // Comparison view
          Expanded(
            child: hasBoth
                ? _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _viewMode == 'side'
                        ? _buildSideBySide()
                        : _buildStackView()
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.compare, size: 80, color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Text(
                          'Select two PDFs to compare',
                          style: TextStyle(color: theme.colorScheme.outline, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _fileSelector(String label, String? path, VoidCallback onTap, ThemeData theme) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: path != null ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: path != null ? theme.colorScheme.primary.withValues(alpha: 0.3) : theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.outline)),
            const SizedBox(height: 4),
            Text(
              _fileName(path),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            if (path != null)
              Text(
                '${path == _pathA ? _pagesA : _pagesB} pages',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageNav(ThemeData theme) {
    final maxPage = _maxPages;
    if (maxPage == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _pageIndexA > 0
                ? () {
                    _controllerA?.previousPage(duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
                    _controllerB?.previousPage(duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
                    setState(() {
                      _pageIndexA = (_pageIndexA - 1).clamp(0, (_pagesA ?? 1) - 1);
                      _pageIndexB = (_pageIndexB - 1).clamp(0, (_pagesB ?? 1) - 1);
                    });
                  }
                : null,
          ),
          Expanded(
            child: Text(
              'Page ${_pageIndexA + 1} / $maxPage',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _pageIndexA < maxPage - 1
                ? () {
                    _controllerA?.nextPage(duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
                    _controllerB?.nextPage(duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
                    setState(() {
                      _pageIndexA = (_pageIndexA + 1).clamp(0, (_pagesA ?? 1) - 1);
                      _pageIndexB = (_pageIndexB + 1).clamp(0, (_pagesB ?? 1) - 1);
                    });
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSideBySide() {
    return Row(
      children: [
        Expanded(child: _pdfView(_controllerA, _pathA, 'A')),
        const VerticalDivider(width: 1),
        Expanded(child: _pdfView(_controllerB, _pathB, 'B')),
      ],
    );
  }

  Widget _buildStackView() {
    return Column(
      children: [
        Expanded(child: _pdfView(_controllerA, _pathA, 'A')),
        const Divider(height: 1),
        Expanded(child: _pdfView(_controllerB, _pathB, 'B')),
      ],
    );
  }

  Widget _pdfView(pdfx.PdfController? controller, String? path, String label) {
    if (controller == null || path == null) {
      return Center(child: Text('Select Document $label'));
    }
    return pdfx.PdfView(
      controller: controller,
      onDocumentLoaded: (doc) {},
      onPageChanged: (page) {},
    );
  }
}
