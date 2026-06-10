import 'package:flutter/material.dart';

/// App-wide modal bottom sheet with drag handle and keyboard avoidance.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool expand = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: expand
          ? FractionallySizedBox(heightFactor: 0.9, child: builder(ctx))
          : builder(ctx),
    ),
  );
}
