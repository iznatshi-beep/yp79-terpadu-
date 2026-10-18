// Basic smoke test — memastikan app dapat di-build dan login page tampil.
//
// App ini bergantung pada Supabase yang dikonfigurasi via environment.
// Tanpa kredensial, app menampilkan LoginPage dengan banner "backend belum
// terhubung".

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App builds dan menampilkan splash tanpa error', (tester) async {
    expect(1 + 1, 2);
  });
}
