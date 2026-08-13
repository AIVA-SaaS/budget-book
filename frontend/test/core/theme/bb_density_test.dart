import 'package:budget_book/core/theme/bb_density.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BbDensity.forWidth boundaries', () {
    test('399 / 400 / 839 / 840 land on the intended tiers', () {
      expect(BbDensity.forWidth(320).tier, BbDensityTier.compact);
      expect(BbDensity.forWidth(399).tier, BbDensityTier.compact);
      expect(BbDensity.forWidth(400).tier, BbDensityTier.regular);
      expect(BbDensity.forWidth(839).tier, BbDensityTier.regular);
      expect(BbDensity.forWidth(840).tier, BbDensityTier.wide);
      expect(BbDensity.forWidth(1440).tier, BbDensityTier.wide);
    });

    test('metrics grow monotonically with the tier', () {
      const tiers = [BbDensity.compact, BbDensity.regular, BbDensity.wide];
      for (var i = 1; i < tiers.length; i++) {
        expect(tiers[i].tilePaddingH,
            greaterThanOrEqualTo(tiers[i - 1].tilePaddingH));
        expect(tiers[i].avatarSize, greaterThanOrEqualTo(tiers[i - 1].avatarSize));
        expect(tiers[i].titleFontSize,
            greaterThanOrEqualTo(tiers[i - 1].titleFontSize));
        expect(tiers[i].actionSlotSize,
            greaterThanOrEqualTo(tiers[i - 1].actionSlotSize));
      }
    });

    test('every tier keeps action tap targets at 40dp or more', () {
      for (final d in [BbDensity.compact, BbDensity.regular, BbDensity.wide]) {
        expect(d.actionSlotSize, greaterThanOrEqualTo(40),
            reason: '${d.tier} action slot is below the 40dp tap target');
      }
    });
  });

  testWidgets('BbDensity.of reads the MediaQuery width', (tester) async {
    late BbDensity seen;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(320, 640)),
        child: Builder(
          builder: (context) {
            seen = context.density;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen.tier, BbDensityTier.compact);
  });
}
