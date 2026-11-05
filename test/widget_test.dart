import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/main.dart';

void main() {
  testWidgets('PdfReaderApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PdfReaderApp());
    expect(find.text('Folio'), findsWidgets);
    expect(find.text('PDF Dosyası Seç'), findsOneWidget);
  });
}
