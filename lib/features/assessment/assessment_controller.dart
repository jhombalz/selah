import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/user_database.dart';
import 'assessment_store.dart';

class AssessmentNotifications {
  static const channel = MethodChannel('selah/assessment');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static Future<void> sync(AssessmentAttempt? a) async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('sync', {
        'id': a?.id,
        'level': a?.level,
        'deadline': a?.deadline.millisecondsSinceEpoch,
      });
    } on MissingPluginException {
      /* Unit tests and older installations. */
    } on PlatformException {
      /* The local assessment deadline remains authoritative. */
    }
  }

  static Future<void> requestPermission() async {
    if (!supported) return;
    try {
      await channel.invokeMethod<bool>('permission');
    } on MissingPluginException {
      /* No native service in unit tests. */
    } on PlatformException {
      /* Denying notifications must not block assessments. */
    }
  }
}

class AssessmentController extends ChangeNotifier with WidgetsBindingObserver {
  final UserDatabase database;
  final clock = AssessmentClock();
  late final store = AssessmentStore(database, clock: clock.now);
  final resumeRequests = ValueNotifier<int>(0);
  AssessmentAttempt? active;
  Timer? _timer;
  StreamSubscription<void>? _changes;
  bool _disposed = false, _refreshing = false, _again = false;
  String? _nativeScope;
  bool _foreground = true;
  String? latestId;
  AssessmentController(this.database);
  void start() {
    WidgetsBinding.instance.addObserver(this);
    _changes =
        AssessmentStore.changes.stream.listen((_) => unawaited(refresh()));
    unawaited(refresh());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      if (active != null && !clock.now().isBefore(active!.deadline)) {
        unawaited(refresh());
      } else if (active != null) {
        notifyListeners();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  Future<void> refresh() async {
    if (_disposed) return;
    if (_refreshing) {
      _again = true;
      return;
    }
    _refreshing = true;
    try {
      final attempts = await store.load();
      if (_disposed) return;
      latestId = attempts.isEmpty ? null : attempts.first.id;
      active = null;
      for (final a in attempts) {
        if (!a.submitted) {
          active = a;
          break;
        }
      }
      final scope = active == null
          ? 'none'
          : '${active!.id}:${active!.deadline.millisecondsSinceEpoch}';
      if (_nativeScope != scope && (active != null || _foreground)) {
        _nativeScope = scope;
        await AssessmentNotifications.sync(active);
      }
      if (!_disposed) notifyListeners();
    } catch (_) {
      /* Keep an existing deadline visible if storage is temporarily unavailable. */
    } finally {
      _refreshing = false;
      if (_again && !_disposed) {
        _again = false;
        unawaited(refresh());
      }
    }
  }

  String get countdown {
    final seconds =
        active?.deadline.difference(clock.now()).inSeconds.clamp(0, 999999) ??
            0;
    return '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  void resume() => resumeRequests.value++;
  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    clock.elapsed.stop();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_changes?.cancel() ?? Future.value());
    resumeRequests.dispose();
    super.dispose();
  }
}

class AssessmentTimerFrame extends StatelessWidget {
  final AssessmentController controller;
  final Widget child;
  final VoidCallback onOpen;
  const AssessmentTimerFrame(
      {super.key,
      required this.controller,
      required this.child,
      required this.onOpen});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, navigator) {
        final a = controller.active;
        return Column(children: [
          Expanded(child: navigator!),
          if (a != null)
            Material(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: SafeArea(
                    top: false,
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                        child: Row(children: [
                          const Icon(Icons.timer_outlined, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(
                                  'Level ${a.level} assessment · ${controller.countdown}\nTimer running · cannot pause',
                                  style: const TextStyle(fontSize: 12))),
                          Semantics(
                              button: true,
                              label: 'Resume assessment',
                              child: InkWell(
                                  onTap: onOpen,
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Text('Resume')))),
                        ])))),
        ]);
      });
}
