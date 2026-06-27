import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scho_navi/features/splash/splash_controller.dart';

void main() {
  test('初始状态 progress=0 isCompleted=false', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final state = container.read(splashControllerProvider);
    expect(state.progress, 0);
    expect(state.isCompleted, isFalse);
  });

  test('setProgress 更新 progress 且不置 isCompleted（v<1）', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(splashControllerProvider.notifier).setProgress(0.5);
    final state = container.read(splashControllerProvider);
    expect(state.progress, 0.5);
    expect(state.isCompleted, isFalse);
  });

  test('setProgress(1.0) 自动置 isCompleted=true', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(splashControllerProvider.notifier).setProgress(1.0);
    final state = container.read(splashControllerProvider);
    expect(state.isCompleted, isTrue);
    expect(state.progress, 1.0);
  });

  test('skip（无 attach）直接置完成态', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(splashControllerProvider.notifier).skip();
    expect(container.read(splashControllerProvider).isCompleted, isTrue);
    expect(container.read(splashControllerProvider).progress, 1.0);
  });

  test('markNavigated 后 setProgress 被忽略（防导航后残余帧）', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(splashControllerProvider.notifier).setProgress(0.3);
    container.read(splashControllerProvider.notifier).markNavigated();
    // 导航后即便收到残余 progress 也应忽略，状态不变。
    container.read(splashControllerProvider.notifier).setProgress(0.8);
    final state = container.read(splashControllerProvider);
    expect(state.progress, 0.3);
    expect(state.isCompleted, isFalse);
  });
}
