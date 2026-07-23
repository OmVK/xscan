import 'package:flutter/material.dart';

import 'package:xscan/core/services/pdf_tools_service.dart';
import 'package:xscan/features/tools/widgets/pdf_source_picker.dart';
import 'package:xscan/features/tools/widgets/tool_result_sheet.dart';

/// Fills interactive AcroForm fields (text & checkbox) in a PDF.
class FillFormsScreen extends StatefulWidget {
  const FillFormsScreen({super.key});

  @override
  State<FillFormsScreen> createState() => _FillFormsScreenState();
}

class _FillFormsScreenState extends State<FillFormsScreen> {
  final _service = PdfToolsService();
  String? _path;
  List<PdfFormFieldInfo> _fields = [];
  final Map<String, TextEditingController> _text = {};
  final Map<String, bool> _checks = {};
  bool _flatten = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final path = await pickInAppPdf(context);
    if (path == null) return;
    setState(() => _busy = true);
    try {
      final fields = await _service.readFormFields(path);
      for (final c in _text.values) {
        c.dispose();
      }
      _text.clear();
      _checks.clear();
      for (final f in fields) {
        if (f.type == PdfFormFieldType.text) {
          _text[f.name] = TextEditingController(text: f.value);
        } else {
          _checks[f.name] = f.value == 'true';
        }
      }
      setState(() {
        _path = path;
        _fields = fields;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_path == null) return;
    setState(() => _busy = true);
    try {
      final values = <String, String>{};
      _text.forEach((k, v) => values[k] = v.text);
      _checks.forEach((k, v) => values[k] = v ? 'true' : 'false');
      final out = await _service.fillForm(_path!, values, flatten: _flatten);
      if (!mounted) return;
      await showPdfResult(context, out);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fill Forms')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.upload_file),
              label: Text(_path == null ? 'Select PDF' : 'Change PDF'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _path == null
                  ? const Center(child: Text('Select a fillable PDF'))
                  : _fields.isEmpty
                      ? const Center(
                          child: Text('No fillable form fields found'))
                      : ListView(
                          children: _fields.map(_buildField).toList(),
                        ),
            ),
            if (_fields.isNotEmpty) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Flatten after filling'),
                subtitle: const Text('Bake values in (not editable later)'),
                value: _flatten,
                onChanged: (v) => setState(() => _flatten = v),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: const Text('Save Filled PDF'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildField(PdfFormFieldInfo f) {
    if (f.type == PdfFormFieldType.checkbox) {
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(f.name),
        value: _checks[f.name] ?? false,
        onChanged: (v) => setState(() => _checks[f.name] = v ?? false),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _text[f.name],
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: f.name,
        ),
      ),
    );
  }
}
