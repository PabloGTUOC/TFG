import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carecoins_flutter/widgets/ui.dart';

void main() {
  testWidgets('UI kit smoke test: VButton, KpiCard and PillBadge render',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              VButton(child: Text('Sign In')),
              KpiCard(label: 'Family coins', value: '120', unit: 'cc'),
              PillBadge(text: '+5cc'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('FAMILY COINS'), findsOneWidget);
    expect(find.text('+5cc'), findsOneWidget);
  });
}
