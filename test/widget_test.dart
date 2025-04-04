import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:untitled2/main.dart';

void main() {
  testWidgets('App loads and shows AppBar', (WidgetTester tester) async {
    // Загружаем приложение
    await tester.pumpWidget(MyApp());

    // Проверяем, что отображается заголовок AppBar
    expect(find.text('Пользователи'), findsOneWidget);

    // Проверяем наличие TabBar
    expect(find.byType(TabBar), findsOneWidget);
  });

  testWidgets('FloatingActionButton adds user dialog', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    // Ждём, пока интерфейс отрисуется
    await tester.pumpAndSettle();

    // Нажимаем на кнопку добавления пользователя
    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    // Проверяем, что открылся диалог
    expect(find.text('Добавить пользователя'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Сохранить'), findsOneWidget);
  });
}
