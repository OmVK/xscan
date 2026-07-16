import 'package:local_auth/local_auth.dart';

/// Thin wrapper around [LocalAuthentication] for the app lock.
class BiometricService {
  final _auth = LocalAuthentication();

  /// Whether the device can perform any biometric/device-credential auth.
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported || canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the user to authenticate. Returns true on success.
  Future<bool> authenticate({
    String reason = 'Unlock XScan',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
