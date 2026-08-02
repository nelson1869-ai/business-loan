import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Applies consistent system-back behavior to a non-root application route.
class RouteBackScope extends StatelessWidget {
  final String fallbackLocation;
  final Widget child;

  const RouteBackScope({
    super.key,
    required this.fallbackLocation,
    required this.child,
  });

  static void navigateBack(BuildContext context, String fallbackLocation) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(fallbackLocation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(fallbackLocation);
      },
      child: child,
    );
  }
}

/// Visible app-bar action matching [RouteBackScope]'s system-back policy.
class RouteBackButton extends StatelessWidget {
  final String fallbackLocation;
  final String tooltip;

  const RouteBackButton({
    super.key,
    required this.fallbackLocation,
    this.tooltip = 'Back',
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(Icons.arrow_back),
      onPressed: () => RouteBackScope.navigateBack(context, fallbackLocation),
    );
  }
}
