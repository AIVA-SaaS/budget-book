import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/utils/error_reporter.dart';

void main() {
  group('ErrorReporter', () {
    test('captureException does not throw when Sentry is not initialized', () {
      // When SENTRY_DSN is empty, Sentry is disabled and calls are no-ops.
      // This test verifies that calling captureException does not crash.
      expect(
        () => ErrorReporter.captureException(
          Exception('test error'),
          stackTrace: StackTrace.current,
          context: 'test',
        ),
        returnsNormally,
      );
    });

    test('captureException works without optional parameters', () {
      expect(
        () => ErrorReporter.captureException(Exception('test error')),
        returnsNormally,
      );
    });

    test('captureException works with null context', () {
      expect(
        () => ErrorReporter.captureException(
          Exception('test error'),
          stackTrace: StackTrace.current,
          context: null,
        ),
        returnsNormally,
      );
    });
  });
}
