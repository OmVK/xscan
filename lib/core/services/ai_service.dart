/// On-device, offline "AI" using deterministic heuristics over OCR text.
///
/// No network calls or external models — keeps the app fully offline-first.
class AiService {
  /// Detects a high-level document type from OCR text.
  static String detectDocType(String text) {
    final t = text.toLowerCase();
    int score(List<String> words) =>
        words.where((w) => t.contains(w)).length;

    final scores = <String, int>{
      'Invoice': score(['invoice', 'bill to', 'invoice no', 'amount due', 'tax invoice']),
      'Receipt': score(['receipt', 'subtotal', 'total', 'change', 'cash', 'vat', 'thank you']),
      'Business Card': score(['@', 'www.', 'ceo', 'manager', 'director', 'mobile', 'tel']),
      'ID / Passport': score(['passport', 'identity', 'id no', 'date of birth', 'nationality', 'license']),
      'Contract': score(['agreement', 'hereby', 'party', 'terms', 'signature', 'whereas', 'clause']),
      'Bank Statement': score(['statement', 'balance', 'account no', 'debit', 'credit', 'transaction']),
      'Certificate': score(['certificate', 'awarded', 'completion', 'certify']),
    };

    var best = 'Document';
    var bestScore = 0;
    scores.forEach((type, s) {
      if (s > bestScore) {
        bestScore = s;
        best = type;
      }
    });
    return bestScore == 0 ? 'Document' : best;
  }

  /// Maps a document type to a suggested folder.
  static String suggestFolder(String docType) {
    switch (docType) {
      case 'Invoice':
        return 'Invoices';
      case 'Receipt':
        return 'Receipts';
      case 'Business Card':
        return 'Contacts';
      case 'ID / Passport':
        return 'IDs';
      case 'Contract':
        return 'Contracts';
      case 'Bank Statement':
        return 'Finance';
      case 'Certificate':
        return 'Certificates';
      default:
        return 'Documents';
    }
  }

