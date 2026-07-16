import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xscan/core/providers/settings_provider.dart';
import 'package:xscan/core/theme/app_theme.dart';
import 'package:xscan/features/auth/screens/lock_screen.dart';
import 'package:xscan/features/onboarding/screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Database
  // IsarService auto-initializes in its constructor.

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const XScanApp(),
    ),
  );
}

class XScanApp extends ConsumerWidget {
  const XScanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final dynamicEnabled = ref.watch(dynamicColorProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final light = dynamicEnabled && lightDynamic != null
            ? lightDynamic.harmonized()
            : null;
        final dark = dynamicEnabled && darkDynamic != null
            ? darkDynamic.harmonized()
            : null;
        return MaterialApp(
          title: 'XScan',
          theme: AppTheme.buildLight(light),
          darkTheme: AppTheme.buildDark(dark),
          themeMode: themeMode,
          home: const _RootGate(),
        );
      },
    );
  }
}

/// Shows onboarding on first launch, then the (optionally locked) app.
class _RootGate extends ConsumerStatefulWidget {
  const _RootGate();

  @override
  ConsumerState<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<_RootGate> {
  late bool _onboardingDone;

  @override
  void initState() {
    super.initState();
    _onboardingDone =
        ref.read(settingsServiceProvider).getOnboardingDone();
  }

  @override
  Widget build(BuildContext context) {
    if (!_onboardingDone) {
      return OnboardingScreen(
        onDone: () {
          ref.read(settingsServiceProvider).setOnboardingDone(true);
          setState(() => _onboardingDone = true);
        },
      );
    }
    return const LockGate();
  }
}
