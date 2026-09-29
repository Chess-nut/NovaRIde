import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Thrown when a pick/upload step fails, with a message safe to show
/// directly to the rider (no stack traces, no raw HTTP error bodies).
class AvatarUploadException implements Exception {
  final String message;
  const AvatarUploadException(this.message);

  @override
  String toString() => message;
}

/// Picks a photo (camera or gallery) and uploads it to Cloudinary as the
/// rider's avatar, using an unsigned upload preset.
class AvatarUploadService {
  const AvatarUploadService._();

  static const String _cloudName = 'uh7e9vl1';
  static const String _uploadPreset = 'NovaRide';

  static final ImagePicker _picker = ImagePicker();

  static bool get isConfigured =>
      _cloudName != 'YOUR_CLOUD_NAME' && _uploadPreset != 'YOUR_UPLOAD_PRESET';

  /// Returns the uploaded photo's URL, or null if the rider cancelled the
  /// picker (no error in that case — cancelling isn't a failure). Throws
  /// [AvatarUploadException] on a real failure, including "not configured
  /// yet" so that reads like a setup step, not a crash.
  static Future<String?> pickAndUpload({
    required ImageSource source,
    required String riderId,
  }) async {
    if (!isConfigured) {
      throw const AvatarUploadException(
        'Photo upload isn\'t set up yet — add your Cloudinary cloud name '
        'and upload preset in avatar_upload_service.dart.',
      );
    }

    final XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } catch (_) {
      throw AvatarUploadException(
        source == ImageSource.camera
            ? 'Couldn\'t open the camera. Check camera permission and try again.'
            : 'Couldn\'t open your photos. Check photo permission and try again.',
      );
    }

    if (picked == null) return null; // rider backed out of the picker

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['public_id'] = riderId
      ..fields['folder'] = 'avatars';

    try {
      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes('file', await picked.readAsBytes(), filename: '$riderId.jpg'),
        );
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', picked.path));
      }

      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode != 200) {
        throw AvatarUploadException(
          'Upload failed (${streamed.statusCode}). Double-check your Cloudinary '
          'cloud name and upload preset.',
        );
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final url = decoded['secure_url'] as String?;
      if (url == null) {
        throw const AvatarUploadException('Upload succeeded but Cloudinary returned no URL.');
      }
      return url;
    } on AvatarUploadException {
      rethrow;
    } catch (_) {
      throw const AvatarUploadException('Upload failed — check your connection and try again.');
    }
  }
}