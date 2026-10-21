import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../../../services/cbt_store.dart';
import '../../../services/exam_kiosk.dart';
import '../../../services/repositories.dart';
import '../../../widgets/app_states.dart';
import '../../../widgets/common.dart';

/// Halaman pengerjaan ujian CBT — port sistem pengerjaan cbt-sekolah:
///
/// 1. Anti-cheat ringan (tanpa native): keluar-app = pelanggaran tercatat,
///    >3× auto-submit; back-button diblokir (PopScope) + dihitung pelanggaran.
/// 2. Timer SERVER-authoritative: sisa detik dari RPC `exam_session_start`,
///    reload/crash tidak menguntungkan siswa.
/// 3. Autosave 2 lapisan: lokal instan (SharedPreferences) + flush batched
///    tiap 2 menit ke server. Resume otomatis dari HP bila server kosong.
/// 4. Palet soal mengambang + flag "RAGU" per soal.
/// 5. Submit anti-hilang: flush retry 6×, submit idempotent retry 5×,
///    auto-submit saat waktu habis.
class ExamTakePage extends StatefulWidget {
  const ExamTakePage({
    super.key,
    required this.examId,
    required this.judul,
  });

  final String examId;
  final String judul;

  @override
  State<ExamTakePage> createState() => _ExamTakePageState();
}