  /// Suggests a concise, descriptive title.
  static String suggestTitle(String text, String docType) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.length >= 3)
        .toList();
    final date = _firstDate(text);
    final datePart = date != null ? ' $date' : '';

    if (docType == 'Invoice') {
      final no = _match(text, RegExp(r'invoice\s*#?\s*[:\-]?\s*([A-Za-z0-9\-]+)',
          caseSensitive: false));
      return 'Invoice ${no ?? ''}$datePart'.trim();
    }
    if (docType == 'Receipt') {
      final vendor = lines.isNotEmpty ? lines.first : 'Receipt';
      return '$vendor Receipt$datePart'.trim();
    }
    if (docType == 'Business Card') {
      final name = _guessName(lines);
      return name ?? 'Business Card';
    }
    // Fallback: first meaningful line, truncated.
    if (lines.isNotEmpty) {
      final first = lines.first;
      return first.length > 40 ? '${first.substring(0, 40)}…' : first;
    }
    return '$docType$datePart'.trim();
  }

  /// Extractive summary: ranks sentences by keyword frequency.
  static String summarize(String text, {int maxSentences = 3}) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return '';
    final sentences = clean
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().length > 20)
        .toList();
    if (sentences.length <= maxSentences) return clean;

    final freq = <String, int>{};
    for (final word in clean.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
      if (word.length < 4 || _stopWords.contains(word)) continue;
      freq[word] = (freq[word] ?? 0) + 1;
    }

    final ranked = sentences.map((s) {
      var score = 0;
      for (final w in s.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
        score += freq[w] ?? 0;
      }
      return MapEntry(s, score);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = ranked.take(maxSentences).map((e) => e.key).toList();
    // Preserve original order.
    top.sort((a, b) => sentences.indexOf(a).compareTo(sentences.indexOf(b)));
    return top.join(' ');
  }

  /// Extracts key invoice fields.
  static Map<String, String> extractInvoice(String text) {
    final result = <String, String>{};
    final invoiceNo = _match(
        text,
        RegExp(r'invoice\s*#?\s*[:\-]?\s*([A-Za-z0-9\-]+)',
            caseSensitive: false));
    final date = _firstDate(text);
    final total = _grandTotal(text);
    if (invoiceNo != null) result['Invoice #'] = invoiceNo;
    if (date != null) result['Date'] = date;
    if (total != null) result['Total'] = total;
    return result;
  }

  /// Extracts the receipt total (largest currency amount near "total").
  static String? extractReceiptTotal(String text) => _grandTotal(text);

  /// Parses a business card into structured fields + a vCard string.
  static Map<String, String> extractBusinessCard(String text) {
    final lines = text.split('\n').map((l) => l.trim()).toList();
    final email = _match(text, RegExp(r'[\w.\-]+@[\w.\-]+\.\w+'));
    final phone = _match(
        text, RegExp(r'(\+?\d[\d\s\-().]{6,}\d)'));
    final website =
        _match(text, RegExp(r'(www\.[\w.\-]+|https?://[\w.\-/]+)'));
    final name = _guessName(lines.where((l) => l.length >= 3).toList());

    final result = <String, String>{};
    if (name != null) result['Name'] = name;
    if (phone != null) result['Phone'] = phone;
    if (email != null) result['Email'] = email;
    if (website != null) result['Website'] = website;
    return result;
  }

  static String buildVCard(Map<String, String> card) {
    final b = StringBuffer('BEGIN:VCARD\nVERSION:3.0\n');
    if (card['Name'] != null) b.write('FN:${card['Name']}\n');
    if (card['Phone'] != null) b.write('TEL:${card['Phone']}\n');
    if (card['Email'] != null) b.write('EMAIL:${card['Email']}\n');
    if (card['Website'] != null) b.write('URL:${card['Website']}\n');
    b.write('END:VCARD');
    return b.toString();
  }

  /// Naive keyword-based Q&A: returns the sentence best matching the question.
  static String answerQuestion(String text, String question) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final sentences = clean.split(RegExp(r'(?<=[.!?])\s+'));
    final keywords = question
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toSet();
    if (keywords.isEmpty || sentences.isEmpty) {
      return 'No relevant answer found.';
    }
    MapEntry<String, int>? best;
    for (final s in sentences) {
      final lower = s.toLowerCase();
      final score = keywords.where((k) => lower.contains(k)).length;
      if (best == null || score > best.value) {
        best = MapEntry(s, score);
      }
    }
    if (best == null || best.value == 0) return 'No relevant answer found.';
    return best.key.trim();
  }

  // ---- helpers ----

  static String? _match(String text, RegExp re) {
    final m = re.firstMatch(text);
    if (m == null) return null;
    return (m.groupCount >= 1 ? m.group(1) : m.group(0))?.trim();
  }

  static String? _firstDate(String text) {
    final patterns = [
      RegExp(r'\b\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4}\b'),
      RegExp(r'\b\d{4}[/\-.]\d{1,2}[/\-.]\d{1,2}\b'),
      RegExp(
          r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},?\s+\d{4}\b',
          caseSensitive: false),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(text);
      if (m != null) return m.group(0);
    }
    return null;
  }

  static String? _grandTotal(String text) {
    final lines = text.split('\n');
    final amountRe = RegExp(r'([$€£₹]?\s?\d[\d,]*\.\d{2})');
    String? candidate;
    double best = -1;
    for (final line in lines) {
      final lower = line.toLowerCase();
      final isTotalLine = lower.contains('total') ||
          lower.contains('amount due') ||
          lower.contains('balance');
      for (final m in amountRe.allMatches(line)) {
        final raw = m.group(1)!;
        final num = double.tryParse(
                raw.replaceAll(RegExp(r'[^\d.]'), '')) ??
            0;
        final weighted = isTotalLine ? num * 1000 : num;
        if (weighted > best) {
          best = weighted;
          candidate = raw.trim();
        }
      }
    }
    return candidate;
  }

  static String? _guessName(List<String> lines) {
    for (final l in lines) {
      if (l.contains('@') || l.contains('www') || RegExp(r'\d').hasMatch(l)) {
        continue;
      }
      final words = l.split(RegExp(r'\s+'));
      if (words.length >= 2 &&
          words.length <= 4 &&
          words.every((w) => w.isNotEmpty && w[0] == w[0].toUpperCase())) {
        return l;
      }
    }
    return lines.isNotEmpty ? lines.first : null;
  }

  static const _stopWords = {
    'the', 'and', 'for', 'are', 'but', 'not', 'you', 'all', 'can', 'her',
    'was', 'one', 'our', 'out', 'day', 'get', 'has', 'him', 'his', 'how',
    'man', 'new', 'now', 'old', 'see', 'two', 'way', 'who', 'boy', 'did',
    'its', 'let', 'put', 'say', 'she', 'too', 'use', 'that', 'this', 'with',
    'from', 'they', 'have', 'what', 'your', 'when', 'will', 'there', 'their',
  };
}
