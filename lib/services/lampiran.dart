import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

/// Upload file ke Supabase Storage bucket `lampiran` (publik-read).
///
/// App target: Android-only, jadi `dart:io` aman dipakai.
///
/// Alur tipikal:
/// ```dart
/// final url = await Lampiran.pickAndUpload(
///   types: const [FilePickerType.image, FilePickerType.pdf],
/// );
/// // simpan url ke kolom `lampiran_url` / `file_url` di DB
/// ```
class Lampiran {
  /// Pick file dari gallery / file manager user.
  /// Return null kalau user batal.
  static Future<({String path, String name, String mime})?> pickFile({
    required List<FilePickerType> types,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FilePickerFileType.custom(types),
      withReadPermission: true,
    );
    if (result == null) return null;
    final f = result.files.first;
    final name = f.name;
    final path = f.path ?? '';
    if (path.isEmpty) return null; // web-only edge case, diabaikan.
    return (path: path, name: name, mime: _guessMime(name));
  }

  /// Pick + upload sekaligus. Return public URL, atau null kalau batal.
  static Future<String?> pickAndUpload({
    required List<FilePickerType> types,
  }) async {
    final picked = await pickFile(types: types);
    if (picked == null) return null;
    final bytes = await File(picked.path).readAsBytes();
    return await upload(bytes, picked.name, mimeType: picked.mime);
  }

  /// Upload bytes ke bucket, return **public URL** (simpan ke DB).
  static Future<String> upload(
    List<int> bytes,
    String filename, {
    String? mimeType,
  }) async {
    final client = supa.Supabase.instance.client;
    final uid = client.auth.currentUser?.id ?? 'anon';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safe = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final target = '$uid/${ts}-$safe';

    await client.storage.from('lampiran').upload(
          target,
          bytes,
          contentType: mimeType ?? _guessMime(filename),
          upsert: false,
        );

    final url = client.storage.from('lampiran').getPublicUrl(target);
    debugPrint('Lampiran uploaded: $url');
    return url;
  }

  static String _guessMime(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'zip':
        return 'application/zip';
      case 'mp3':
        return 'audio/mpeg';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }
}
