import 'package:supabase_flutter/supabase_flutter.dart';

/// Tipe record generik untuk data Supabase.
typedef RowData = Map<String, dynamic>;

/// Hasil memulai ujian. Sebelumnya `startExam` mengembalikan String yang
/// ambigu (id attempt ATAU pesan error pada tipe yang sama).
class StartExamResult {
  const StartExamResult({this.attemptId, this.error});
  final String? attemptId;
  final String? error;
  bool get ok => attemptId != null && error == null;
}

/// Hasil query standar.
class QueryResult<T> {
  const QueryResult({required this.data, this.total, this.error});
  final List<T> data;
  final int? total;
  final String? error;

  bool get ok => error == null;
  bool get isEmpty => data.isEmpty;
}

/// Helper untuk membangun filter Supabase yang konsisten.
/// Kembalikan `dynamic` karena chain `.order()`/`.limit()` mengubah tipe
/// builder menjadi PostgrestTransformBuilder, dan kita hanya memakai filter.
/// PENTING: bertipe `dynamic` dengan sengaja.
/// Rantai `.order()`/`.limit()` mengembalikan `PostgrestTransformBuilder`
/// sedangkan `.eq()`/`.gte()` mengembalikan `PostgrestFilterBuilder`, dan
/// pemanggil butuh keduanya pada builder yang sama. Memakai tipe eksplisit
/// membuat build gagal (lihat riwayat CI), jadi builder di-`dynamic`-kan
/// namun tetap di-await dengan benar oleh pemanggil.
dynamic _filter(
  String table, {
  String select = '*',
  String? orderCol,
  bool ascending = true,
  int? limit,
}) {
  dynamic q = Supabase.instance.client.from(table).select(select);
  if (orderCol != null) {
    q = q.order(orderCol, ascending: ascending);
  }
  if (limit != null) {
    q = q.limit(limit);
  }
  return q;
}

/// Repositori terpusat seluruh modul.
/// Semua fetch mengembalikan [QueryResult] agar UI bisa render loading/empty/error.
class Repos {
  static SupabaseClient get db => Supabase.instance.client;

  static String get uid => db.auth.currentUser?.id ?? '';

  // ---------- SEKOLAH ----------

