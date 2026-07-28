import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Sends an accessibility announcement via SemanticsService.
void sendAnnouncement(BuildContext context, String message) {
  try {
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      TextDirection.ltr,
    );
  } catch (_) {}
}

/// Shows a frosted glass confirmation dialog and returns true if confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = 'Delete',
  String cancelLabel = 'Cancel',
  Color? confirmColor,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final glassColor = isDark
      ? const Color(0xFF181824).withValues(alpha: 0.85)
      : Colors.white.withValues(alpha: 0.90);
  final borderColor = isDark
      ? Colors.white.withValues(alpha: 0.18)
      : Colors.black.withValues(alpha: 0.08);

  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.40),
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: AlertDialog(
        backgroundColor: glassColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: borderColor, width: 1.2),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: confirmColor != null
                ? FilledButton.styleFrom(backgroundColor: confirmColor)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
  return result == true;
}
