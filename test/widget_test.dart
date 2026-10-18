// Smoke test nyata (bukan placeholder).
//
// Menguji jalur boot aplikasi tanpa kredensial backend: aplikasi HARUS
// menampilkan banner "Backend belum terhubung" dan form login dalam keadaan
// nonaktif. Ini memastikan tidak ada autentikasi palsu yang selalu berhasil
// ketika backend belum dikonfigurasi.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yp79_terpadu/app.dart';
import 'package:yp79_terpadu/core/config.dart';
import 'package:yp79_terpadu/core/models/role.dart';

void main() {
  testWidgets('Boot tanpa backend: banner tampil + input login nonaktif',
      (tester) async {
    await tester.pumpWidget(const Yp79App());
    await tester.pumpAndSettle();

    expect(AppConfig.isConfigured, isFalse,
        reason: 'Test ini berjalan tanpa .env / --dart-define.');

    // Regresi: gerbang TIDAK boleh berhenti di splash "Memuat data sesi..."
    // (bug lapangan: berputar tanpa akhir karena event sesi pertama tidak
    // pernah datang). Tanpa backend, layar login harus langsung tampil.
    expect(find.text('Memuat data sesi...'), findsNothing);

    expect(find.text('Backend belum terhubung'), findsOneWidget);
    expect(find.text('YP79 Terpadu'), findsOneWidget);

    final fields =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(fields, isNotEmpty, reason: 'Form login harus dirender.');
    expect(fields.every((f) => f.enabled == false), isTrue,
        reason: 'Tanpa kredensial backend, input login wajib nonaktif.');

    final tombolMasuk = tester.widgetList<FilledButton>(
        find.widgetWithText(FilledButton, 'Masuk')).toList();
    expect(tombolMasuk, isNotEmpty);
    expect(tombolMasuk.first.onPressed, isNull,
        reason: 'Tombol Masuk tidak boleh aktif tanpa backend nyata.');
  });

  test('Role.fromString memetakan seluruh peran ke enum yang benar', () {
    expect(Role.fromString('admin'), Role.admin);
    expect(Role.fromString('guru'), Role.guru);
    expect(Role.fromString('guru_pembimbing'), Role.guruPembimbing);
    expect(Role.fromString('siswa'), Role.siswa);
    expect(Role.fromString('orang_tua'), Role.orangTua);
    expect(Role.fromString(null), Role.siswa);
    expect(Role.admin.isFullAccess, isTrue);
    expect(Role.guru.isFullAccess, isFalse);
  });
}
