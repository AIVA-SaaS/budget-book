import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/widgets/announcement_banner.dart';

void main() {
  group('AnnouncementBanner', () {
    testWidgets('is a StatefulWidget', (tester) async {
      expect(const AnnouncementBanner(), isA<StatefulWidget>());
    });
  });
}
