import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

/// Upload file ke Supabase Storage bucket `lampiran` (publik-read).
///
/// App target: Android-only, tapi tidak pakai `dart:io` —
/// `PlatformFile.readAsBytes()` dari file_picker 13.x cukup.
///
/// API file_picker 13.x (federated): `FilePicker.pickFile()` adalah
/// **static method** (bukan `FilePicker.platform.pickFiles`), return
/// `PlatformFile?` (null = user batal), bytes dibaca via
/// `file.readAsBytes()` (async, `Future<Uint8List>`).
///
/// Alur tipikal:
/// ```dart
/// final url = await Lampiran.pickAndUpload(
///   allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
/// );
/// ```
class Lampiran {
  /// Pick file dari file manager / gallery user.
  /// Return null kalau user batal.
  static Future<({String name, Uint8List bytes})?> pickFile({
    List<String>? allowedExtensions,
  }) async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (f == null) return null;
    final bytes = await f.readAsBytes();
    return (name: f.name, bytes: bytes);
  }

  /// Pick + upload sekaligus. Return public URL, atau null kalau batal.
  static Future<String?> pickAndUpload({
    List<String>? allowedExtensions,
  }) async {
    final picked = await pickFile(allowedExtensions: allowedExtensions);
    if (picked == null) return null;
    return await upload(picked.bytes, picked.name);
  }

  /// Upload bytes ke bucket, return **public URL** (simpan ke DB).
  static Future<String> upload(
    Uint8List bytes,
    String filename, {
    String? mimeType,
  }) async {
    final client = supa.Supabase.instance.client;
    final uid = client.auth.currentUser?.id ?? 'anon';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safe = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final target = '$uid/$ts-$safe';

    await client.storage.from('lampiran').uploadBinary(
          target,
          bytes,
          fileOptions: supa.FileOptions(
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
