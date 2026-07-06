import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// Opens the gallery picker and uploads the chosen image as multipart
/// `avatar` to [path] (e.g. `/api/me/avatar`). Returns true on success.
/// Mirrors handleUserAvatarUpload / the actor upload in the Vue app.
Future<bool> pickAndUploadAvatar(BuildContext context, String path,
    {String successMessage = 'Avatar updated successfully!'}) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 800,
    maxHeight: 800,
    imageQuality: 85,
  );
  if (picked == null || !context.mounted) return false;
  final bytes = await picked.readAsBytes();
  if (!context.mounted) return false;
  final app = context.read<AppState>();
  return app.runAction(() async {
    await app.api.uploadFile(path,
        field: 'avatar', bytes: bytes, filename: picked.name);
  }, successMessage);
}
