import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ICU lets a plural use `#` for the count, but Flutter's `gen-l10n` does not
/// substitute it — it copies each branch verbatim into `Intl.pluralLogic`, so a
/// `#` reaches the screen as a literal `#`. It looks correct in the ARB and
/// wrong in the app, in every language at once, which is exactly the kind of
/// bug that survives review. Use the placeholder name instead: `{count}`.
void main() {
  final arbs = Directory('lib/l10n')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.arb'))
      .toList();

  test('there are ARB files to check', () {
    expect(arbs, isNotEmpty);
  });

  for (final file in arbs) {
    test('${file.uri.pathSegments.last} has no bare # in a plural', () {
      final map = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      final offenders = <String>[];

      map.forEach((key, value) {
        if (key.startsWith('@') || value is! String) return;
        final plural = RegExp(r'^\{(\w+),\s*plural,').firstMatch(value);
        if (plural != null && value.contains('#')) {
          offenders.add('$key -> use {${plural.group(1)}} instead of #');
        }
      });

      expect(offenders, isEmpty,
          reason: 'gen-l10n renders these as a literal "#":\n'
              '${offenders.join('\n')}');
    });
  }
}