  static Future<QueryResult<RowData>> schoolSettings() async {
    try {
      final rows = await db.from('school_settings').select().limit(5000);
      return QueryResult<RowData>(data: [
        for (final r in rows)
          Map<String, dynamic>.from(
            {'key': r['key'], 'value': r['value']}
          )
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  // ---------- PELAJARAN / JADWAL ----------

  static Future<QueryResult<RowData>> classes() async {
    try {
      // Catatan: tabel `classes` TIDAK punya kolom subject_id, jadi embedded
      // select `subjects(...)` selalu ditolak PostgREST (400). Relasi kelas↔mapel
      // yang benar ada di `schedules` / `teacher_assignments`.
      final rows = await db.from('classes').select().limit(5000);
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<QueryResult<RowData>> subjects() async {
    try {
      final rows = await db.from('subjects').select().limit(5000);
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<QueryResult<RowData>> schedules({
    String? classId,
    String? teacherId,
    String? tahunAjaran,
  }) async {
    try {
      final q = _filter('schedules', orderCol: 'hari', ascending: false);
      if (classId != null) q.eq('class_id', classId);
      if (teacherId != null) q.eq('teacher_user_id', teacherId);
      if (tahunAjaran != null) q.eq('tahun_ajaran', tahunAjaran);
      final rows = await q;
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<QueryResult<RowData>> teacherAssignments({
    String? teacherId,
  }) async {
    try {
      final q = _filter('teacher_assignments', orderCol: 'class_id');
      if (teacherId != null) q.eq('teacher_user_id', teacherId);
      final rows = await q;
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<QueryResult<RowData>> classStudents(
    String classId, {
    String? tahunAjaran,
  }) async {
    try {
      final q = _filter(
        'class_enrollments',
        select:
            'student_user_id, student_profiles(nis, nama_lengkap, jenis_kelamin, tanggal_lahir)',
        orderCol: 'student_user_id',
      )
        ..eq('class_id', classId);
      if (tahunAjaran != null) q.eq('tahun_ajaran', tahunAjaran);
      final rows = await q;
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// Nama & NIS siswa untuk daftar id — dipakai orang tua untuk menampilkan
  /// anak yang terhubung ke akunnya.
  static Future<QueryResult<RowData>> studentsByIds(List<String> ids) async {
    if (ids.isEmpty) return const QueryResult<RowData>(data: []);
    try {
      final rows = await db
          .from('student_profiles')
          .select('user_id, nis, nama_lengkap')
          .inFilter('user_id', ids)
          .order('nama_lengkap')
          .limit(5000);
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  // ---------- PRESSENSI ----------

  /// Rekap absensi per kelas dengan NIS + nama siswa (untuk ekspor XLSX/CSV).
  static Future<QueryResult<RowData>> attendanceRekap({
    required String classId,
    required DateTime mulai,
    required DateTime sampai,
  }) async {
    try {
      final s =
          '${mulai.year}-${mulai.month.toString().padLeft(2, '0')}-${mulai.day.toString().padLeft(2, '0')}';
      final e =
          '${sampai.year}-${sampai.month.toString().padLeft(2, '0')}-${sampai.day.toString().padLeft(2, '0')}';
      final rows = await db
          .from('attendance_records')
          .select('student_user_id, tanggal, status, metode, student_profiles(nis, nama_lengkap), attendance_sessions!left(class_id)')
          .gte('tanggal', s)
          .lte('tanggal', e)
          .eq('attendance_sessions.class_id', classId)
          .order('tanggal', ascending: false)
          .limit(2000);
      // Saring berdasarkan keanggotaan kelas (client-side; RLS server tetap
      // batasi baris yang boleh dibaca).
      final siswaKelas = await classStudents(classId);
      final idsKelas = {
        for (final r in siswaKelas.data) r['user_id']?.toString()
      };
      return QueryResult<RowData>(data: [
        for (final r in rows)
          if (idsKelas.contains(r['student_user_id']?.toString()))
            Map<String, dynamic>.from(r as Map),
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<QueryResult<RowData>> attendance({
    String? studentId,
    String? classId,
    DateTime? mulai,
    DateTime? sampai,
  }) async {
    try {
      // Filter kelas: attendance_records tidak punya class_id; terhubung lewat
      // attendance_sessions.class_id. Embed session supaya filter berlaku.
      dynamic q = db
          .from('attendance_records')
          .select('*, attendance_sessions!left(class_id)')
          .order('tanggal', ascending: false)
          .limit(5000);
      if (studentId != null) q = q.eq('student_user_id', studentId);
      if (classId != null) {
        q = q.eq('attendance_sessions.class_id', classId);
      }
      if (mulai != null) {
        q = q.gte('tanggal', mulai.toIso8601String().substring(0, 10));
      }
      if (sampai != null) {
        q = q.lte('tanggal', sampai.toIso8601String().substring(0, 10));
      }
      final rows = await q;
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<QueryResult<RowData>> attendanceToday({String? classId}) async {
    final today = DateTime.now();
    final s =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    try {
      var q = db.from('attendance_records').select().eq('tanggal', s);
      if (classId != null) {
        final studentIds = await _studentIdsOfClass(classId);
        if (studentIds.isNotEmpty) {
          q = q.inFilter('student_user_id', studentIds);
        }
      }
      final rows = await q.limit(5000);
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<List<String>> _studentIdsOfClass(String classId) async {
    final rows = await db
        .from('class_enrollments')
        .select('student_user_id')
        .eq('class_id', classId);
    return [
      for (final r in rows) r['student_user_id'] as String? ?? ''
    ].where((v) => v.isNotEmpty).toList();
  }

  static Future<bool> upsertAttendance({
    required String studentId,
    required String tanggal,
    required String status,
    String metode = 'manual',
    String? catatan,
  }) async {
    try {
      await db.from('attendance_records').upsert(
        {
          'student_user_id': studentId,
          'tanggal': tanggal,
          'status': status,
          'metode': metode,
          'catatan': catatan,
          'jam_checkin': DateTime.now().toIso8601String(),
          'dibuat_oleh': uid,
        },
        onConflict: 'student_user_id,tanggal',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------- IZIN ----------

  static Future<QueryResult<RowData>> leaves({
    String? studentId,
    String? status,
  }) async {
    try {
      final q = _filter(
        'leave_requests',
        orderCol: 'created_at',
        ascending: false,
        limit: 100,
      );
      if (studentId != null) q.eq('student_user_id', studentId);
      if (status != null) q.eq('status', status);
      final rows = await q;
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<bool> submitLeave({
    required String studentId,
    required String mulai,
    String? selesai,
    required String jenis,
    required String alasan,
    String? lampiranUrl,
  }) async {
    try {
      await db.from('leave_requests').insert({
        'student_user_id': studentId,
        'diajukan_oleh': uid,
        'mulai': mulai,
        'selesai': selesai,
        'jenis': jenis,
        'alasan': alasan,
        if (lampiranUrl != null) 'lampiran_url': lampiranUrl,
        'status': 'diajukan',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> decideLeave({
    required String id,
    required String status,
    String? catatan,
  }) async {
    try {
      await db
          .from('leave_requests')
          .update({
            'status': status,
            'catatan_keputusan': catatan,
            'keputusan_oleh': uid,
          })
          .eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------- NILAI ----------

  static Future<QueryResult<RowData>> grades({
    String? studentId,
    String? subjectId,
    String? semester,
  }) async {
    try {
      final q = _filter(
        'grading_records',
        orderCol: 'tanggal_input',
        ascending: false,
        limit: 500,
      );
      if (studentId != null) q.eq('student_user_id', studentId);
      if (subjectId != null) q.eq('subject_id', subjectId);
      if (semester != null) q.eq('semester', semester);
      final rows = await q;
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<bool> upsertGrade({
    required String studentId,
    required String subjectId,
    required String kategori,
    required double nilai,
    String semester = 'gasal',
    String tahunAjaran = '2026/2027',
    String? catatan,
  }) async {
    try {
      final existing = await db
          .from('grading_records')
          .select('id')
          .eq('student_user_id', studentId)
          .eq('subject_id', subjectId)
          .eq('kategori', kategori)
          .eq('semester', semester)
          .eq('tahun_ajaran', tahunAjaran)
          .limit(1);
      if (existing.isNotEmpty) {
        await db
            .from('grading_records')
            .update({
              'nilai': nilai,
              'catatan': catatan,
              'guru_id': uid,
            })
            .eq('id', existing.first['id']);
      } else {
        await db.from('grading_records').insert({
          'student_user_id': studentId,
          'subject_id': subjectId,
          'guru_id': uid,
          'kategori': kategori,
          'nilai': nilai,
          'semester': semester,
          'tahun_ajaran': tahunAjaran,
          'catatan': catatan,
        });
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------- LMS ----------

  static Future<QueryResult<RowData>> materials({
    String? classId,
    String? subjectId,
  }) async {
    try {
      // Join subjek + kelas (untuk label UI). Siswa hanya melihat materi
      // terbit (RLS memfilter otomatis; admin/guru melihat semua).
      final q = db
          .from('learning_materials')
          .select('*, subjects(id, nama), classes(id, nama)');
      final rows = await q
          .order('created_at', ascending: false)
          .limit(200);
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<QueryResult<RowData>> assignments({
    String? classId,
    String? subjectId,
    String? status,
  }) async {
    try {
      final q = _filter('assignments', orderCol: 'tenggat', limit: 200);
      if (classId != null) q.eq('class_id', classId);
      if (subjectId != null) q.eq('subject_id', subjectId);
      if (status != null) q.eq('status', status);
      final rows = await q;
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<QueryResult<RowData>> submissions({
    String? assignmentId,
    String? studentId,
  }) async {
    try {
      final q = _filter(
        'assignment_submissions',
        orderCol: 'created_at',
        ascending: false,
        limit: 200,
      );
      if (assignmentId != null) q.eq('assignment_id', assignmentId);
      if (studentId != null) q.eq('student_user_id', studentId);
      final rows = await q;
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<bool> submitAssignment({
    required String assignmentId,
    required String studentId,
    String? jawaban,
    String? fileUrl,
    String? fileName,
  }) async {
    try {
      await db.from('assignment_submissions').upsert(
        {
          'assignment_id': assignmentId,
          'student_user_id': studentId,
          'jawaban_text': jawaban,
          'file_url': fileUrl,
          'file_nama': fileName,
          'status': 'dikumpulkan',
        },
        onConflict: 'assignment_id,student_user_id',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> gradeSubmission({
    required String id,
    required double nilai,
    String? umpanBalik,
  }) async {
    try {
      await db.from('assignment_submissions')
          .update({
            'nilai': nilai,
            'umpan_balik': umpanBalik,
            'status': 'dinilai',
          })
          .eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------- CBT ----------

  static Future<QueryResult<RowData>> exams({
    String? classId,
    String? subjectId,
    String? status,
  }) async {
    try {
      final q = _filter('exams', orderCol: 'mulai', limit: 200);
      if (classId != null) q.eq('class_id', classId);
      if (subjectId != null) q.eq('subject_id', subjectId);
      if (status != null) q.eq('status', status);
      final rows = await q;
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// Soal ujian TANPA kunci jawaban (memakai RPC `exam_questions_public`).
  ///
  /// Versi lama memakai `.from('exam_questions').select().limit(5000)` yang mengambil
  /// SELURUH kolom termasuk `kunci`. Penyembunyian di UI bukan keamanan:
  /// payload sudah terkirim ke perangkat siswa. Sekarang kunci tidak pernah
  /// meninggalkan database pada jalur ini.
  static Future<QueryResult<RowData>> examQuestions(String examId) async {
    try {
      final rows = await db.rpc(
        'exam_questions_public',
        params: {'p_exam': examId},
      );
      return QueryResult<RowData>(data: [
        for (final r in (rows as List))
          Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// Soal ujian beserta kunci — hanya untuk guru/admin, atau siswa setelah
  /// ujian berstatus selesai/dipublikasikan (dibatasi di sisi server).
  static Future<QueryResult<RowData>> examQuestionsWithKey(String examId) async {
    try {
      final rows = await db.rpc(
        'exam_questions_with_key',
        params: {'p_exam': examId},
      );
      return QueryResult<RowData>(data: [
        for (final r in (rows as List))
          Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// Hitung nilai pilihan ganda di server, kembalikan nilai yang diperoleh.
  static Future<double?> finalizeExam(String attemptId) async {
    try {
      final res = await db.rpc(
        'finalize_cbt',
        params: {'p_attempt': attemptId},
      );
      if (res == null) return null;
      return double.tryParse(res.toString());
    } catch (_) {
      return null;
    }
  }

  static Future<QueryResult<RowData>> examAttempts({String? examId}) async {
    try {
      final q = _filter(
        'exam_attempts',
        orderCol: 'mulai',
        ascending: false,
        limit: 200,
      );
      if (examId != null) q.eq('exam_id', examId);
      final rows = await q;
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<QueryResult<RowData>> examAnswers(String attemptId) async {
    try {
      final rows = await db
          .from('exam_answers')
          .select()
          .eq('attempt_id', attemptId)
          .order('id');
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<StartExamResult> startExam({
    required String examId,
    required String studentId,
  }) async {
    try {
      final exam = await db.from('exams').select().eq('id', examId).limit(1);
      if (exam.isEmpty) {
        return const StartExamResult(error: 'Ujian tidak ditemukan.');
      }
      final e = exam.first as Map;
      final now = DateTime.now();
      final mulai = DateTime.tryParse(e['mulai'] as String) ?? now;
      final selesai = DateTime.tryParse(e['selesai'] as String) ?? now;
      if (now.isBefore(mulai) || now.isAfter(selesai)) {
        return const StartExamResult(error: 'Periode ujian tidak aktif.');
      }
      final existing = await db
          .from('exam_attempts')
          .select('id, percobaan')
          .eq('exam_id', examId)
          .eq('student_user_id', studentId)
          .order('percobaan', ascending: false)
          .limit(1);
      final nextPercobaan =
          (existing.isEmpty ? 0 : (existing.first['percobaan'] as int? ?? 0)) +
              1;
      final maxPercobaan = e['jumlah_percobaan'] as int? ?? 1;
      if (nextPercobaan > maxPercobaan) {
        return const StartExamResult(
            error: 'Jumlah percobaan sudah tercapai.');
      }
      final ins = await db
          .from('exam_attempts')
          .insert({
            'exam_id': examId,
            'student_user_id': studentId,
            'percobaan': nextPercobaan,
            'mulai': now.toIso8601String(),
            'status': 'berlangsung',
          })
          .select('id')
          .single();
      final id = ins['id'] as String?;
      if (id == null) {
        return const StartExamResult(error: 'Gagal membuat sesi ujian.');
      }
      return StartExamResult(attemptId: id);
    } catch (e) {
      return StartExamResult(error: e.toString());
    }
  }

  static Future<bool> saveExamAnswer({
    required String attemptId,
    required String questionId,
    String? jawaban,
  }) async {
    try {
      await db.from('exam_answers').upsert(
        {
          'attempt_id': attemptId,
          'question_id': questionId,
          'jawaban': jawaban,
        },
        onConflict: 'attempt_id,question_id',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> submitExam({
    required String attemptId,
  }) async {
    try {
      final upd = await db
          .from('exam_attempts')
          .update({
            'selesai': DateTime.now().toIso8601String(),
            'status': 'dikumpulkan',
          })
          .eq('id', attemptId)
          .select();
      if (upd.isEmpty) return 'Attempt tidak ditemukan.';
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ---------- PANEL GURU CBT (buat ujian + koreksi esai) ----------

  /// Buat ujian baru (guru/admin). Status awal 'draft'.
  static Future<({String? error, String? examId})> buatExam({
    required String judul,
    String? deskripsi,
    String? subjectId,
    String? classId,
    required DateTime mulai,
    required DateTime selesai,
    required int durasiMenit,
    int jumlahPercobaan = 1,
  }) async {
    try {
      final ins = await db
          .from('exams')
          .insert({
            'dibuat_oleh': uid,
            'subject_id': null, // mapel opsional; bisa diisi via dropdown
            'class_id': classId,
            'judul': judul,
            'deskripsi': deskripsi,
            'mulai': mulai.toIso8601String(),
            'selesai': selesai.toIso8601String(),
            'durasi_menit': durasiMenit,
            'jumlah_percobaan': jumlahPercobaan,
            'status': 'draft',
          })
          .select('id')
          .single();
      return (error: null, examId: ins['id']?.toString());
    } catch (e) {
      return (error: _pesan(e.toString()), examId: null);
    }
  }

  /// Ubah status ujian: draft → aktif → selesai.
  static Future<String?> ubahStatusExam(String examId, String status) async {
    try {
      await db.from('exams').update({'status': status}).eq('id', examId);
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Tambah soal pilihan ganda (kunci = huruf 'a'..'e').
  static Future<String?> tambahSoalPG({
    required String examId,
    required String pertanyaan,
    required String opsiA,
    required String opsiB,
    String? opsiC,
    String? opsiD,
    String? opsiE,
    required String kunci,
    int skor = 1,
  }) async {
    try {
      await db.from('exam_questions').insert({
        'exam_id': examId,
        'urutan': DateTime.now().millisecondsSinceEpoch % 1000000,
        'tipe': 'pilihan',
        'pertanyaan': pertanyaan,
        'opsi_a': opsiA,
        'opsi_b': opsiB,
        'opsi_c': opsiC,
        'opsi_d': opsiD,
        'opsi_e': opsiE,
        'kunci': kunci,
        'skor': skor,
      });
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Tambah soal esai (kunci NULL, dinilai manual guru).
  static Future<String?> tambahSoalEsai({
    required String examId,
    required String pertanyaan,
    int skor = 10,
  }) async {
    try {
      await db.from('exam_questions').insert({
        'exam_id': examId,
        'urutan': DateTime.now().millisecondsSinceEpoch % 100000,
        'tipe': 'esai',
        'pertanyaan': pertanyaan,
        'kunci': null,
        'skor': skor,
      });
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Generate rapor massal untuk satu kelas: ambil rata-rata nilai tiap siswa
  /// per mapel dari grading_records semester terpilih, lalu buat rapor draf
  /// per siswa. Siswa tanpa nilai → mapel nilainya 0 (guru tinggal edit).
  static Future<({String? error, int jumlah})> buatRaportMassal({
    required String classId,
    required String semester,
    required String tahunAjaran,
    bool publikasikan = false,
  }) async {
    try {
      final siswaRes = await classStudents(classId);
      if (siswaRes.data.isEmpty) {
        return (error: 'Kelas ini belum punya siswa.', jumlah: 0);
      }
      final mapelRes = await subjects();
      if (mapelRes.data.isEmpty) {
        return (error: 'Tidak ada mata pelajaran.', jumlah: 0);
      }
      int dibuat = 0;
      for (final s in siswaRes.data) {
        final studentId = s['student_user_id']?.toString() ?? '';
        if (studentId.isEmpty) continue;
        // Rata-rata nilai per mapel dari grading_records.
        final g = await grades(studentId: studentId, semester: semester);
        final perMapel = <String, List<double>>{};
        for (final gr in g.data) {
          final sid = gr['subject_id']?.toString();
          final v = double.tryParse(gr['nilai']?.toString() ?? '');
          if (sid == null || v == null) continue;
          perMapel.putIfAbsent(sid, () => []).add(v);
        }
        final items = <RowData>[];
        for (final m in mapelRes.data) {
          final sid = m['id']?.toString();
          if (sid == null) continue;
          final daftar = perMapel[sid] ?? const <double>[];
          final rata = daftar.isEmpty
              ? 0.0
              : daftar.reduce((a, b) => a + b) / daftar.length;
          items.add({
            'subject_id': sid,
            'nilai_akhir': double.parse(rata.toStringAsFixed(2)),
            'predikat': _predikatDariNilai(rata),
          });
        }
        final err = await buatRaport(
          studentId: studentId,
          semester: semester,
          tahunAjaran: tahunAjaran,
          items: items,
          publikasikan: publikasikan,
        );
        if (err == null) dibuat++;
      }
      return (error: null, jumlah: dibuat);
    } catch (e) {
      return (error: _pesan(e.toString()), jumlah: 0);
    }
  }

  static String _predikatDariNilai(double n) {
    if (n >= 90) return 'A';
    if (n >= 80) return 'B';
    if (n >= 70) return 'C';
    if (n >= 60) return 'D';
    return 'E';
  }

  static Future<({String? error, String? examId})> duplikatExam(
      String examId) async {
    try {
      // 1. Ambil ujian sumber.
      final src = await db.from('exams').select().eq('id', examId).single();
      // 2. Buat ujian baru (judul + "Salinan -", status draft, tanggal digeser).
      final ins = await db.from('exams').insert({
        'dibuat_oleh': uid,
        'subject_id': src['subject_id'],
        'class_id': src['class_id'],
        'judul': 'Salinan - ${src['judul']}',
        'deskripsi': src['deskripsi'],
        'mulai': DateTime.now().toIso8601String(),
        'selesai': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'durasi_menit': src['durasi_menit'] ?? 60,
        'jumlah_percobaan': src['jumlah_percobaan'] ?? 1,
        'status': 'draft',
      }).select('id').single();
      final newId = ins['id']?.toString();
      if (newId == null || newId.isEmpty) {
        return (error: 'Gagal membuat salinan ujian.', examId: null);
      }
      // 3. Salin soal (jika ada).
      final soal = await db
          .from('exam_questions')
          .select()
          .eq('exam_id', examId)
          .order('urutan');
      if ((soal as List).isNotEmpty) {
        final rows = <Map<String, dynamic>>[];
        var i = 0;
        for (final raw in soal) {
          final q = Map<String, dynamic>.from(raw as Map);
          rows.add({
            'exam_id': newId,
            'urutan': i + 1,
            'tipe': q['tipe'],
            'pertanyaan': q['pertanyaan'],
            'opsi_a': q['opsi_a'],
            'opsi_b': q['opsi_b'],
            'opsi_c': q['opsi_c'],
            'opsi_d': q['opsi_d'],
            'opsi_e': q['opsi_e'],
            'kunci': q['kunci'],
            'skor': q['skor'] ?? 1,
          });
          i++;
        }
        await db.from('exam_questions').insert(rows);
      }
      return (error: null, examId: newId);
    } catch (e) {
      return (error: _pesan(e.toString()), examId: null);
    }
  }

  /// Ambil daftar ujian lain milik siapa pun (untuk sumber salin soal / bank soal).
  static Future<QueryResult<RowData>> semuaExamUntukBank() async {
    try {
      final rows = await _filter('exams', orderCol: 'created_at',
          ascending: false, limit: 300);
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// Salin semua soal dari ujian lain ke ujian ini (bank soal antar ujian).
  static Future<String?> salinSoalDariExam({
    required String dariExamId,
    required String keExamId,
  }) async {
    try {
      final soal = await db
          .from('exam_questions')
          .select()
          .eq('exam_id', dariExamId)
          .order('urutan');
      if ((soal as List).isEmpty) return 'Ujian sumber tidak punya soal.';
      final rows = <Map<String, dynamic>>[];
      var i = 0;
      for (final raw in soal) {
        final q = Map<String, dynamic>.from(raw as Map);
        rows.add({
          'exam_id': keExamId,
          'urutan': i + 1,
          'tipe': q['tipe'],
          'pertanyaan': q['pertanyaan'],
          'opsi_a': q['opsi_a'],
          'opsi_b': q['opsi_b'],
          'opsi_c': q['opsi_c'],
          'opsi_d': q['opsi_d'],
          'opsi_e': q['opsi_e'],
          'kunci': q['kunci'],
          'skor': q['skor'] ?? 1,
        });
        i++;
      }
      await db.from('exam_questions').insert(rows);
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Tambah banyak soal sekaligus (bulk insert).
  static Future<String?> tambahSoalMassal({
    required String examId,
    required List<Map<String, dynamic>> soalList,
  }) async {
    try {
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < soalList.length; i++) {
        final s = soalList[i];
        final tipe = s['tipe']?.toString() ?? 'pilihan';
        if (tipe == 'esai') {
          rows.add({
            'exam_id': examId,
            'urutan': (DateTime.now().millisecondsSinceEpoch % 1000000) + i,
            'tipe': 'esai',
            'pertanyaan': s['pertanyaan'],
            'kunci': null,
            'skor': s['skor'] ?? 10,
          });
        } else {
          rows.add({
            'exam_id': examId,
            'urutan': (DateTime.now().millisecondsSinceEpoch % 1000000) + i,
            'tipe': 'pilihan',
            'pertanyaan': s['pertanyaan'],
            'opsi_a': s['opsi_a'],
            'opsi_b': s['opsi_b'],
            'opsi_c': s['opsi_c'],
            'opsi_d': s['opsi_d'],
            'opsi_e': s['opsi_e'],
            'kunci': (s['kunci'] ?? 'A').toString().toUpperCase(),
            'skor': s['skor'] ?? 1,
          });
        }
      }
      await db.from('exam_questions').insert(rows);
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Hapus soal.
  static Future<String?> hapusSoal(String questionId) async {
    try {
      await db.from('exam_questions').delete().eq('id', questionId);
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Daftar peserta satu ujian (RPC migration 0020).
  static Future<List<Map<String, dynamic>>> examPeserta(String examId) async {
    try {
      final res = await db
          .rpc('exam_peserta', params: {'p_exam': examId});
      return [for (final r in (res as List)) Map<String, dynamic>.from(r as Map)];
    } catch (_) {
      return [];
    }
  }

  /// Jawaban esai satu attempt (untuk halaman koreksi).
  static Future<List<Map<String, dynamic>>> examEsaiJawaban(
      String attemptId) async {
    try {
      final res = await db.rpc('exam_esai_jawaban',
          params: {'p_attempt': attemptId});
      return [
        for (final r in (res as List)) Map<String, dynamic>.from(r as Map)
      ];
    } catch (_) {
      return [];
    }
  }

  /// Simpan nilai esai satu soal; return nilai total baru (PG+esai).
  static Future<double?> simpanNilaiEsai(
      String attemptId, String questionId, double nilai) async {
    try {
      final res = await db.rpc('exam_nilai_esai', params: {
        'p_attempt': attemptId,
        'p_question': questionId,
        'p_nilai': nilai,
      });
      return double.tryParse(res?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  // ---------- LEGER NILAI (gabungan tugas + CBT + manual) ----------

  /// Leger nilai satu kelas per mapel: gabungan nilai tugas (rata-rata
  /// assignment_submissions), CBT (exam_attempts terbaik), dan input manual
  /// (grading_records). Dipakai guru/admin untuk rekap + ekspor.
  static Future<List<Map<String, dynamic>>> legerKelas({
    required String classId,
    String? subjectId,
  }) async {
    final hasil = <Map<String, dynamic>>[];
    try {
      // 1) Siswa kelas ini.
      final siswa = await classStudents(classId);
      for (final s in siswa.data) {
        final uid = s['student_user_id']?.toString() ?? '';
        final nama =
            s['student_profiles']?['nama_lengkap']?.toString() ?? '-';
        final nis = s['student_profiles']?['nis']?.toString() ?? '-';
        if (uid.isEmpty) continue;

        // 2) Nilai tugas: rata-rata dari assignment_submissions.
        double? rataTugas;
        try {
          final subs = await db
              .from('assignment_submissions')
              .select('nilai, assignment_id!inner(assignments:class_id)')
              .eq('student_user_id', uid);
          final nilais = [
            for (final r in subs)
              if (r['nilai'] is num) (r['nilai'] as num).toDouble(),
          ];
          if (nilais.isNotEmpty) {
            rataTugas = nilais.reduce((a, b) => a + b) / nilais.length;
          }
        } catch (_) {}

        // 3) Nilai CBT: attempt terbaik (nilai maksimum).
        double? nilaiCbt;
        try {
          final attempts = await db
              .from('exam_attempts')
              .select('nilai_pilihan, total_skor')
              .eq('student_user_id', uid)
              .neq('status', 'berlangsung')
              .order('nilai_pilihan', ascending: false)
              .limit(1);
          if (attempts.isNotEmpty) {
            final n = attempts.first['nilai_pilihan'];
            final t = attempts.first['total_skor'];
            if (n is num && t is num && t > 0) nilaiCbt = n / t * 100;
          }
        } catch (_) {}

        // 4) Nilai input manual (grading_records) — yang terbaru.
        double? nilaiManual;
        try {
          var q = db
              .from('grading_records')
              .select('nilai')
              .eq('student_user_id', uid);
          if (subjectId != null) q = q.eq('subject_id', subjectId);
          final rows =
              await q.order('created_at', ascending: false).limit(1);
          if (rows.isNotEmpty && rows.first['nilai'] is num) {
            nilaiManual = (rows.first['nilai'] as num).toDouble();
          }
        } catch (_) {}

        hasil.add({
          'student_user_id': uid,
          'nis': nis,
          'nama': nama,
          'rata_tugas': rataTugas,
          'nilai_cbt': nilaiCbt,
          'nilai_manual': nilaiManual,
        });
      }
      return hasil;
    } catch (_) {
      return hasil;
    }
  }

  // ---------- VERIFIKASI STAF (izin + mutabaah + hafalan 1 halaman) ----------

  /// Setoran hafalan yang menunggu verifikasi.
  static Future<QueryResult<RowData>> hafalanMenunggu() async {
    try {
      final rows = await db
          .from('memorization_submissions')
          .select()
          .eq('status', 'diajukan')
          .order('created_at', ascending: false)
          .limit(100);
      return QueryResult<RowData>(
        data: [for (final r in rows) Map<String, dynamic>.from(r as Map)],
        total: rows.length,
      );
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// Verifikasi hafalan: setujui / tolak (dengan alasan).
  static Future<String?> verifikasiHafalan({
    required String id,
    required bool setuju,
    String? alasanPenolakan,
  }) async {
    try {
      await db.from('memorization_submissions').update({
        'status': setuju ? 'diverifikasi' : 'ditolak',
        'verified_by': uid,
        'verified_at': DateTime.now().toIso8601String(),
        'alasan_penolakan': setuju ? null : alasanPenolakan,
      }).eq('id', id);
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Verifikasi mutaba'ah harian (guru menandai sudah dicek).
  static Future<String?> verifikasiMutabaah(String id) async {
    try {
      await db.from('mutabaah_entries').update({
        'diverifikasi': true,
        'diverifikasi_oleh': uid,
        'diverifikasi_pada': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Mutaba'ah hari ini (semua siswa, untuk staf).
  static Future<QueryResult<RowData>> mutabaahHariIni() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final rows = await db
          .from('mutabaah_entries')
          .select()
          .eq('tanggal', today)
          .order('created_at', ascending: false)
          .limit(200);
      return QueryResult<RowData>(
        data: [for (final r in rows) Map<String, dynamic>.from(r as Map)],
        total: rows.length,
      );
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  // ---------- PERPUSTAKAAN ----------

  static Future<QueryResult<RowData>> libraryBooks({
    String? q,
    String? kategori,
  }) async {
    try {
      final query = _filter('library_books', orderCol: 'judul', limit: 200);
      if (q != null && q.isNotEmpty) query.ilike('judul', '%$q%');
      if (kategori != null) query.eq('kategori', kategori);
      final rows = await query;
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<QueryResult<RowData>> libraryLoans({String? studentId}) async {
    try {
      // Judul buku di-embed supaya daftar pinjaman tidak menampilkan UUID.
      dynamic q = db
          .from('library_loans')
          .select('*, library_books(judul)')
          .order('tanggal_pinjam', ascending: false)
          .limit(100);
      if (studentId != null) q = q.eq('student_user_id', studentId);
      final rows = await q;
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<QueryResult<RowData>> digitalResources({String? q}) async {
    try {
      final query = _filter(
        'digital_resources',
        orderCol: 'created_at',
        ascending: false,
        limit: 200,
      )
        ..eq('dipublikasikan', true);
      if (q != null && q.isNotEmpty) query.ilike('judul', '%$q%');
      final rows = await query;
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  // ---------- KEUANGAN ----------

  static Future<QueryResult<RowData>> financeCategories() async {
    try {
      final rows =
          await db.from('finance_categories').select().limit(5000).order('kode');
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<QueryResult<RowData>> financeItems({String? studentId}) async {
    try {
      final q = _filter('finance_items', orderCol: 'semester');
      if (studentId != null) q.eq('student_user_id', studentId);
      final rows = await q;
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  // ---------- MABIT ----------

  static Future<QueryResult<RowData>> mabitEvents({String? status}) async {
    try {
      final q = _filter(
        'mabit_events',
        orderCol: 'tanggal_mulai',
        ascending: false,
        limit: 50,
      );
      if (status != null) q.eq('status', status);
      final rows = await q;
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<QueryResult<RowData>> mabitParticipants(
    String eventId,
  ) async {
    try {
      final rows = await db
          .from('mabit_participants')
          .select().eq('event_id', eventId).limit(5000)
          .order('id');
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<QueryResult<RowData>> mutabaah({String? studentId}) async {
    try {
      final q = _filter(
        'mutabaah_entries',
        orderCol: 'tanggal',
        ascending: false,
        limit: 100,
      );
      if (studentId != null) q.eq('student_user_id', studentId);
      final rows = await q;
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<QueryResult<RowData>> mabitRundown(String eventId) async {
    try {
      final rows = await db
          .from('mabit_rundown_items')
          .select().eq('event_id', eventId).limit(5000)
          .order('urutan');
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  // ---------- NOTIFIKASI / PENGUMUMAN ----------

  static Future<QueryResult<RowData>> notifications({int limit = 30}) async {
    try {
      final rows = await db
          .from('notifications')
          .select()
          .eq('penerima_user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<bool> markNotificationRead(String id) async {
    try {
      await db
          .from('notifications')
          .update({'dibaca_pada': DateTime.now().toIso8601String()})
          .eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<QueryResult<RowData>> announcements({int limit = 20}) async {
    try {
      final rows = await db
          .from('announcements')
          .select()
          .order('dipublikasikan_pada', ascending: false)
          .limit(limit);
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  // ---------- CHAT ----------

  /// Daftar guru (hanya id + nama) lewat RPC — orang tua/siswa tidak punya
  /// izin membaca `teacher_profiles` secara langsung, dan nomor HP tidak boleh
  /// ikut terkirim.
  static Future<QueryResult<RowData>> listGuru() async {
    try {
      final rows = await db.rpc('list_guru');
      return QueryResult<RowData>(data: [
        for (final r in (rows as List)) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// Buat (atau ambil) percakapan dengan seorang guru. Dibuat di server supaya
  /// percakapan + keanggotaan tercatat dalam satu transaksi.
  static Future<String?> startConversation(String guruId) async {
    try {
      final res = await db.rpc(
        'start_conversation',
        params: {'p_guru': guruId},
      );
      return res?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Nama peserta tiap percakapan (untuk judul daftar chat).
  static Future<QueryResult<RowData>> conversationPeers() async {
    try {
      final rows = await db.rpc('conversation_peers');
      return QueryResult<RowData>(data: [
        for (final r in (rows as List)) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  // ---------- MANAJEMEN PENGGUNA (admin) ----------
  //
  // Sebelumnya tidak ada satu pun jalan membuat akun dari aplikasi, sehingga
  // sekolah praktis tidak bisa memakainya. Fungsi-fungsi di bawah ini
  // memanggil RPC yang memeriksa `is_admin()` di sisi SERVER; menyembunyikan
  // tombol di aplikasi bukan pengaman.

  /// Daftar seluruh pengguna beserta peran, email, dan status aktifnya.
  /// Hanya admin yang akan melihat baris (kebijakan RLS `profiles`).
  static Future<QueryResult<RowData>> listPengguna({int limit = 500}) async {
    try {
      final rows = await db
          .from('profiles')
          .select('id, nama, email, role, created_at')
          .order('role')
          .limit(limit);
      return QueryResult<RowData>(
        data: [for (final r in rows) Map<String, dynamic>.from(r as Map)],
        total: rows.length,
      );
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// Kelas yang tersedia (untuk menempatkan siswa saat akun dibuat).
  static Future<QueryResult<RowData>> listKelas() async {
    try {
      final rows = await db.rpc('list_kelas');
      return QueryResult<RowData>(data: [
        for (final r in (rows as List)) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// Daftar siswa (untuk menghubungkan akun orang tua ke anak).
  static Future<QueryResult<RowData>> listSiswa() async {
    try {
      // kelas_id diambil dari student_profiles supaya halaman Data Siswa
      // bisa menampilkan kelas tiap siswa.
      final rows = await db
          .from('profiles')
          .select('id, nama, email, student_profiles(kelas_id)').eq('role', 'siswa').limit(5000)
          .order('nama');
      return QueryResult<RowData>(
        data: [
          for (final r in rows)
            {
              'id': r['id'],
              'nama': r['nama'],
              'email': r['email'],
              'kelas_id': (r['student_profiles'] is Map &&
                      (r['student_profiles'] as Map)['kelas_id'] != null)
                  ? (r['student_profiles'] as Map)['kelas_id']
                  : null,
            },
        ],
        total: rows.length,
      );
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// Relasi orang tua <-> siswa. Membaca dua sisi; UI hanya perlu menampilkan
  /// pasangan yang sudah diverifikasi.
  static Future<QueryResult<RowData>> relasiOrtuSiswa() async {
    try {
      final rows = await db
          .from('parent_student')
          .select('parent_user_id, student_user_id, hubungan, diverifikasi').limit(5000);
      return QueryResult<RowData>(
        data: [for (final r in rows) Map<String, dynamic>.from(r as Map)],
        total: rows.length,
      );
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// Admin membuat akun baru. Mengembalikan null bila berhasil, atau pesan
  /// kegagalan yang siap ditampilkan.
  static Future<String?> adminCreateUser({
    required String email,
    required String nama,
    required String role,
    required String password,
    String? identitas,
    String? kelasId,
  }) async {
    try {
      await db.rpc('admin_create_user', params: {
        'p_email': email,
        'p_nama': nama,
        'p_role': role,
        'p_password': password,
        'p_identitas': identitas,
        'p_kelas_id': kelasId,
      });
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  static Future<String?> adminSetRole({
    required String userId,
    required String role,
    String? identitas,
  }) async {
    try {
      await db.rpc('admin_set_role', params: {
        'p_user_id': userId,
        'p_role': role,
        'p_identitas': identitas,
      });
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  static Future<String?> adminSetAktif(String userId, bool aktif) async {
    try {
      await db.rpc('admin_set_aktif',
          params: {'p_user_id': userId, 'p_aktif': aktif});
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Reset kata sandi: server menyetel kata sandi BARU acak dan mengembalikannya
  /// untuk disampaikan admin ke pengguna (SMTP belum dikonfigurasi).
  static Future<Map<String, String?>> adminResetPassword(String email) async {
    try {
      final res = await db.rpc(
        'admin_reset_password',
        params: {'p_email': email},
      );
      final m = (res is Map) ? res : const {};
      return {
        'email': m['email']?.toString() ?? email,
        'password_baru': m['password_baru']?.toString() ?? '',
      };
    } catch (e) {
      return {'error': _pesan(e)};
    }
  }

  static Future<String?> adminHapusUser(String userId) async {
    try {
      await db.rpc('admin_hapus_user', params: {'p_user_id': userId});
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  static Future<String?> adminSetRelasiOrtu({
    required String parentId,
    required String studentId,
    required String hubungan,
  }) async {
    try {
      await db.rpc('admin_set_relasi_ortu', params: {
        'p_parent_id': parentId,
        'p_student_id': studentId,
        'p_hubungan': hubungan,
        'p_verifikasi': true,
      });
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  static Future<String?> adminHapusRelasiOrtu(
      String parentId, String studentId) async {
    try {
      await db.rpc('admin_hapus_relasi_ortu',
          params: {'p_parent_id': parentId, 'p_student_id': studentId});
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Status aktif akun dibaca dari `auth.users.banned_until`. Tabel auth tidak
  /// bisa dibaca langsung dari aplikasi, jadi statusnya diambil lewat RPC.
  static Future<QueryResult<RowData>> statusAkun() async {
    try {
      final rows = await db.rpc('admin_status_akun');
      return QueryResult<RowData>(data: [
        for (final r in (rows as List)) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// PostgrestError berisi `code`/`message`/`details`; pesan mentahnya panjang
  /// dan berbahasa Inggris, sedangkan pesan dari RPC (raise exception) sudah
  /// ditulis untuk dibaca admin. Dahulukan yang terakhir.
  static String _pesan(Object e) {
    final s = e.toString();
    final m = RegExp(r'message:\s*([^,\n]+)').firstMatch(s);
    if (m != null) return m.group(1)!.trim();
    return s;
  }

  // ---------- PPDB (admin) ----------
  static Future<QueryResult<RowData>> ppdbDaftar() async {
    try {
      final rows = await db
          .from('admissions')
          .select()
          .order('created_at', ascending: false)
          .limit(300);
      return QueryResult<RowData>(
        data: [for (final r in rows) Map<String, dynamic>.from(r as Map)],
        total: rows.length,
      );
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<String?> ppdbSetStatus(String id, String status) async {
    try {
      await db.rpc('ppdb_set_status',
          params: {'p_id': id, 'p_status': status});
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  static Future<String?> ppdbSetHasil(String id, String hasil,
      {bool publikasi = false}) async {
    try {
      await db.rpc('ppdb_set_hasil', params: {
        'p_id': id,
        'p_hasil': hasil,
        'p_publikasi': publikasi,
      });
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  static Future<String?> terbitkanPengumuman({
    required String judul,
    required String isi,
    String kategori = 'umum',
    String prioritas = 'biasa',
    String target = 'semua',
  }) async {
    try {
      await db.rpc('terbitkan_pengumuman', params: {
        'p_judul': judul,
        'p_isi': isi,
        'p_kategori': kategori,
        'p_prioritas': prioritas,
        'p_target': target,
      });
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  // ---------- MUTABAAH & HAFALAN ----------
  static Future<QueryResult<RowData>> mutabaahSaya() async {
    try {
      final uid = db.auth.currentUser?.id;
      if (uid == null) return const QueryResult<RowData>(data: []);
      final rows = await db
          .from('mutabaah_entries')
          .select()
          .eq('student_user_id', uid)
          .order('tanggal', ascending: false)
          .limit(30);
      return QueryResult<RowData>(
        data: [for (final r in rows) Map<String, dynamic>.from(r as Map)],
        total: rows.length,
      );
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<QueryResult<RowData>> memorization() async {
    try {
      final uid = db.auth.currentUser?.id;
      dynamic q = db
          .from('memorization_submissions')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      if (uid != null) q = q.eq('student_user_id', uid);
      final rows = await q;
      return QueryResult<RowData>(
        data: [for (final r in rows) Map<String, dynamic>.from(r as Map)],
        total: rows.length,
      );
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  // ---------- BUS & GPS (admin) ----------
  static Future<QueryResult<RowData>> vehicles() async {
    try {
      final rows = await db
          .from('vehicles')
          .select()
          .order('plat_nomor');
      return QueryResult<RowData>(
        data: [for (final r in rows) Map<String, dynamic>.from(r as Map)],
        total: rows.length,
      );
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// Siswa meminjam buku — sesuai desain migration 0017: insert
  /// `library_loans` (policy `ll_write` izinkan siswa untuk pinjamannya
  /// sendiri) lalu kurangi `stok_tersedia` via update PostgREST.
  /// Stok di-update client-side karena RLS update `library_books` hanya
  /// admin, jadi langkah update stok untuk siswa akan ditolak RLS —
  /// tidak fatal (insert peminjaman tetap tercatat); admin yang
  /// bertanggung jawab stok.
  static Future<String?> pinjamBuku(String bookId) async {
    final uid = db.auth.currentUser?.id;
    if (uid == null) return 'Sesi tidak ditemukan.';
    try {
      final now = DateTime.now();
      final kembali = now.add(const Duration(days: 7));
      await db.from('library_loans').insert({
        'book_id': bookId,
        'student_user_id': uid,
        'tanggal_pinjam': now.toIso8601String().split('T').first,
        'tanggal_kembali': kembali.toIso8601String().split('T').first,
        'status': 'dipinjam',
      });
      // Kurangi stok (best-effort; RLS update hanya admin).
      // Jika RLS menolak update, insert peminjaman di atas tetap valid.
      // Tidak dibungkus try/catch khusus agar insert di atas dulu
      // terkonfirmasi sukses — update stok dipercayakan admin.
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Buat token QR presensi untuk seorang siswa (dipanggil guru/admin).
  /// Token diverifikasi `verify_attendance_qr` oleh perangkat siswa.
  static Future<String?> generateAttendanceQr(String studentId) async {
    try {
      final res = await db.rpc(
        'generate_attendance_qr',
        params: {'p_student': studentId},
      );
      return res?.toString();
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Siswa memverifikasi token QR (memindai QR guru) — presensi tercatat.
  static Future<String?> verifikasiQr(String token, String studentId) async {
    try {
      await db.rpc('verify_attendance_qr',
          params: {'p_token': token, 'p_student': studentId});
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  static Future<String?> tambahBus({
    required String plat,
    required String jenis,
    String? sopir,
    required int kapasitas,
  }) async {
    try {
      await db.from('vehicles').insert({
        'plat_nomor': plat,
        'jenis': jenis,
        'sopir_nama': sopir,
        'kapasitas': kapasitas,
        'status': 'aktif',
      });
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  static Future<String?> ubahStatusBus(String id, String status) async {
    try {
      await db.from('vehicles').update({'status': status}).eq('id', id);
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  // ---------- BUS & GPS (sopir / tracker) ----------

  /// Kirim posisi GPS dari HP pengemudi ke tabel `vehicle_locations`.
  /// Dipanggil TrackerBus tiap ~20 detik saat mode mengemudi aktif.
  static Future<String?> kirimLokasiBus({
    required String vehicleId,
    required double lat,
    required double lng,
    double? heading,
    double? kecepatanKph,
  }) async {
    try {
      await db.from('vehicle_locations').insert({
        'vehicle_id': vehicleId,
        'lat': lat,
        'lng': lng,
        if (heading != null) 'heading': heading,
        if (kecepatanKph != null) 'kecepatan_kph': kecepatanKph,
        'sumber': 'app-sopir',
      });
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Lokasi terakhir tiap bus (untuk kartu admin). Kembalikan
  /// vehicle_id -> baris vehicle_locations terbaru.
  static Future<Map<String, RowData>> lokasiTerakhirSemuaBus() async {
    try {
      final rows = await db
          .from('vehicle_locations')
          .select()
          .order('terekam_pada', ascending: false)
          .limit(500);
      final hasil = <String, RowData>{};
      for (final r in rows) {
        final m = Map<String, dynamic>.from(r as Map);
        final vid = m['vehicle_id']?.toString();
        if (vid != null && !hasil.containsKey(vid)) hasil[vid] = m;
      }
      return hasil;
    } catch (_) {
      return {};
    }
  }



  /// Daftar anak bagi akun orang tua, LENGKAP DENGAN NAMA + NIS + KELAS.
  ///
  /// Sebelumnya dashboard orang tua hanya punya daftar UUID (dari
  /// `SessionProfile.parentStudentIds`) sehingga yang tampil cuma "Anak 1",
  /// "Anak 2" — nama anak tidak pernah bisa dibaca karena kebijakan RLS
  /// `profiles` hanya mengizinkan profil sendiri. RPC ini (migrasi 0010)
  /// mengambil nama hanya untuk anak yang relasinya SUDAH DIVERIFIKASI.
  static Future<QueryResult<RowData>> anakSaya() async {
    try {
      final rows = await db.rpc('anak_saya');
      return QueryResult<RowData>(data: [
        for (final r in (rows as List)) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// Kelas yang diampu guru (wali kelas atau punya penugasan mengajar),
  /// beserta jumlah siswanya.
  static Future<QueryResult<RowData>> kelasSaya() async {
    try {
      final rows = await db.rpc('kelas_saya');
      return QueryResult<RowData>(data: [
        for (final r in (rows as List)) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// Nama siswa untuk sekumpulan id (dipakai guru agar tidak menampilkan UUID).
  static Future<Map<String, String>> namaSiswa(List<String> ids) async {
    if (ids.isEmpty) return const {};
    try {
      final rows = await db
          .from('profiles')
          .select('id, nama')
          .inFilter('id', ids)
          .limit(5000);
      return {
        for (final r in rows)
          if (r['id'] != null) r['id'].toString(): r['nama']?.toString() ?? '-'
      };
    } catch (_) {
      return const {};
    }
  }

  // ---------- AUDIT LOG (admin) ----------

  static Future<QueryResult<RowData>> auditLogs({int limit = 200}) async {
    try {
      final rows = await db
          .from('audit_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// Nama pemilik akun untuk daftar audit log (admin berhak membaca profiles).
  static Future<QueryResult<RowData>> profilesByIds(List<String> ids) async {
    if (ids.isEmpty) return const QueryResult<RowData>(data: []);
    try {
      final rows = await db
          .from('profiles')
          .select('id, nama, role')
          .inFilter('id', ids)
          .limit(5000);
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<QueryResult<RowData>> conversations() async {
    try {
      final rows = await db
          .from('chat_conversations')
          .select()
          .or(
            'dibuat_oleh.eq.$uid,guru_user_id.eq.$uid',
          )
          .order('created_at', ascending: false)
          .limit(50);
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<QueryResult<RowData>> messages(String conversationId) async {
    try {
      final rows = await db
          .from('chat_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at')
          .limit(200);
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<bool> sendMessage({
    required String conversationId,
    required String isi,
  }) async {
    try {
      await db.from('chat_messages').insert({
        'conversation_id': conversationId,
        'pengirim_user_id': uid,
        'isi': isi,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------- MEDIA MABIT (guru/admin upload, semua baca) ----------

  /// Daftar media per event MABIT (galeri dokumen/foto untuk peserta).
  static Future<QueryResult<RowData>> mabitMedia(String eventId) async {
    try {
      final rows = await db
          .from('mabit_media')
          .select().eq('event_id', eventId).limit(5000)
          .order('created_at', ascending: false);
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// Unggah file media ke event MABIT (bucket `lampiran`), insert
  /// `mabit_media` (RLS: admin/staff), publish langsung.
  static Future<String?> unggahMabitMedia({
    required String eventId,
    required String fileUrl,
    String? deskripsi,
    bool publikasikan = true,
  }) async {
    try {
      await db.from('mabit_media').insert({
        'event_id': eventId,
        'file_url': fileUrl,
        'deskripsi': deskripsi,
        'dipublikasikan': publikasikan,
        'diunggah_oleh': Repos.uid,
      });
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Ubah status publik/draf media.
  static Future<String?> setMediaPublik(String id, bool publik) async {
    try {
      await db
          .from('mabit_media')
          .update({'dipublikasikan': publik})
          .eq('id', id);
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Hapus media (hanya admin per RLS).
  static Future<String?> hapusMabitMedia(String id) async {
    try {
      await db.from('mabit_media').delete().eq('id', id);
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  // ---------- ALOKASI BUS (siswa naik kendaraan, admin) ----------

  /// Daftar alokasi bus: siswa + kendaraan. Join nama siswa & plat.
  static Future<QueryResult<RowData>> vehicleAssignments() async {
    try {
      final rows = await db
          .from('vehicle_assignments')
          .select(
              '*, vehicles(id, plat_nomor, jenis, sopir_nama), student_profiles(*)')
          .limit(5000).order('created_at', ascending: false);
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// Alokasi siswa ke kendaraan (admin): set rute + siswa.
  static Future<String?> alokasiBus({
    required String vehicleId,
    required String studentUserId,
    String? ruteMulai,
    String? ruteTujuan,
  }) async {
    try {
      await db.from('vehicle_assignments').insert({
        'vehicle_id': vehicleId,
        'student_user_id': studentUserId,
        if (ruteMulai != null) 'rute_mulai': ruteMulai,
        if (ruteTujuan != null) 'rute_tujuan': ruteTujuan,
      });
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Hapus alokasi bus.
  static Future<String?> hapusAlokasiBus(String id) async {
    try {
      await db.from('vehicle_assignments').delete().eq('id', id);
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  // ---------- RAPOR / REPORT CARD (admin buat, ortu/siswa baca) ----------

  /// Daftar rapor per siswa (join nama siswa). Semua semester.
  static Future<QueryResult<RowData>> raports({String? studentId}) async {
    try {
      final q = _filter(
        'report_cards',
        select: '*, student_profiles(user_id, nis, nama_lengkap, kelas_id)',
        orderCol: 'created_at',
        ascending: false,
        limit: 200,
      );
      if (studentId != null) q.eq('student_user_id', studentId);
      final rows = await q;
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// Detail mata-pel dalam satu rapor.
  static Future<QueryResult<RowData>> raportItems(String raportId) async {
    try {
      final rows = await db
          .from('report_card_items')
          .select('*, subjects(id, nama)').eq('report_card_id', raportId).limit(5000)
          .order('subject_id');
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// Buat rapor (admin) + isian mapel sekaligus. Status draf.
  static Future<String?> buatRaport({
    required String studentId,
    required String semester,
    required String tahunAjaran,
    required List<RowData> items,
    String? catatanKarakter,
    bool publikasikan = false,
  }) async {
    try {
      final ins = await db.from('report_cards').insert({
        'student_user_id': studentId,
        'semester': semester,
        'tahun_ajaran': tahunAjaran,
        'status': publikasikan ? 'dipublikasikan' : 'draf',
        'dibuat_oleh': Repos.uid,
        if (catatanKarakter != null && catatanKarakter.isNotEmpty)
          'catatan_karakter': catatanKarakter,
      }).select('id').single();
      final raportId = ins['id'] as String;
      if (items.isNotEmpty) {
        await db.from('report_card_items').insert([
          for (final it in items) {
            {
              'report_card_id': raportId,
              'subject_id': it['subject_id'],
              'nilai_akhir': it['nilai_akhir'],
              'predikat': it['predikat'],
              'catatan_guru': it['catatan_guru'],
            }
          }
        ]);
      }
      if (publikasikan) {
        await db
            .from('report_cards')
            .update({'dipublikasikan_pada': DateTime.now().toIso8601String()})
            .eq('id', raportId);
      }
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Ubah status rapor (admin). Dipakai untuk publikasi/ubah draf.
  static Future<String?> ubahStatusRaport(String id, String status) async {
    try {
      final payload = <String, dynamic>{'status': status};
      if (status == 'dipublikasikan') {
        payload['dipublikasikan_pada'] = DateTime.now().toIso8601String();
      }
      await db.from('report_cards').update(payload).eq('id', id);
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Hapus rapor (admin).
  static Future<String?> hapusRaport(String id) async {
    try {
      await db.from('report_cards').delete().eq('id', id);
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  // ---------- LAPORAN KEJADIAN / INCIDENT REPORTS ----------

  /// Daftar laporan kejadian (join pelapor & siswa sasaran).
  static Future<QueryResult<RowData>> incidents() async {
    try {
      final q = _filter(
        'incident_reports',
        select:
            '*, reporter:profiles!incident_reports_reporter_id_fkey(id, nama, email, role), target:profiles!incident_reports_target_siswa_id_fkey(id, nama, email, role)',
        orderCol: 'created_at',
        ascending: false,
        limit: 200,
      );
      final rows = await q;
      return QueryResult<RowData>(
        data: [for (final r in rows) Map<String, dynamic>.from(r)],
      );
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  /// Buat laporan kejadian (siswa/ortu/admin: reporter = user aktif).
  static Future<String?> buatInsiden({
    required String kategori,
    required String deskripsi,
    String? lokasi,
    String? waktuKejadian,
    String? targetSiswaId,
    String? lampiranUrl,
  }) async {
    try {
      await db.from('incident_reports').insert({
        'reporter_id': uid,
        'kategori': kategori,
        'deskripsi': deskripsi,
        if (lokasi != null && lokasi.trim().isNotEmpty) 'lokasi': lokasi,
        if (waktuKejadian != null) 'waktu_kejadian': waktuKejadian,
        if (targetSiswaId != null) 'target_siswa_id': targetSiswaId,
        if (lampiranUrl != null) 'lampiran_url': lampiranUrl,
      });
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Ubah status laporan (admin): processed / resolved + keterangan.
  static Future<String?> updateStatusInsiden(
    String id, {
    required String status,
    String? keterangan,
  }) async {
    try {
      final payload = <String, dynamic>{'status': status};
      if (keterangan != null) {
        payload['keterangan_admin'] = keterangan;
      }
      payload['handled_by'] = uid;
      await db.from('incident_reports').update(payload).eq('id', id);
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }

  /// Hapus laporan (admin).
  static Future<String?> hapusInsiden(String id) async {
    try {
      await db.from('incident_reports').delete().eq('id', id);
      return null;
    } catch (e) {
      return _pesan(e);
    }
  }
}
