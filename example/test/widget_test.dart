// 基础 UI 冒烟测试。
//
// 验证新的科技风背景组件能够正常构建并渲染其子节点（纯 widget 测试，
// 不依赖原生插件，因此可在 `flutter test` 环境稳定运行）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/widgets/tech_background.dart';
import 'package:example/widgets/tech_controls.dart';

void main() {
  testWidgets('TechBackground 渲染子节点', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TechBackground(child: Center(child: Text('hello'))),
        ),
      ),
    );

    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('GradientFab / LiveDot 可构建', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: const [
              GradientFab(
                gradient: LinearGradient(colors: [Colors.cyan, Colors.blue]),
                glowColor: Colors.cyan,
                icon: Icons.mic_rounded,
              ),
              LiveDot(active: true, color: Colors.cyan),
              LiveDot(active: false, color: Colors.red),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
  });
}
