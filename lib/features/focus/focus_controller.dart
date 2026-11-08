import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class FocusStatus {
  final bool enabled, consented, pendingEnable, completed, reading;
  final bool accessibilityEnabled, serviceConnected;
  final int goalMinutes, earnedSeconds, remainingSeconds;
  final Set<String> selectedPackages;
  const FocusStatus(
      {this.enabled = false,
      this.consented = false,
      this.pendingEnable = false,
      this.completed = false,
      this.reading = false,
      this.accessibilityEnabled = false,
      this.serviceConnected = false,
      this.goalMinutes = 10,
      this.earnedSeconds = 0,
      this.remainingSeconds = 600,
      this.selectedPackages = const {}});
  factory FocusStatus.fromMap(Map<dynamic, dynamic> value) => FocusStatus(
      enabled: value['enabled'] == true,
      consented: value['consented'] == true,
      pendingEnable: value['pendingEnable'] == true,
      completed: value['completed'] == true,
      reading: value['reading'] == true,
      accessibilityEnabled: value['accessibilityEnabled'] == true,
      serviceConnected: value['serviceConnected'] == true,
      goalMinutes: (value['goalMinutes'] as num?)?.toInt() ?? 10,
      earnedSeconds: (value['earnedSeconds'] as num?)?.toInt() ?? 0,
      remainingSeconds: (value['remainingSeconds'] as num?)?.toInt() ?? 600,
      selectedPackages: (value['selectedPackages'] as List? ?? [])
          .whereType<String>()
          .toSet());
  bool get protected => enabled && accessibilityEnabled && serviceConnected;
  double get progress => (earnedSeconds / (goalMinutes * 60)).clamp(0.0, 1.0);
  String get countdown =>
      '${(remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(remainingSeconds % 60).toString().padLeft(2, '0')}';
}

class FocusApp {
  final String packageName, name;
  final Uint8List? icon;
  const FocusApp(this.packageName, this.name, this.icon);
  factory FocusApp.fromMap(Map<dynamic, dynamic> value) => FocusApp(
      value['packageName'] as String,
      value['name'] as String,
      value['icon'] as Uint8List?);
}

class FocusController extends ChangeNotifier with WidgetsBindingObserver {
  final MethodChannel channel;
  final bool supported;
  FocusController({MethodChannel? channel, bool? supported})
      : channel = channel ?? const MethodChannel('selah/focus'),
        supported = supported ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
  FocusStatus status = const FocusStatus();
  bool available = false;
  String? error;
  void Function(String)? onAction;
  Timer? _timer;
  bool _disposed = false, _refreshing = false, _foreground = true;
  bool? _lastReading;

  Future<void> start() async {
    if (!supported) return;
    WidgetsBinding.instance.addObserver(this);
    await refresh();
    _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    if (!_disposed && available && _foreground) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(refresh().then((_) => _startPolling()));
    } else {
      _timer?.cancel();
    }
  }

  Future<void> refresh() async {
    if (!supported || _disposed || _refreshing) return;
    _refreshing = true;
    try {
      final value = await channel.invokeMapMethod<dynamic, dynamic>('status');
      if (_disposed || value == null) return;
      status = FocusStatus.fromMap(value);
      available = true;
      error = null;
      final action = value['action'];
      notifyListeners();
      if (action is String && action.isNotEmpty) onAction?.call(action);
    } on MissingPluginException {
      available = false;
    } on PlatformException catch (exception) {
      if (!_disposed) {
        error = exception.message ?? 'Focus Mode could not be loaded.';
        notifyListeners();
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<bool> _change(String method, [Map<String, Object?>? arguments]) async {
    try {
      await channel.invokeMethod<void>(method, arguments);
      await refresh();
      return true;
    } on PlatformException catch (exception) {
      if (!_disposed) {
        error = exception.message ?? 'Focus Mode could not be updated.';
        notifyListeners();
      }
      return false;
    }
  }

  Future<List<FocusApp>> apps() async {
    final rows = await channel.invokeListMethod<dynamic>('apps') ?? [];
    return rows.map((row) => FocusApp.fromMap(row as Map)).toList();
  }

  Future<bool> configure({int? minutes, Set<String>? packages}) =>
      _change('configure', {
        'goalMinutes': minutes ?? status.goalMinutes,
        'selectedPackages': (packages ?? status.selectedPackages).toList(),
      });
  Future<void> enable(bool value) async {
    if (await _change('enable', {'enabled': value}) &&
        value &&
        !status.accessibilityEnabled) {
      await openPermission();
    }
  }

  Future<void> consent() async {
    await _change('consent');
  }

  Future<void> openPermission() async {
    await _change('accessibilitySettings');
  }

  Future<void> readingVisible(bool value) async {
    if (!available || _disposed || _lastReading == value) return;
    _lastReading = value;
    try {
      await channel.invokeMethod<void>('reading', {'visible': value});
    } on PlatformException {
      _lastReading = null;
    } on MissingPluginException {
      _lastReading = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    onAction = null;
    super.dispose();
  }
}

class FocusRouteObserver extends NavigatorObserver {
  final VoidCallback changed;
  FocusRouteObserver(this.changed);
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      changed();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => changed();
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      changed();
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      changed();
}
