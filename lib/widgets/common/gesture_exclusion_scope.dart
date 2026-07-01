import 'package:flutter/material.dart';

import '../../services/gesture_exclusion_service.dart';

/// Wraps [child] and excludes the left screen edge from Android system
/// gesture navigation while this widget is in the tree.
class GestureExclusionScope extends StatefulWidget {
  final Widget child;
  final int widthDp;

  const GestureExclusionScope({
    super.key,
    required this.child,
    this.widthDp = 30,
  });

  @override
  State<GestureExclusionScope> createState() => _GestureExclusionScopeState();
}

class _GestureExclusionScopeState extends State<GestureExclusionScope> {
  @override
  void initState() {
    super.initState();
    GestureExclusionService.setLeftEdgeExclusion(widthDp: widget.widthDp);
  }

  @override
  void dispose() {
    GestureExclusionService.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
