// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

/// Runnable demo of `otel_riverpod` against a local LGTM stack.
///
/// Run the stack:
///   docker compose -f ../../../tool/lgtm/docker-compose.yml up -d
///
/// Then run this app:
///   dart run bin/main.dart
///
/// Open Grafana (http://localhost:3000), pick the Tempo datasource in
/// Explore, search for service `riverpod-otel-example-app`, and
/// you'll see one trace per scenario — added, updated, family,
/// auto-dispose, and a failing provider — each demonstrating a
/// different observer hook.
library;

import 'dart:async';
import 'dart:io';

// Example apps use the Pro SDK to demonstrate the one-character
// switch (OTel.initialize -> DOTel.initialize). The package source
// still imports the OSS SDK directly so non-Pro users can use it.
import 'package:dartastic_opentelemetry_pro/dartastic_opentelemetry_pro.dart';
import 'package:otel_riverpod/otel_riverpod.dart';
import 'package:riverpod/riverpod.dart';

const _serviceName = 'riverpod-otel-example-app';
// 4318 = OTLP/HTTP default port (the SDK's default protocol is
// `http/protobuf`). Use 4317 only with `OTEL_EXPORTER_OTLP_PROTOCOL=grpc`.
const _defaultEndpoint = 'http://localhost:4318';

Future<void> main(List<String> args) async {
  final endpoint =
      Platform.environment['OTEL_EXPORTER_OTLP_ENDPOINT'] ?? _defaultEndpoint;

  print('==> exporting to $endpoint as $_serviceName');

  await DOTel.initialize(
    serviceName: _serviceName,
    serviceVersion: '0.0.1',
    endpoint: endpoint,
  );

  final tracer = DOTel.tracer();

  // `recordValues: true` is fine for a demo — production apps should
  // leave it `false` because provider state often carries user data.
  final container = ProviderContainer(
    observers: [OTelRiverpodObserver(recordValues: true)],
  );

  await tracer.startActiveSpanAsync<void>(
    name: 'run-scenarios',
    fn: (_) async {
      // Each scenario lives in its own parent span so they appear as
      // distinct traces in Tempo.
      await _scenario('plain-provider-add', () {
        final greeting = Provider<String>((_) => 'hello', name: 'greeting');
        container.read(greeting);
      });

      await _scenario('notifier-update', () async {
        container.read(_counterProvider);
        container.read(_counterProvider.notifier).increment();
        container.read(_counterProvider.notifier).increment();
        // Let observer notifications drain.
        await Future<void>.delayed(Duration.zero);
      });

      await _scenario('family-with-argument', () {
        container.read(_doubler(21));
      });

      await _scenario('auto-dispose-and-recycle', () async {
        // Subscribe + drop the listener so the auto-dispose cleanup
        // fires. Riverpod's auto-dispose runs on the next microtask.
        final sub = container.listen<int>(_ephemeral, (_, __) {});
        sub.close();
        await Future<void>.delayed(Duration.zero);
      });

      await _scenario('failing-provider', () {
        try {
          container.read(_explodes);
        } on Object catch (e) {
          // The observer has already recorded the failure as a span
          // with status=Error; we just don't let it crash the demo.
          // (Riverpod's `e.toString()` is verbose — only print the
          // first line so the demo output stays readable.)
          print('  expected failure: ${e.toString().split('\n').first}');
        }
      });

      // Dispose inside the parent span so the four `didDisposeProvider`
      // spans show up as children of `run-scenarios` rather than as
      // orphan traces.
      container.dispose();
    },
  );

  print('==> flushing + shutting down');
  await DOTel.tracerProvider().forceFlush();
  await DOTel.shutdown();
  print('==> done. open Grafana at http://localhost:3000 → Explore → '
      'Tempo, service = $_serviceName');
}

Future<void> _scenario(String name, FutureOr<void> Function() body) async {
  print('--> $name');
  await DOTel.tracer().startActiveSpanAsync<void>(
    name: name,
    fn: (_) async {
      await body();
    },
  );
}

final _counterProvider =
    NotifierProvider<_Counter, int>(_Counter.new, name: 'counter');

final _doubler = Provider.family<int, int>(
  (_, arg) => arg * 2,
  name: 'doubler',
);

final _ephemeral = Provider.autoDispose<int>(
  (_) => DateTime.now().millisecondsSinceEpoch,
  name: 'ephemeral',
);

final _explodes = Provider<int>(
  (_) => throw StateError('intentional demo failure'),
  name: 'explodes',
);

class _Counter extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}
