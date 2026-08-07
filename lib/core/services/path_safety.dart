// Pure helpers for verifying paths extracted from archives. No platform
// plugins, so fully unit-testable on the Dart VM.

import 'package:path/path.dart' as p;

/// Returns true if [entryPath] (an archive entry name) resolves to a file
/// inside [basePath] — i.e. it is not a zip-slip / path-traversal attempt.
///
/// The check is done on *canonicalized* absolute paths so `..`, `.`,
/// redundant separators and backslash tricks are all resolved first. A sibling
/// directory that merely shares a prefix with [basePath] is rejected because
/// the resolved path must equal [basePath] or start with `basePath/`.
bool zipEntryIsSafe(String basePath, String entryPath) {
  // Archive entries must never be absolute paths (drives, /etc, UNC, …).
  // Reject them before any joining — otherwise an absolute entry like
  // `C:\evil` would simply be joined onto the base instead of escaping it.
  if (p.isAbsolute(entryPath)) return false;

  final base = p.canonicalize(p.absolute(basePath));
  final target = p.canonicalize(p.join(base, entryPath));

  final prefix = base.endsWith(p.separator) ? base : '$base${p.separator}';
  return target == base || target.startsWith(prefix);
}