class _ExamTakePageState extends State<ExamTakePage>
    with WidgetsBindingObserver {
  static const _penaltyLimit = 3;
  static const _flushInterval = Duration(minutes: 2);

  bool _loading = true;
  String? _error;
  String? _attemptId;
  List<Map<String, dynamic>> _soal = const [];
  final Map<String, String?> _jawaban = {};
  final Map<String, bool> _ragu = {};
  final Set<String> _belumKirim = {};
  CbtJawabanStore _store = CbtJawabanStore('');

  Timer? _timer;
  Timer? _flushTimer;
  int _sisaDetik = 0;
  int _idx = 0;
  bool _submitting = false;
  bool _sinkron = true;
  bool _showPalette = false;
  int _pelanggaran = 0;
  final Map<String, TextEditingController> _essayCtrl = {};

  TextEditingController _ctrlFor(String soalId) {
    return _essayCtrl.putIfAbsent(soalId, () {
      final c = TextEditingController(text: _jawaban[soalId] ?? '');
      c.selection = TextSelection.collapsed(offset: c.text.length);
      return c;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _mulai();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _flushTimer?.cancel();
    for (final c in _essayCtrl.values) {
      c.dispose();
    }
    ExamKiosk.alarmStop();
    ExamKiosk.setSecure(false);
    ExamKiosk.exitKiosk();
    ExamKiosk.detach();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _mulai() async {
    final sesi = await CbtApi.start(widget.examId);
    if (!mounted) return;
    if (!sesi.ok || sesi.attemptId == null) {
      setState(() {
        _loading = false;
        _error = sesi.error ?? 'Ujian tidak dapat dimulai.';
      });
      return;
    }

    _attemptId = sesi.attemptId;
    _store = CbtJawabanStore(_attemptId!);

    // Jawaban dari server dulu…
    for (final e in sesi.jawaban.entries) {
      _jawaban[e.key] = e.value.jawaban;
      _ragu[e.key] = e.value.ragu;
    }
    // …lalu resume dari LOKAL: jawaban di HP menang bila server kosong
    // (kasus: jawab lalu mati listrik sebelum sempat flush).
    try {
      final lokal = await _store.loadAll();
      for (final e in lokal.entries) {
        final v = e.value;
        if ((v['jawaban'] ?? '').toString().isNotEmpty ||
            (_jawaban[e.key] ?? '').isEmpty) {
          _jawaban[e.key] = (v['jawaban'] ?? '').toString();
          _ragu[e.key] = v['ragu'] == true;
        }
      }
      final synced = await _store.getSynced();
      for (final id in lokal.keys) {
        if (!synced.contains(id)) _belumKirim.add(id);
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = sesi.soal.isEmpty ? 'Ujian ini belum memiliki soal.' : null;
      _soal = sesi.soal;
      _sisaDetik = sesi.sisaDetik;
    });
    if (sesi.soal.isNotEmpty) {
      _startTimer();
      _startFlush();
      // Mode ujian native: FLAG_SECURE + immersive + soft kiosk.
      await ExamKiosk.setSecure(true);
      await ExamKiosk.enterKiosk();
      ExamKiosk.onIntrusion(() {
        if (!mounted || _submitting) return;
        _pelanggaran++;
        CbtApi.pelanggaran(_attemptId!);
        ExamKiosk.alarmStart();
        if (_pelanggaran > _penaltyLimit) _submit(otomatis: true);
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_sisaDetik <= 1) {
        t.cancel();
        setState(() => _sisaDetik = 0);
        _submit(otomatis: true);
        return;
      }
      setState(() => _sisaDetik--);
    });
  }

  String get _sisaLabel {
    final m = (_sisaDetik ~/ 60).toString().padLeft(2, '0');
    final s = (_sisaDetik % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Flush jawaban yang belum tersinkron (batch — anti rate-limit).
  Future<void> _flushKeServer() async {
    if (_attemptId == null || _belumKirim.isEmpty) return;
    final ids = _belumKirim.toList();
    for (final id in ids) {
      final ok = await CbtApi.saveAnswer(
          _attemptId!, id, _jawaban[id], _ragu[id] ?? false);
      if (ok) _belumKirim.remove(id);
      await Future.delayed(const Duration(milliseconds: 60));
    }
    try {
      final synced = await _store.getSynced();
      synced.addAll(ids.where((i) => !_belumKirim.contains(i)));
      await _store.markSynced(synced);
    } catch (_) {}
    if (mounted) setState(() => _sinkron = _belumKirim.isEmpty);
  }

  void _startFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) async {
      if (_belumKirim.isNotEmpty) await _flushKeServer();
    });
  }

  /// Simpan LOKAL saja (instan). Server menyusul via flush batched.
  Future<void> _saveJawaban(String soalId) async {
    _belumKirim.add(soalId);
    if (mounted) setState(() => _sinkron = false);
    await _store.saveAll(_jawaban, _ragu);
  }

  /// Lifecycle: keluar app saat ujian = pelanggaran (>limit → auto-submit).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_submitting || _attemptId == null) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pelanggaran++;
      CbtApi.pelanggaran(_attemptId!);
      if (_pelanggaran > _penaltyLimit) _submit(otomatis: true);
    }
  }

  void _pilih(String soalId, String jawaban) {
    setState(() => _jawaban[soalId] = jawaban);
    _belumKirim.add(soalId);
    _store.saveAll(_jawaban, _ragu);
  }

  void _toggleRagu(String soalId) {
    setState(() => _ragu[soalId] = !(_ragu[soalId] ?? false));
    _belumKirim.add(soalId);
    _store.saveAll(_jawaban, _ragu);
  }

  Future<void> _submit({bool otomatis = false}) async {
    if (_submitting || _attemptId == null) return;

    if (!otomatis) {
      final terjawab =
          _jawaban.values.where((v) => v != null && v!.isNotEmpty).length;
      final ok = await showConfirmDialog(
        context,
        judul: 'Kirim jawaban?',
        pesan: 'Anda menjawab $terjawab dari ${_soal.length} soal. '
            'Setelah dikirim, jawaban tidak dapat diubah.',
        tombolYa: 'Kirim',
      );
      if (!ok) return;
    }

    setState(() => _submitting = true);
    _timer?.cancel();

    // 1) Pastikan semua jawaban ke server (retry 6×).
    for (int i = 0; i < 6; i++) {
      await _flushKeServer();
      if (_belumKirim.isEmpty) break;
      await Future.delayed(const Duration(seconds: 2));
    }
    // 2) Submit idempotent + retry 5×.
    var hasil = await CbtApi.submit(_attemptId!);
    for (int attempt = 0; !hasil.ok && attempt < 5; attempt++) {
      await Future.delayed(Duration(seconds: 2 + attempt * 2));
      hasil = await CbtApi.submit(_attemptId!);
    }
    if (!hasil.ok) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showToast(
        context,
        'Jaringan bermasalah — jawaban TERSIMPAN di server. '
        'Tap "Kirim" lagi saat sinyal pulih.',
        color: AppColors.danger,
      );
      _startTimer();
      return;
    }

    await _store.clear();
    _flushTimer?.cancel();
    _timer?.cancel();
    // Keluar mode ujian + matikan alarm.
    await ExamKiosk.alarmStop();
    await ExamKiosk.setSecure(false);
    await ExamKiosk.exitKiosk();
    ExamKiosk.detach();
    if (!mounted) return;
    Navigator.of(context).pop(
      otomatis
          ? 'Waktu habis — dikirim otomatis. Nilai PG: ${hasil.nilai ?? '-'}'
          : 'Jawaban terkirim. Nilai PG: '
              '${hasil.nilai?.toStringAsFixed(2) ?? 'menunggu koreksi esai'}',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kesalahan')),
        body: ErrorState(
          message: _error!,
          onRetry: () {
            setState(() {
              _loading = true;
              _error = null;
            });
            _mulai();
          },
        ),
      );
    }
    if (_soal.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ujian')),
        body: const Center(
            child: Text('Ujian tidak memiliki soal. Hubungi guru.')),
      );
    }

    final soal = _soal[_idx];
    final sid = soal['id']?.toString() ?? '';
    final tipe = soal['tipe']?.toString() ?? 'pilihan';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          CbtApi.pelanggaran(_attemptId ?? '');
          showToast(
            context,
            'Tombol kembali diblokir selama ujian — tercatat sebagai pelanggaran.',
            color: AppColors.danger,
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            Column(
              children: [
                _header(),
                LinearProgressIndicator(
                  value: (_idx + 1) / _soal.length,
                  minHeight: 4,
                  backgroundColor: Colors.white,
                  valueColor: AlwaysStoppedAnimation(
                      _sisaDetik < 300 ? AppColors.danger : AppColors.primary),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kartuSoal(soal, sid, tipe),
                        const SizedBox(height: 16),
                        _opsiSoal(sid, tipe, soal),
                        const SizedBox(height: 12),
                        _chipRagu(sid),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                _navBawah(),
              ],
            ),
            if (_showPalette) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _showPalette = false),
                  child:
                      Container(color: Colors.black.withValues(alpha: 0.45)),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: _palet(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final progress = (_idx + 1) / _soal.length;
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10, bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.judul,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _sisaLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: _sisaDetik < 60
                          ? AppColors.danger
                          : _sisaDetik < 300
                              ? AppColors.warning
                              : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Soal ${_idx + 1}/${_soal.length}',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(width: 12),
                Icon(
                  _sinkron ? Icons.cloud_done_outlined : Icons.save_outlined,
                  size: 13,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  _sinkron
                      ? 'Tersimpan di server'
                      : 'Tersimpan di HP — mengirim otomatis',
                  style:
                      const TextStyle(color: Colors.white, fontSize: 11.5),
                ),
                const Spacer(),
                Text('Pelanggaran: $_pelanggaran',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartuSoal(Map<String, dynamic> soal, String sid, String tipe) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: appSoftShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(
                label: tipe == 'esai' ? 'ESAI' : 'PILIHAN GANDA',
                state: BadgeState.info,
              ),
              const Spacer(),
              Text('Skor: ${soal['skor'] ?? 0}',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary)),
              if ((_ragu[sid] ?? false)) ...[
                const SizedBox(width: 8),
                const Icon(Icons.flag_rounded,
                    size: 14, color: AppColors.warning),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: Text('${_idx + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(soal['pertanyaan']?.toString() ?? '',
                    style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.55,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _opsiSoal(String sid, String tipe, Map<String, dynamic> soal) {
    if (tipe == 'esai') {
      return TextField(
        controller: _ctrlFor(sid),
        minLines: 4,
        maxLines: 8,
        textInputAction: TextInputAction.newline,
        onChanged: (v) {
          // Tanpa setState — keyboard/cursor tidak lompat.
          _jawaban[sid] = v;
          _belumKirim.add(sid);
          _store.saveAll(_jawaban, _ragu);
        },
        decoration: const InputDecoration(
          hintText: 'Ketik jawaban lengkap Anda di sini...',
        ),
      );
    }
    final opsi = <(String, String)>[
      for (final l in ['a', 'b', 'c', 'd'])
        if (soal['opsi_$l'] != null)
          (l.toUpperCase(), soal['opsi_$l'].toString()),
    ];
    return Column(
      children: [
        for (final (huruf, teks) in opsi)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: _jawaban[sid] == huruf
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => _pilih(sid, huruf),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _jawaban[sid] == huruf
                            ? AppColors.primary
                            : AppColors.border,
                        width: _jawaban[sid] == huruf ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _jawaban[sid] == huruf
                              ? AppColors.primary
                              : AppColors.background,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(huruf,
                            style: TextStyle(
                                color: _jawaban[sid] == huruf
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(teks,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.4,
                                  color: AppColors.ink))),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _chipRagu(String sid) {
    final isRagu = _ragu[sid] ?? false;
    return GestureDetector(
      onTap: () => _toggleRagu(sid),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isRagu
              ? AppColors.warning.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: isRagu ? AppColors.warning : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isRagu ? Icons.flag : Icons.outlined_flag,
                size: 16,
                color: isRagu ? AppColors.warning : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(isRagu ? 'Ditandai ragu-ragu' : 'Tandai ragu-ragu',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isRagu
                        ? AppColors.warning
                        : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _navBawah() {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: MediaQuery.of(context).padding.bottom + 10),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _idx > 0 ? () => setState(() => _idx--) : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 18),
            label: const Text('Sebelumnya'),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => setState(() => _showPalette = !_showPalette),
            icon: Icon(_showPalette ? Icons.close : Icons.grid_view_rounded,
                size: 18),
            label: Text(_showPalette ? 'Tutup' : 'Daftar Soal'),
          ),
          const SizedBox(width: 8),
          if (_idx < _soal.length - 1)
            FilledButton.icon(
              onPressed: () => setState(() => _idx++),
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('Lanjut'),
            )
          else
            FilledButton.icon(
              onPressed: _submitting ? null : () => _submit(),
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: const Text('Kirim'),
            ),
        ],
      ),
    );
  }

  Widget _palet() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Daftar Soal (${_soal.length})',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.ink)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => setState(() => _showPalette = false),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              _dot(AppColors.success, 'Dijawab'),
              const SizedBox(width: 14),
              _dot(AppColors.warning, 'Ragu'),
              const SizedBox(width: 14),
              _dot(Colors.grey.shade400, 'Kosong'),
            ]),
          ),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 64,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: _soal.length,
              itemBuilder: (context, i) {
                final id = _soal[i]['id']?.toString() ?? '';
                final dijawab =
                    _jawaban[id] != null && _jawaban[id]!.isNotEmpty;
                final ragu = _ragu[id] ?? false;
                final isCurrent = i == _idx;
                Color bg;
                if (dijawab) {
                  bg = AppColors.success;
                } else if (ragu) {
                  bg = AppColors.warning;
                } else {
                  bg = Colors.grey.shade300;
                }
                return InkWell(
                  onTap: () => setState(() {
                    _idx = i;
                    _showPalette = false;
                  }),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCurrent ? AppColors.primary : bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color:
                              isCurrent ? AppColors.primary : Colors.transparent,
                          width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text('${i + 1}',
                        style: TextStyle(
                            color: isCurrent || dijawab || ragu
                                ? Colors.white
                                : const Color(0xFF475569),
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color c, String label) {
    return Row(children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11)),
    ]);
  }
}
