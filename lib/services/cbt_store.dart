import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'repositories.dart';

/// Penyimpanan LOKAL jawaban ujian (anti-hilang walau HP mati / offline).
///
/// Desain (port dari cbt-sekolah):
/// - Setiap perubahan jawaban LANGSUNG disimpan ke SharedPreferences
///   (instan, tanpa internet) — listrik mati / force-close pun aman.
/// - Server di-flush batched tiap 2 menit, bukan tiap tap (anti rate-limit).
/// - Key unik per attempt: `cbt_jwb_<attemptId>`.
class CbtJawabanStore {
  final String attemptId;
  CbtJawabanStore(this.attemptId);

  String get _key => 'cbt_jwb_$attemptId';

  Future<void> saveAll(
      Map<String, String?> jawaban, Map<String, bool> ragu) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final data = <String, dynamic>{
        for (final e in jawaban.entries)
          e.key: {'jawaban': e.value ?? '', 'ragu': ragu[e.key] ?? false},
      };
      await sp.setString(_key, jsonEncode(data));
    } catch (_) {}
  }

  Future<Map<String, Map<String, dynamic>>> loadAll() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_key);
      if (raw == null) return {};
      final m = jsonDecode(raw);
      if (m is! Map) return {};
      return {
        for (final e in m.entries)
          '${e.key}': Map<String, dynamic>.from(e.value as Map),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> markSynced(Set<String> ids) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList('${_key}_synced', ids.toList());
    } catch (_) {}
  }

  Future<Set<String>> getSynced() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return (sp.getStringList('${_key}_synced') ?? []).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> clear() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_key);
      await sp.remove('${_key}_synced');
    } catch (_) {}
  }
}

/// Hasil memulai sesi ujian via RPC exam_session_start.
class CbtSesi {
  final bool ok;
  final String? error;
  final String? attemptId;
  final int sisaDetik;
  final int percobaan;
  final List<Map<String, dynamic>> soal;
  final Map<String, ({String? jawaban, bool ragu})> jawaban;

  const CbtSesi({
    this.ok = false,
    this.error,
    this.attemptId,
    this.sisaDetik = 0,
    this.percobaan = 1,
    this.soal = const [],
    this.jawaban = const {},
  });
}

/// Endpoint RPC ekosistem pengerjaan CBT (migration 0019).
class CbtApi {
  CbtApi._();

  /// Mulai/lanjut sesi ujian. Return CbtSesi.
  static Future<CbtSesi> start(String examId) async {
    try {
      final res = await Repos.db.rpc('exam_session_start',
          params: {'p_exam': examId});
      final m = Map<String, dynamic>.from(res as Map);
      final jw = Map<String, dynamic>.from(m['jawaban'] as Map? ?? {});
      return CbtSesi(
        ok: true,
        attemptId: m['attempt_id']?.toString(),
        sisaDetik: (m['sisa_detik'] as num?)?.toInt() ?? 0,
        percobaan: (m['percobaan'] as num?)?.toInt() ?? 1,
        soal: [
          for (final s in (m['soal'] as List? ?? []))
            Map<String, dynamic>.from(s as Map),
        ],
        jawaban: {
          for (final e in m['jawaban'].entries)
            e.key.toString(): (
              jawaban: (e.value as Map)['jawaban']?.toString(),
              ragu: e.value['ragu'] == true,
            ),
        },
      );
    } catch (e) {
      return CbtSesi(ok: false, error: e.toString());
    }
  }

  /// Simpan jawaban + flag ragu ke server (RPC, idempotent).
  static Future<bool> saveAnswer(
      String attemptId, String questionId, String? jawaban, bool ragu) async {
    try {
      await Repos.db.rpc('exam_save_answer', params: {
        'p_attempt': attemptId,
        'p_question': questionId,
        'p_jawaban': jawaban ?? '',
        'p_ragu': ragu,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Kumpulkan ujian (idempotent) + nilai PG otomatis.
  static Future<({bool ok, String? error, double? nilai})> submit(
      String attemptId) async {
    try {
      final res = await Repos.db
          .rpc('exam_submit', params: {'p_attempt': attemptId});
      final n = double.tryParse(res?.toString() ?? '');
      return (ok: true, error: null, nilai: n);
    } catch (e) {
      return (ok: false, error: e.toString(), nilai: null);
    }
  }

  /// Catat pelanggaran (keluar app / overlay). Diam-diam — kegagalan diabaikan.
  static Future<void> pelanggaran(String attemptId) async {
    try {
      await Repos.db.rpc('exam_pelanggaran', params: {'p_attempt': attemptId});
    } catch (_) {}
  }

}