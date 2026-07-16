// Basic smoke test for the XScan app.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xscan/core/providers/settings_provider.dart';
import 'package:xscan/main.dart';

void main() {
  testWidgets('XScan app renders the dashboard title', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const XScanApp(),
      ),
    );
    await tester.pump();

    expect(find.text('XScan'), findsOneWidget);
  });
}
