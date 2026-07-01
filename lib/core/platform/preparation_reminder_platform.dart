import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/preparation_reminder.dart';

typedef ReminderRouteHandler = void Function(String route);

abstract interface class PreparationReminderPlatform {
  bool get isSupported;
  Future<void> syncSnapshot(PreparationReminderSnapshot snapshot);
  Future<void> updateSchedule(ReminderPreferences preferences);
  Future<ReminderNotificationStatus> getNotificationStatus();
  Future<ReminderNotificationStatus> requestNotificationPermission();
  Future<bool> pinWidget();
  Future<void> openNotificationSettings();
  Future<String?> takeInitialRoute();
  void setRouteHandler(ReminderRouteHandler? handler);
}

class MethodChannelPreparationReminderPlatform
    implements PreparationReminderPlatform {
  MethodChannelPreparationReminderPlatform({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const _channelName = 'com.example.scho_navi/preparation_reminders';

  final MethodChannel _channel;
  ReminderRouteHandler? _routeHandler;

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> syncSnapshot(PreparationReminderSnapshot snapshot) async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>(
      'syncSnapshot',
      jsonEncode(snapshot.toJson()),
    );
  }

  @override
  Future<void> updateSchedule(ReminderPreferences preferences) async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('updateSchedule', preferences.toJson());
  }

  @override
  Future<ReminderNotificationStatus> getNotificationStatus() async {
    if (!isSupported) return ReminderNotificationStatus.notRequired;
    final value = await _channel.invokeMethod<String>('getNotificationStatus');
    return _status(value);
  }

  @override
  Future<ReminderNotificationStatus> requestNotificationPermission() async {
    if (!isSupported) return ReminderNotificationStatus.notRequired;
    final value = await _channel.invokeMethod<String>(
      'requestNotificationPermission',
    );
    return _status(value);
  }

  @override
  Future<bool> pinWidget() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('pinWidget') ?? false;
  }

  @override
  Future<void> openNotificationSettings() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('openNotificationSettings');
  }

  @override
  Future<String?> takeInitialRoute() async {
    if (!isSupported) return null;
    return _channel.invokeMethod<String>('takeInitialRoute');
  }

  @override
  void setRouteHandler(ReminderRouteHandler? handler) {
    _routeHandler = handler;
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'openRoute') return;
    final route = call.arguments as String?;
    if (route != null && _isAllowedRoute(route)) {
      _routeHandler?.call(route);
    }
  }

  bool _isAllowedRoute(String route) =>
      route == '/home' ||
      route.startsWith('/home?') ||
      route == '/preparation-plans' ||
      route.startsWith('/preparation-plans/');

  ReminderNotificationStatus _status(String? value) => switch (value) {
    'granted' => ReminderNotificationStatus.granted,
    'denied' => ReminderNotificationStatus.denied,
    _ => ReminderNotificationStatus.notRequired,
  };
}
