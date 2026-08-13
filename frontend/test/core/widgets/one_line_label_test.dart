import 'package:budget_book/core/widgets/one_line_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double width = 200, double textScale = 1.0}) {
  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

double _renderedFontSize(WidgetTester tester) =>
    tester.widget<Text>(find.byType(Text)).style!.fontSize!;

void main() {
  setUp(OneLineLabel.clearCache);

  testWidgets('keeps the base size when the text fits', (tester) async {
    await tester.pumpWidget(
      _host(const OneLineLabel('현금', baseFontSize: 16), width: 300),
    );
    expect(_renderedFontSize(tester), 16);
  });

  testWidgets('shrinks instead of truncating when the text is long',
      (tester) async {
    const longName = '카카오뱅크 생활비 공동통장';
    await tester.pumpWidget(
      _host(const OneLineLabel(longName, baseFontSize: 16), width: 110),
    );
    final size = _renderedFontSize(tester);
    expect(size, lessThan(16));
    expect(size, greaterThanOrEqualTo(OneLineLabel.defaultMinFontSize));
    expect(tester.takeException(), isNull);
  });

  testWidgets('never goes below the minimum size', (tester) async {
    await tester.pumpWidget(
      _host(
        const OneLineLabel('아주아주아주아주아주 긴 결제수단 이름입니다',
            baseFontSize: 16, minFontSize: 12),
        width: 40,
      ),
    );
    expect(_renderedFontSize(tester), 12);
  });

  testWidgets('renders on one line with ellipsis as the last resort',
      (tester) async {
    await tester.pumpWidget(
      _host(const OneLineLabel('아주아주 긴 이름', baseFontSize: 16), width: 40),
    );
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('shrinks further under a 1.3x system text scale',
      (tester) async {
    const name = '카카오뱅크 생활비';
    await tester.pumpWidget(
      _host(const OneLineLabel(name, baseFontSize: 16), width: 120),
    );
    final atNormalScale = _renderedFontSize(tester);

    OneLineLabel.clearCache();
    await tester.pumpWidget(
      _host(const OneLineLabel(name, baseFontSize: 16),
          width: 120, textScale: 1.3),
    );
    expect(_renderedFontSize(tester), lessThanOrEqualTo(atNormalScale));
  });

  group('fitFontSize', () {
    const style = TextStyle(fontSize: 16);

    test('returns the base size for an unbounded width', () {
      expect(
        OneLineLabel.fitFontSize(
          text: '무한폭',
          maxWidth: double.infinity,
          baseFontSize: 16,
          minFontSize: 12,
          style: style,
          textScaler: TextScaler.noScaling,
        ),
        16,
      );
    });

    test('returns the base size for empty text', () {
      expect(
        OneLineLabel.fitFontSize(
          text: '',
          maxWidth: 10,
          baseFontSize: 16,
          minFontSize: 12,
          style: style,
          textScaler: TextScaler.noScaling,
        ),
        16,
      );
    });

    test('stays within [min, base]', () {
      for (final width in <double>[10, 30, 60, 120, 400]) {
        final size = OneLineLabel.fitFontSize(
          text: '카카오뱅크 생활비 공동통장',
          maxWidth: width,
          baseFontSize: 16,
          minFontSize: 12,
          style: style,
          textScaler: TextScaler.noScaling,
        );
        expect(size, inInclusiveRange(12, 16), reason: 'width=$width');
      }
    });

    test('is monotonic — a wider box never yields a smaller size', () {
      double sizeAt(double width) => OneLineLabel.fitFontSize(
            text: '카카오뱅크 생활비 공동통장',
            maxWidth: width,
            baseFontSize: 16,
            minFontSize: 12,
            style: style,
            textScaler: TextScaler.noScaling,
          );
      var previous = 0.0;
      for (var width = 20.0; width <= 400; width += 20) {
        final current = sizeAt(width);
        expect(current, greaterThanOrEqualTo(previous), reason: 'width=$width');
        previous = current;
      }
    });

    test('memoizes repeated measurements', () {
      OneLineLabel.clearCache();
      double call() => OneLineLabel.fitFontSize(
            text: '반복 측정',
            maxWidth: 60,
            baseFontSize: 16,
            minFontSize: 12,
            style: style,
            textScaler: TextScaler.noScaling,
          );
      final first = call();
      expect(call(), first);
      expect(call(), first);
    });
  });

  testWidgets('200 rows build within the frame budget', (tester) async {
    OneLineLabel.clearCache();
    final stopwatch = Stopwatch()..start();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(360, 4000)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 200; i++)
                  SizedBox(
                    width: 140,
                    height: 18,
                    child: OneLineLabel('카카오뱅크 생활비 $i', baseFontSize: 15),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    stopwatch.stop();
    expect(tester.takeException(), isNull);
    expect(
      stopwatch.elapsedMilliseconds,
      lessThan(3000),
      reason: '200 OneLineLabel rows took ${stopwatch.elapsedMilliseconds}ms',
    );
  });
}
