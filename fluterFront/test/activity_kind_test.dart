import 'package:flutter_test/flutter_test.dart';

import 'package:carecoins_flutter/widgets/ui.dart';

/// The subclass discriminator the timeline reads (docs/personal-time-plan.md §4).
/// The risk it guards against is a row written before `kind` existed being
/// mistaken for personal time and losing its coin treatment.
void main() {
  group('isSelfActivity', () {
    test('a row with kind self is personal time', () {
      expect(isSelfActivity({'kind': 'self', 'category': null}), isTrue);
    });

    test('a row with kind care is family work', () {
      expect(isSelfActivity({'kind': 'care', 'category': 'household'}), isFalse);
    });

    test('a legacy row with no kind at all is family work', () {
      expect(isSelfActivity({'category': 'care', 'coin_value': 5}), isFalse);
      expect(isSelfActivity({'kind': null}), isFalse);
    });

    test('an unrecognised kind is treated as family work, never as personal', () {
      expect(isSelfActivity({'kind': 'coverage'}), isFalse);
      expect(isSelfActivity({'kind': ''}), isFalse);
    });
  });
}
