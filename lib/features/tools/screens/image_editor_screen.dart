import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import 'package:xscan/core/services/image_service.dart';

/// Full non-destructive image editor. Returns the saved page path (String) via
/// Navigator.pop when the user taps Save, or null if cancelled.
class ImageEditorScreen extends StatefulWidget {
  final String imagePath;

  const ImageEditorScreen({super.key, required this.imagePath});

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  late String _workingPath = widget.imagePath;
  final ImageEdit _edit = ImageEdit();
  Uint8List? _preview;
  bool _busy = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _rebuildPreview();
  }

  Future<void> _rebuildPreview() async {
    setState(() => _busy = true);
    try {
      final bytes = await ImageService.processToPng(_workingPath, _edit);
      if (!mounted) return;
      setState(() {
        _preview = Uint8List.fromList(bytes);
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Preview error: $e')));
    }
  }

  Future<void> _cropInteractive() async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: _workingPath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop',
          lockAspectRatio: false,
        ),
      ],
    );
    if (cropped == null) return;
    setState(() => _workingPath = cropped.path);
    await _rebuildPreview();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final path = await ImageService.processAndSave(_workingPath, _edit);
      if (!mounted) return;
      Navigator.pop(context, path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Editor'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _edit
                  ..brightness = 0
                  ..contrast = 0
                  ..saturation = 0
                  ..sharpness = 0
                  ..blur = 0
                  ..rotation = 0
                  ..flipH = false
                  ..flipV = false
                  ..colorMode = ImageColorMode.original
                  ..filter = ImageFilterType.none;
              });
              _rebuildPreview();
            },
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset',
          ),
          IconButton(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.check),
            tooltip: 'Save',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: _preview == null
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        InteractiveViewer(
                          child: Image.memory(_preview!, fit: BoxFit.contain),
                        ),
                        if (_busy)
                          Container(
                            color: Colors.black38,
                            child: const Center(
                                child: CircularProgressIndicator()),
                          ),
                      ],
                    ),
            ),
          ),
          _buildTabs(),
          SizedBox(height: 180, child: _buildPanel()),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = ['Transform', 'Adjust', 'Color', 'Filters'];
    return SizedBox(
      height: 48,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _tab == i;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _tab = i),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(tabs[i],
                    style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPanel() {
    switch (_tab) {
      case 1:
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _slider('Brightness', _edit.brightness, -100, 100,
                (v) => _edit.brightness = v),
            _slider('Contrast', _edit.contrast, -100, 100,
                (v) => _edit.contrast = v),
            _slider('Saturation', _edit.saturation, -100, 100,
                (v) => _edit.saturation = v),
            _slider('Sharpness', _edit.sharpness, 0, 100,
                (v) => _edit.sharpness = v),
            _slider('Blur', _edit.blur, 0, 100, (v) => _edit.blur = v),
          ],
        );
      case 2:
        return _wrapButtons([
          _modeBtn('Original', ImageColorMode.original),
          _modeBtn('Color', ImageColorMode.color),
          _modeBtn('Grayscale', ImageColorMode.grayscale),
          _modeBtn('B & W', ImageColorMode.blackWhite),
          _actionBtn('Auto Enhance', Icons.auto_fix_high, () {
            final preset = ImageService.autoEnhancePreset();
            setState(() {
              _edit
                ..colorMode = preset.colorMode
                ..contrast = preset.contrast
                ..brightness = preset.brightness
                ..sharpness = preset.sharpness
                ..saturation = preset.saturation;
            });
            _rebuildPreview();
          }),
        ]);
      case 3:
        return _wrapButtons([
          _filterBtn('None', ImageFilterType.none),
          _filterBtn('Magic', ImageFilterType.magic),
          _filterBtn('Vivid', ImageFilterType.vivid),
          _filterBtn('Cool', ImageFilterType.cool),
          _filterBtn('Warm', ImageFilterType.warm),
          _filterBtn('Vintage', ImageFilterType.vintage),
          _filterBtn('Invert', ImageFilterType.invert),
        ]);
      default:
        return _wrapButtons([
          _actionBtn('Crop', Icons.crop, _cropInteractive),
          _actionBtn('Rotate Left', Icons.rotate_left, () {
            setState(() => _edit.rotation = (_edit.rotation - 90) % 360);
            _rebuildPreview();
          }),
          _actionBtn('Rotate Right', Icons.rotate_right, () {
            setState(() => _edit.rotation = (_edit.rotation + 90) % 360);
            _rebuildPreview();
          }),
          _actionBtn('Flip H', Icons.flip, () {
            setState(() => _edit.flipH = !_edit.flipH);
            _rebuildPreview();
          }),
          _actionBtn('Flip V', Icons.flip_camera_android, () {
            setState(() => _edit.flipV = !_edit.flipV);
            _rebuildPreview();
          }),
          _actionBtn('Resize 1080', Icons.photo_size_select_large, () {
            setState(() => _edit.maxEdge = 1080);
            _rebuildPreview();
          }),
        ]);
    }
  }

  Widget _wrapButtons(List<Widget> children) => SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Wrap(spacing: 10, runSpacing: 10, children: children),
      );

  Widget _slider(String label, int value, double min, double max,
      ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble().clamp(min, max),
            min: min,
            max: max,
            onChanged: (v) => setState(() => onChanged(v.round())),
            onChangeEnd: (_) => _rebuildPreview(),
          ),
        ),
        SizedBox(width: 36, child: Text('$value')),
      ],
    );
  }

  Widget _modeBtn(String label, ImageColorMode mode) {
    final selected = _edit.colorMode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _edit.colorMode = mode);
        _rebuildPreview();
      },
    );
  }

  Widget _filterBtn(String label, ImageFilterType filter) {
    final selected = _edit.filter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _edit.filter = filter);
        _rebuildPreview();
      },
    );
  }

  Widget _actionBtn(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
