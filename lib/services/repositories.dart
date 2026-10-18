import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase/supabase.dart';

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
      final rows = await db.from('school_settings').select();
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
      final rows = await db.from('classes').select();
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  static Future<QueryResult<RowData>> subjects() async {
    try {
      final rows = await db.from('subjects').select();
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
          .order('nama_lengkap');
      return QueryResult<RowData>(data: [
        for (final r in rows) Map<String, dynamic>.from(r as Map)
      ]);
    } catch (e) {
      return QueryResult<RowData>(data: [], error: e.toString());
    }
  }

  // ---------- PRESSENSI ----------

  static Future<QueryResult<RowData>> attendance({
    String? studentId,
    String? classId,
    DateTime? mulai,
    DateTime? sampai,
  }) async {
    try {
      final q = _filter(
        'attendance_records',
        orderCol: 'tanggal',
        ascending: false,
        limit: 200,
      );
      if (studentId != null) q.eq('student_user_id', studentId);
      if (mulai != null) {
        q.gte('tanggal', mulai.toIso8601String().substring(0, 10));
      }
      if (sampai != null) {
        q.lte('tanggal', sampai.toIso8601String().substring(0, 10));
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
      final q = db.from('attendance_records').select().eq('tanggal', s);
      if (classId != null) {
        final studentIds = await _studentIdsOfClass(classId);
        if (studentIds.isNotEmpty) {
          q.inFilter('student_user_id', studentIds);
        }
      }
      final rows = await q;
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
  }) async {
    try {
      await db.from('leave_requests').insert({
        'student_user_id': studentId,
        'diajukan_oleh': uid,
        'mulai': mulai,
        'selesai': selesai,
        'jenis': jenis,
        'alasan': alasan,
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
      final q = _filter(
        'learning_materials',
        orderCol: 'created_at',
        ascending: false,
        limit: 200,
      );
      if (classId != null) q.eq('class_id', classId);
      if (subjectId != null) q.eq('subject_id', subjectId);
      final rows = await q;
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
  /// Versi lama memakai `.from('exam_questions').select()` yang mengambil
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
      final q = _filter(
        'library_loans',
        orderCol: 'tanggal_pinjam',
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
          await db.from('finance_categories').select().order('kode');
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
          .select()
          .eq('event_id', eventId)
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
          .select()
          .eq('event_id', eventId)
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
}
