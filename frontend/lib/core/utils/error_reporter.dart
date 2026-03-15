import 'package:sentry_flutter/sentry_flutter.dart';

/// Centralized error reporting utility.
///
/// Wraps Sentry SDK calls so that error reporting can be easily
/// swapped or extended without touching every call site.
/// When SENTRY_DSN is empty, Sentry is disabled and calls are no-ops.
class ErrorReporter {
  /// Capture an exception with optional stack trace and context tag.
  static void captureException(
    dynamic exception, {
    dynamic stackTrace,
    String? context,
  }) {
    Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      withScope: context != null
          ? (scope) {
              scope.setTag('context', context);
            }
          : null,
    );
  }
}
