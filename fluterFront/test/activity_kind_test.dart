import 'package:flutter_test/flutter_test.dart';

import 'package:carecoins_flutter/widgets/ui.dart';

/// The subclass discriminator the timeline reads (docs/personal-time-plan.md §4).
/// The risk it guards against is a row written before `kind` existed being
/// mistaken for personal time and losing its coin treatment.
void main() {
  group('isSelfActivity', () {
    test('a self row is personal time, whatever its type', () {
      expect(isSelfActivity({'category': 'self', 'type': 'sport'}), isTrue);
      expect(isSelfActivity({'category': 'self', 'type': 'appointment'}), isTrue);
    });

    test('a care row is family work', () {
      expect(isSelfActivity({'category': 'care', 'type': 'household'}), isFalse);
    });

    test('a legacy row with no category at all is family work', () {
      expect(isSelfActivity({'type': 'care', 'coin_value': 5}), isFalse);
      expect(isSelfActivity({'category': null}), isFalse);
    });

    test('an unrecognised category is family work, never personal time', () {
      expect(isSelfActivity({'category': 'coverage'}), isFalse);
      expect(isSelfActivity({'category': ''}), isFalse);
    });
  });
}
