import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'focus_controller.dart';

class FocusPage extends StatefulWidget {
  final FocusController controller;
  final VoidCallback onRead;
  const FocusPage({super.key, required this.controller, required this.onRead});
  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  bool busy = false;

  Future<void> enable(bool value) async {
    final controller = widget.controller;
    if (value && !controller.status.consented) {
      final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('Allow app blocking?'),
                  content: const SingleChildScrollView(
                      child: Text(
                          'SELAH uses Android Accessibility to detect when a selected app opens and show its reading gate until your daily goal is complete.\n\n'
                          'It does not read messages, passwords, or screen text. App selections and reading time stay on this phone; nothing is sent to a server.\n\n'
                          'You can disable Focus Mode or its accessibility permission at any time. This is a personal habit tool and can be bypassed.')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Not now')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Agree and continue'))
                  ]));
      if (accepted != true || !mounted) return;
      await controller.consent();
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      await controller.enable(value);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> customGoal() async {
    final input =
        TextEditingController(text: '${widget.controller.status.goalMinutes}');
    final route = DialogRoute<int>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Daily reading minutes'),
                content: TextField(
                    controller: input,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                        labelText: 'Minutes',
                        helperText: 'Choose 5 to 180 minutes')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        final value = int.tryParse(input.text);
                        if (value != null && value >= 5 && value <= 180) {
                          Navigator.pop(context, value);
                        }
                      },
                      child: const Text('Save'))
                ]));
    final value = await Navigator.of(context).push(route);
    await route.completed;
    input.dispose();
    if (value != null) await widget.controller.configure(minutes: value);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final status = controller.status;
        return Scaffold(
            appBar: AppBar(title: const Text('Focus Mode')),
            body: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child:
                        ListView(padding: const EdgeInsets.all(24), children: [
                      Icon(Icons.shield_outlined,
                          size: 42,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 16),
                      const Text('Read first.\nScroll later.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'SourceSerif4',
                              fontSize: 34,
                              height: 1.2)),
                      const SizedBox(height: 12),
                      const Text(
                          'Choose apps to pause until your daily Scripture time is complete. They unlock for the rest of the day.',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      Card(
                          child: SwitchListTile(
                              title: const Text('Enable Focus Mode'),
                              subtitle: Text(status.pendingEnable
                                  ? 'Finish setup in Android Accessibility.'
                                  : status.enabled && !status.protected
                                      ? 'Accessibility permission needs attention.'
                                      : status.protected
                                          ? 'Your selected apps follow today’s reading goal.'
                                          : 'Off · You control when to enable it.'),
                              value: status.enabled || status.pendingEnable,
                              onChanged: busy ? null : enable)),
                      if (status.enabled && !status.protected ||
                          status.pendingEnable)
                        TextButton.icon(
                            onPressed: controller.openPermission,
                            icon: const Icon(Icons.settings_accessibility),
                            label: const Text('Open Android Accessibility')),
                      if (controller.error != null)
                        Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(controller.error!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error))),
                      const SizedBox(height: 20),
                      Text('Daily reading goal',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final minutes in [5, 10, 15, 20, 30, 60])
                          ChoiceChip(
                              label: Text('$minutes min'),
                              selected: status.goalMinutes == minutes,
                              onSelected: (_) =>
                                  controller.configure(minutes: minutes)),
                        ActionChip(
                            label: Text([5, 10, 15, 20, 30, 60]
                                    .contains(status.goalMinutes)
                                ? 'Custom'
                                : '${status.goalMinutes} min · Custom'),
                            onPressed: customGoal),
                      ]),
                      const SizedBox(height: 20),
                      Card(
                          child: ListTile(
                              leading: const Icon(Icons.apps_rounded),
                              title: const Text('Apps to pause'),
                              subtitle: Text(
                                  '${status.selectedPackages.length} selected · Phone, launcher, and settings stay available'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                final selected = await Navigator.of(context)
                                    .push<Set<String>>(MaterialPageRoute(
                                        builder: (_) => FocusAppPicker(
                                            controller: controller)));
                                if (selected != null) {
                                  await controller.configure(
                                      packages: selected);
                                }
                              })),
                      const SizedBox(height: 20),
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        status.completed
                                            ? 'Today’s goal is complete'
                                            : 'Today’s reading time',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                    const SizedBox(height: 12),
                                    Text(
                                        status.completed
                                            ? 'Your selected apps are unlocked today.'
                                            : '${status.countdown} remaining',
                                        style: const TextStyle(
                                            fontFamily: 'SourceSerif4',
                                            fontSize: 28)),
                                    const SizedBox(height: 12),
                                    LinearProgressIndicator(
                                        value: status.progress,
                                        minHeight: 7,
                                        borderRadius: BorderRadius.circular(8)),
                                    const SizedBox(height: 16),
                                    const Text(
                                        'Time counts in the reader while SELAH is in front and your screen is unlocked. Menus, dialogs, and background audio do not count. You can split your goal across sessions.'),
                                    const SizedBox(height: 16),
                                    FilledButton.icon(
                                        onPressed: widget.onRead,
                                        icon: const Icon(
                                            Icons.menu_book_outlined),
                                        label: const Text('Start reading')),
                                  ]))),
                      const SizedBox(height: 16),
                      const Text(
                          'Resets at local midnight. Settings and progress stay on this Android phone. App blocking relies on the accessibility service remaining enabled.',
                          style: TextStyle(fontSize: 12)),
                    ]))));
      });
}

