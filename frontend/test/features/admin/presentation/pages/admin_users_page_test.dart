import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/features/admin/presentation/pages/admin_users_page.dart';

void main() {
  group('AdminUsersPage', () {
    testWidgets('is a StatefulWidget', (tester) async {
      expect(const AdminUsersPage(), isA<StatefulWidget>());
    });
  });
}
