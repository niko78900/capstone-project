import 'dart:io';

import 'package:cap_app/core/errors/app_exception.dart';
import 'package:cap_app/features/settings/providers/settings_providers.dart';
import 'package:cap_app/shared/widgets/async_value_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pull to refresh works while in error state', (tester) async {
    var refreshCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [debugModeEnabledProvider.overrideWithValue(false)],
        child: MaterialApp(
          home: Scaffold(
            body: AsyncValueView<int>(
              value: AsyncValue<int>.error(
                const SocketException('Failed host lookup'),
                StackTrace.empty,
              ),
              onRefresh: () async {
                refreshCount += 1;
              },
              data: (value) => Text('Value $value'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No connection.'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(refreshCount, 1);
  });

  testWidgets('debug mode appends exception details in async error view', (
    tester,
  ) async {
    const error = AppException(message: 'Cannot reach server');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [debugModeEnabledProvider.overrideWithValue(true)],
        child: MaterialApp(
          home: Scaffold(
            body: AsyncValueView<int>(
              value: AsyncValue<int>.error(error, StackTrace.empty),
              data: _dataBuilder,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('No connection.'), findsOneWidget);
    expect(find.textContaining('Details:'), findsOneWidget);
    expect(
      find.textContaining('AppException(statusCode: null'),
      findsOneWidget,
    );
  });
}

Widget _dataBuilder(int value) => Text('Value $value');
