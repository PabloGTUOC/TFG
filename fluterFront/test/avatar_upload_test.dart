import 'package:flutter_test/flutter_test.dart';

import 'package:carecoins_flutter/utils/avatar_upload.dart';

/// The server type-checks the multipart part (ALLOWED_MIME_TYPES in
/// routes/me.js), and the http package labels an untyped part
/// `application/octet-stream` — which that filter refuses. So the bytes have
/// to name themselves correctly here.
void main() {
  test('recognizes the three types the server accepts', () {
    expect(sniffImageMime([0xFF, 0xD8, 0xFF, 0xE0, 0x00]), 'image/jpeg');
    expect(
        sniffImageMime([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]),
        'image/png');
    expect(
        sniffImageMime([
          0x52, 0x49, 0x46, 0x46, // RIFF
          0x00, 0x00, 0x00, 0x00, // size
          0x57, 0x45, 0x42, 0x50, // WEBP
        ]),
        'image/webp');
  });

  test('refuses HEIC, which is what an iPhone photo actually is', () {
    // ....ftypheic — no JPEG/PNG/WebP magic, so it must not be sent as one.
    final heic = [
      0x00, 0x00, 0x00, 0x18,
      0x66, 0x74, 0x79, 0x70, // ftyp
      0x68, 0x65, 0x69, 0x63, // heic
    ];
    expect(sniffImageMime(heic), isNull);
  });

  test('refuses empty and truncated input rather than guessing', () {
    expect(sniffImageMime([]), isNull);
    expect(sniffImageMime([0xFF, 0xD8]), isNull, reason: 'truncated JPEG magic');
    expect(sniffImageMime([0x89, 0x50, 0x4E]), isNull);
    expect(sniffImageMime([0x52, 0x49, 0x46, 0x46, 0x00]), isNull,
        reason: 'RIFF without the WEBP tag is some other RIFF container');
  });
}
