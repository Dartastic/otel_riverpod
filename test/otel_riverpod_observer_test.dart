// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_riverpod/otel_riverpod.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

/// In-memory exporter so we can assert what the observer produced
/// without spinning up a real OTLP backend.
class _MemorySpanExporter implements SpanExporter {
  final List<Span> spans = [];
  bool _shutdown = false;

  @override
  Future<void> export(List<Span> s) async {
    if (_shutdown) return;
    spans.addAll(s);
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    _shutdown = true;
  }
}

Map<String, Object> _attrs(Span span) {
  return {for (final a in span.attributes.toList()) a.key: a.value};
}

void main() {
  group('OTelRiverpodObserver', () {
    late _MemorySpanExporter exporter;
    late ProviderContainer container;

    setUp(() async {
      await OTel.reset();
      exporter = _MemorySpanExporter();
      await OTel.initialize(
        serviceName: 'riverpod-otel-test',
        detectPlatformResources: false,
        spanProcessor: SimpleSpanProcessor(exporter),
      );
      container = ProviderContainer(
        observers: [OTelRiverpodObserver()],
      );
    });

    tearDown(() async {
      container.dispose();
      await OTel.shutdown();
      await OTel.reset();
    });

    test('didAddProvider emits an added span with name + value type', () {
      final counter = Provider<int>((_) => 42, name: 'counter');

      expect(container.read(counter), equals(42));

      expect(exporter.spans, hasLength(1));
      final span = exporter.spans.single;
      expect(span.name, equals('provider.added:counter'));
      final attrs = _attrs(span);
      expect(attrs['riverpod.provider.name'], equals('counter'));
      expect(attrs['riverpod.event'], equals('added'));
      expect(attrs['riverpod.provider.auto_dispose'], equals(false));
      expect(attrs['riverpod.value.type'], equals('int'));
      // Value content is opt-in — should not be present by default.
      expect(attrs.containsKey('riverpod.value'), isFalse);
    });

    test('recordValues: true captures value content (clipped)', () {
      container.dispose();
      container = ProviderContainer(
        observers: [
          OTelRiverpodObserver(recordValues: true, valueAttributeMaxLength: 10),
        ],
      );
      final p = Provider<String>(
        (_) => 'this is way longer than ten chars',
        name: 'long',
      );
      container.read(p);

      final added = exporter.spans.singleWhere(
        (s) => s.name == 'provider.added:long',
      );
      final value = _attrs(added)['riverpod.value']! as String;
      expect(value, endsWith('…'));
      expect(value.length, equals(11)); // 10 chars + ellipsis
    });

    test('NotifierProvider state change emits an updated span', () async {
      final notifierProvider = NotifierProvider<_Counter, int>(
        _Counter.new,
        name: 'counter',
      );

      container.read(notifierProvider); // didAddProvider
      container.read(notifierProvider.notifier).increment();
      // The next microtask drains the pending observer notifications.
      await Future<void>.delayed(Duration.zero);

      final updated = exporter.spans
          .where((s) => s.name == 'provider.updated:counter')
          .toList();
      expect(updated, hasLength(1));
      expect(_attrs(updated.single)['riverpod.event'], equals('updated'));
    });

    test('throwing provider triggers providerDidFail with Error status', () {
      final bad = Provider<int>(
        (_) => throw StateError('boom'),
        name: 'bad',
      );

      // Riverpod 3.x wraps the original error in a ProviderException
      // when read-throwing; we just need *something* to be thrown so
      // the provider-failed pathway fires.
      expect(() => container.read(bad), throwsA(anything));

      final failed = exporter.spans.singleWhere(
        (s) => s.name == 'provider.failed:bad',
      );
      expect(failed.status, equals(SpanStatusCode.Error));
      // recordException is fired as a span event named 'exception'.
      final events = failed.spanEvents ?? [];
      expect(
        events.any((e) => e.name == 'exception'),
        isTrue,
        reason: 'recordException should have emitted an exception event',
      );
    });

    test('autoDispose flag flows to the span attribute', () {
      final p = Provider.autoDispose<int>((_) => 1, name: 'temp');
      container.read(p);

      final added = exporter.spans.singleWhere(
        (s) => s.name == 'provider.added:temp',
      );
      expect(
        _attrs(added)['riverpod.provider.auto_dispose'],
        equals(true),
      );
    });

    test('family argument is recorded on the span', () {
      final family = Provider.family<int, int>(
        (_, arg) => arg * 2,
        name: 'doubler',
      );

      container.read(family(7));

      final added = exporter.spans.singleWhere(
        (s) => s.name == 'provider.added:doubler',
      );
      final attrs = _attrs(added);
      expect(attrs['riverpod.provider.argument'], equals('7'));
      expect(attrs['riverpod.provider.family'], equals('doubler'));
    });

    test('recordUpdates: false suppresses didUpdateProvider spans', () async {
      container.dispose();
      container = ProviderContainer(
        observers: [OTelRiverpodObserver(recordUpdates: false)],
      );

      final p = NotifierProvider<_Counter, int>(_Counter.new, name: 'silent');
      container.read(p);
      container.read(p.notifier).increment();
      await Future<void>.delayed(Duration.zero);

      expect(
        exporter.spans.any((s) => s.name == 'provider.updated:silent'),
        isFalse,
      );
      // The added span is still there.
      expect(
        exporter.spans.any((s) => s.name == 'provider.added:silent'),
        isTrue,
      );
    });
  });
}

class _Counter extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}
