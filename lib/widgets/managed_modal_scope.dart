import 'package:flutter/widgets.dart';

/// Scopes one or more [ChangeNotifier]s (such as [TextEditingController]s) to the lifecycle of
/// a transient modal dialog or bottom sheet route. Disposes all registered controllers only
/// when this widget is unmounted from the element tree (after dismissal animations finish).
class ManagedModalScope extends StatefulWidget {
  final List<ChangeNotifier> controllers;
  final Widget child;

  const ManagedModalScope({
    super.key,
    required this.controllers,
    required this.child,
  });

  @override
  State<ManagedModalScope> createState() => _ManagedModalScopeState();
}

class _ManagedModalScopeState extends State<ManagedModalScope> {
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      try {
        controller.dispose();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
