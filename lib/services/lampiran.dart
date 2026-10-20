import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

/// Upload file ke Supabase Storage bucket `lampiran` (publik-read).
///
/// App target: Android-only, jadi `dart:io` aman dipakai.
///
/// API file_picker 13.x: `FileType` enum (image, video, audio, media,
/// custom, any) + `allowedExtensions` untuk custom. Gak ada
/// `FilePickerType` / `FilePickerFileType` / `withReadPermission`.
///
/// Alur tipikal:
/// ```dart
/// // PDF + gambar:
/// final url = await Lampiran.pickAndUpload(
///   type: FileType.custom,
///   allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
/// );
///
/// // Video + audio:
/// final url = await Lampiran.pickAndUpload(type: FileType.media);
/// ```
class Lampiran {
  /// Pick file dari file manager / gallery user.
  /// Return null kalau user batal.
  ///
  /// [type] = kategori umum (FileType.image, .video, .audio, .media,
  /// .custom, .any). Untuk `FileType.custom`, kirim [allowedExtensions]
  /// (list ext tanpa titik, mis. `['pdf', 'docx']`).
  static Future<({String path, String name, String mime})?> pickFile({
    FileType type = FileType.custom,
    List<String> allowedExtensions = const [],
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions:
          type == FileType.custom ? allowedExtensions : null,
      withData: false,
    );
    if (result == null) return null;
    final f = result.first;
    final name = f.name;
    final path = f.path ?? '';
    if (path.isEmpty) return null; // web-only edge case, diabaikan.
    return (path: path, name: name, mime: _guessMime(name));
  }

  /// Pick + upload sekaligus. Return public URL, atau null kalau batal.
  static Future<String?> pickAndUpload({
    FileType type = FileType.custom,
    List<String> allowedExtensions = const [],
  }) async {
    final picked = await pickFile(
      type: type,
      allowedExtensions: allowedExtensions,
    );
    if (picked == null) return null;
    final bytes = File(picked.path).readAsBytesSync();
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

    await client.storage.from('lampiran').uploadBinary(
          target,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType ?? _guessMime(filename),
            upsert: false,
          ),
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
      case 'm4a':
        return 'audio/mp4';
      case 'wav':
        return 'audio/wav';
      case 'mp4':
      case 'mov':
        return 'video/mp4';
      case '3gp':
        return 'video/3gpp';
      default:
        return 'application/octet-stream';
    }
  }
}
