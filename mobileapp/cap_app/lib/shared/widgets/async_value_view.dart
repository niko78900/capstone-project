// File purpose: Defines reusable Flutter widget behavior for async value view.
import 'package:cap_app/core/errors/error_presenter.dart';
import 'package:cap_app/features/settings/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsyncValueView<T> extends ConsumerWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.loadingMessage = 'Loading...',
    this.onRefresh,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final String loadingMessage;
  final RefreshCallback? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debugModeEnabled = ref.watch(debugModeEnabledProvider);
    return value.when(
      data: data,
      loading: () {
        final loadingView = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(loadingMessage),
            ],
          ),
        );
        if (onRefresh == null) {
          return loadingView;
        }
        return _RefreshableState(onRefresh: onRefresh!, child: loadingView);
      },
      error: (error, _) {
        final errorView = Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              formatErrorMessageForUi(
                error,
                debugModeEnabled: debugModeEnabled,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
        if (onRefresh == null) {
          return errorView;
        }
        return _RefreshableState(onRefresh: onRefresh!, child: errorView);
      },
    );
  }
}

class _RefreshableState extends StatelessWidget {
  const _RefreshableState({required this.onRefresh, required this.child});

  final RefreshCallback onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: child),
            ),
          ),
        );
      },
    );
  }
}
