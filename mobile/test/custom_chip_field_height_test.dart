import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget buildCustomField(String hint) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SizedBox(
            height: 48,
            width: double.infinity,
            child: TextField(
              maxLines: 1,
              inputFormatters: [LengthLimitingTextInputFormatter(80)],
              decoration: InputDecoration(
                hintText: hint,
                hintMaxLines: 1,
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('custom field stays 48px with long RU hint', (tester) async {
    const hint = 'Свой продукт — напишите и добавьте';
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildCustomField(hint));
    await tester.pumpAndSettle();

    final field = tester.renderObject<RenderBox>(find.byType(TextField));
    expect(field.size.height, lessThanOrEqualTo(48.0));
  });
}
