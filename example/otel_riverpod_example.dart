// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

/// Runnable demo of `otel_riverpod`.
///
/// Initializes the OpenTelemetry SDK, installs [OTelRiverpodObserver]
/// on a [ProviderContainer], and drives one scenario per observer
/// hook — added, updated, family argument, auto-dispose, and a
/// failing provider.
///
/// Spans export to the standard OTLP endpoint (`http://localhost:4318`
/// by default; override with `OTEL_EXPORTER_OTLP_ENDPOINT`). Point it
/// at any OTLP-capable collector or backend and open the
/// `riverpod-otel-example` service to see the trace waterfall.
///
///   dart run example/otel_riverpod_example.dart
library;

import 'dart:async';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_riverpod/otel_riverpod.dart';
import 'package:riverpod/riverpod.dart';

Future<void> main() async {
  await OTel.initialize(
    serviceName: 'riverpod-otel-example',
    serviceVersion: '0.0.1',
  );

  // `recordValues: true` is fine for a demo — production apps should
  // leave it `false` because provider state often carries user data.
  final container = ProviderContainer(
    observers: [OTelRiverpodObserver(recordValues: true)],
  );

  await OTel.tracer().startActiveSpanAsync<void>(
    name: 'run-scenarios',
    fn: (_) async {
      // provider.added:<name> — didAddProvider on first read.
      await _scenario('plain-provider-add', () {
        final greeting = Provider<String>((_) => 'hello', name: 'greeting');
        container.read(greeting);
      });

      // provider.updated:<name> — didUpdateProvider per state change.
      await _scenario('notifier-update', () async {
        container.read(_counterProvider);
        container.read(_counterProvider.notifier).increment();
        container.read(_counterProvider.notifier).increment();
        // Let observer notifications drain.
        await Future<void>.delayed(Duration.zero);
      });

      // riverpod.provider.family + riverpod.provider.argument attrs.
      await _scenario('family-with-argument', () {
        container.read(_doubler(21));
      });

      // provider.disposed:<name> — auto-dispose fires on the next
      // microtask after the last listener drops.
      await _scenario('auto-dispose-and-recycle', () async {
        final sub = container.listen<int>(_ephemeral, (_, __) {});
        sub.close();
        await Future<void>.delayed(Duration.zero);
      });

      // provider.failed:<name> — status=Error + recordException event.
      await _scenario('failing-provider', () {
        try {
          container.read(_explodes);
        } on Object catch (e) {
          // The observer has already recorded the failure span; just
          // don't let it crash the demo.
          print('  expected failure: ${e.toString().split('\n').first}');
        }
      });

      // Dispose inside the parent span so the didDisposeProvider
      // spans join the `run-scenarios` trace rather than orphaning.
      container.dispose();
    },
  );

  await OTel.tracerProvider().forceFlush();
  await OTel.shutdown();
  print('done — inspect service `riverpod-otel-example` in your '
      'OTLP backend.');
}

Future<void> _scenario(String name, FutureOr<void> Function() body) async {
  print('--> $name');
  await OTel.tracer().startActiveSpanAsync<void>(
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