class FocusAppPicker extends StatefulWidget {
  final FocusController controller;
  const FocusAppPicker({super.key, required this.controller});
  @override
  State<FocusAppPicker> createState() => _FocusAppPickerState();
}

class _FocusAppPickerState extends State<FocusAppPicker> {
  late Future<List<FocusApp>> apps;
  late Set<String> selected;
  String query = '';
  @override
  void initState() {
    super.initState();
    apps = widget.controller.apps();
    selected = {...widget.controller.status.selectedPackages};
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Choose apps')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
                decoration: const InputDecoration(
                    hintText: 'Search installed apps',
                    prefixIcon: Icon(Icons.search)),
                onChanged: (value) =>
                    setState(() => query = value.trim().toLowerCase()))),
        Expanded(
            child: FutureBuilder<List<FocusApp>>(
                future: apps,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: TextButton(
                            onPressed: () =>
                                setState(() => apps = widget.controller.apps()),
                            child: const Text('Retry loading apps')));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final matches = snapshot.data!
                      .where((app) =>
                          app.name.toLowerCase().contains(query) ||
                          app.packageName.toLowerCase().contains(query))
                      .toList();
                  if (matches.isEmpty) {
                    return const Center(child: Text('No matching apps.'));
                  }
                  return ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final app = matches[index];
                        return CheckboxListTile(
                            value: selected.contains(app.packageName),
                            secondary: app.icon == null
                                ? const Icon(Icons.apps)
                                : Image.memory(app.icon!,
                                    width: 40, height: 40),
                            title: Text(app.name),
                            subtitle: Text(app.packageName,
                                style: const TextStyle(fontSize: 11)),
                            onChanged: (value) => setState(() {
                                  if (value == true) {
                                    selected.add(app.packageName);
                                  } else {
                                    selected.remove(app.packageName);
                                  }
                                }));
                      });
                })),
        SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: () => Navigator.pop(context, selected),
                        child: Text('Save ${selected.length} apps'))))),
      ]));
}

/// Keeps the navigator mounted when the daily timer appears or completes.
class FocusTimerFrame extends StatelessWidget {
  final FocusController controller;
  final Widget child;
  const FocusTimerFrame(
      {super.key, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, navigator) {
        final visible = controller.available &&
            controller.status.enabled &&
            !controller.status.completed;
        return Column(children: [
          Expanded(
              child: MediaQuery.removePadding(
                  context: context, removeBottom: visible, child: navigator!)),
          if (visible)
            Material(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: SafeArea(
                    top: false,
                    child: ReadingGoalBanner(controller: controller))),
        ]);
      });
}

class ReadingGoalBanner extends StatelessWidget {
  final FocusController controller;
  const ReadingGoalBanner({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final status = controller.status;
        return Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Row(children: [
                  Icon(
                      status.completed
                          ? Icons.check_circle_outline
                          : Icons.timer_outlined,
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          status.completed
                              ? 'Goal complete · Apps unlocked today'
                              : '${status.countdown} left · ${status.reading ? 'Reading time' : 'Timer paused'}',
                          style: const TextStyle(fontSize: 12))),
                  if (!status.protected && !status.completed)
                    const Icon(Icons.info_outline,
                        size: 18,
                        semanticLabel:
                            'Accessibility service is not active; selected apps cannot be blocked.'),
                ])));
      });
}
