import 'package:flutter_test/flutter_test.dart';
import 'package:xscan/core/services/ai_service.dart';

void main() {
  group('AiService.detectDocType', () {
    test('detects invoice', () {
      final text = 'Invoice #12345\nBill To: Acme Corp\nAmount Due: \$150.00\nTax Invoice';
      expect(AiService.detectDocType(text), 'Invoice');
    });

    test('detects receipt', () {
      final text = 'WALMART STORE\nSubtotal: \$45.99\nTotal: \$49.50\nThank you for shopping\nVAT included';
      expect(AiService.detectDocType(text), 'Receipt');
    });

    test('detects business card', () {
      final text = 'John Smith\nCEO\njohn@acme.com\nwww.acme.com\nMobile: +1 555-1234';
      expect(AiService.detectDocType(text), 'Business Card');
    });

    test('detects contract', () {
      final text = 'AGREEMENT\nThis agreement is hereby entered into by the parties\nTerms and conditions\nSignature: ________\nClause 1.1';
      expect(AiService.detectDocType(text), 'Contract');
    });

    test('detects bank statement', () {
      final text = 'BANK STATEMENT\nAccount No: 12345678\nBalance: \$5,432.10\nDebit: \$200.00\nCredit: \$1,000.00\nTransaction dated 01/15/2026';
      expect(AiService.detectDocType(text), 'Bank Statement');
    });

    test('returns Document for empty text', () {
      expect(AiService.detectDocType(''), 'Document');
    });

    test('returns Document for unrecognizable text', () {
      expect(AiService.detectDocType('Hello world this is random text'), 'Document');
    });
  });

  group('AiService.suggestFolder', () {
    test('maps Invoice to Invoices', () {
      expect(AiService.suggestFolder('Invoice'), 'Invoices');
    });

    test('maps Receipt to Receipts', () {
      expect(AiService.suggestFolder('Receipt'), 'Receipts');
    });

    test('maps unknown type to Documents', () {
      expect(AiService.suggestFolder('Unknown'), 'Documents');
    });
  });

  group('AiService.suggestTitle', () {
    test('suggests invoice title with number', () {
      final title = AiService.suggestTitle('Invoice #INV-2024-001', 'Invoice');
      expect(title, contains('Invoice'));
    });

    test('suggests receipt title with vendor', () {
      final title = AiService.suggestTitle('WALMART STORE\nSubtotal: \$45.99', 'Receipt');
      expect(title, contains('WALMART'));
      expect(title, contains('Receipt'));
    });

    test('truncates long titles', () {
      final longText = 'A' * 50;
      final title = AiService.suggestTitle(longText, 'Document');
      expect(title.length, lessThanOrEqualTo(42));
    });
  });

  group('AiService.summarize', () {
    test('returns empty for empty text', () {
      expect(AiService.summarize(''), '');
    });

    test('returns original text if fewer than 3 sentences', () {
      final text = 'This is sentence one. This is sentence two.';
      expect(AiService.summarize(text), text);
    });

    test('summarizes long text to maxSentences', () {
      final text = List.generate(10, (i) => 'Sentence $i with enough words to pass filter.').join(' ');
      final summary = AiService.summarize(text, maxSentences: 3);
      final sentences = summary.split(RegExp(r'(?<=[.!?])\s+'));
      expect(sentences.length, lessThanOrEqualTo(4));
    });
  });

  group('AiService.extractInvoice', () {
    test('extracts invoice number', () {
      final result = AiService.extractInvoice('Invoice #INV-2024-001\nDate: 01/15/2026');
      expect(result['Invoice #'], 'INV-2024-001');
    });

    test('extracts date', () {
      final result = AiService.extractInvoice('Invoice\nDate: 01/15/2026');
      expect(result['Date'], isNotNull);
    });

    test('extracts total from total line', () {
      final result = AiService.extractInvoice('Subtotal: \$100.00\nTax: \$8.00\nTotal: \$108.00');
      expect(result['Total'], isNotNull);
    });
  });

  group('AiService.extractBusinessCard', () {
    test('extracts email', () {
      final result = AiService.extractBusinessCard('John Smith\njohn@acme.com\n+1 555-1234');
      expect(result['Email'], 'john@acme.com');
    });

    test('extracts phone', () {
      final result = AiService.extractBusinessCard('John Smith\n+1 555-1234');
      expect(result['Phone'], isNotNull);
    });

    test('extracts website', () {
      final result = AiService.extractBusinessCard('John Smith\nwww.acme.com');
      expect(result['Website'], contains('acme.com'));
    });
  });

  group('AiService.answerQuestion', () {
    test('returns matching sentence', () {
      final text = 'The total amount is \$150.00. The tax is \$12.00. The grand total is \$162.00.';
      final answer = AiService.answerQuestion(text, 'What is the total?');
      expect(answer, contains('total'));
    });

    test('returns no answer for irrelevant question', () {
      final text = 'Invoice #123\nDate: 01/15/2026';
      final answer = AiService.answerQuestion(text, 'What is the weather today?');
      expect(answer, 'No relevant answer found.');
    });
  });

  group('AiService.buildVCard', () {
    test('builds valid vCard', () {
      final card = {
        'Name': 'John Smith',
        'Phone': '+1 555-1234',
        'Email': 'john@acme.com',
        'Website': 'www.acme.com',
      };
      final vcard = AiService.buildVCard(card);
      expect(vcard, contains('BEGIN:VCARD'));
      expect(vcard, contains('VERSION:3.0'));
      expect(vcard, contains('FN:John Smith'));
      expect(vcard, contains('TEL:+1 555-1234'));
      expect(vcard, contains('EMAIL:john@acme.com'));
      expect(vcard, contains('URL:www.acme.com'));
      expect(vcard, contains('END:VCARD'));
    });
  });
}
