// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

/// Integration test: drive a few Riverpod events through the observer
/// against a real OTLP endpoint, then poll Tempo's HTTP API to verify
/// the spans arrived with the expected `riverpod.*` semconv attributes.
///
/// Skipped when no LGTM stack is reachable. Bring one up first:
///   docker compose -f tool/lgtm/docker-compose.yml up -d
///
/// Env vars:
///   LGTM_OTLP_ENDPOINT — OTLP/HTTP endpoint (default http://localhost:4318)
///   LGTM_TEMPO_URL    — Tempo HTTP API base (default http://localhost:3200)
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_riverpod/otel_riverpod.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

const _defaultOtlp = 'http://localhost:4318';
const _defaultOtlpPort = 4318;
const _defaultTempo = 'http://localhost:3200';

void main() {
  group('LGTM end-to-end', () {
    final otlpEndpoint =
        Platform.environment['LGTM_OTLP_ENDPOINT'] ?? _defaultOtlp;
    final tempoUrl = Platform.environment['LGTM_TEMPO_URL'] ?? _defaultTempo;

    test('Riverpod observer spans appear in Tempo', () async {
      // Skip unless BOTH Tempo's HTTP API and the OTLP port are
      // reachable — Tempo /ready alone can match an unrelated service.
      final tempoOk = await _tempoReachable(tempoUrl);
      final otlpOk = await _portOpen(otlpEndpoint);
      if (!tempoOk || !otlpOk) {
        markTestSkipped(
          'LGTM not reachable (tempo=$tempoOk otlp=$otlpOk) — start it '
          'with `docker compose -f tool/lgtm/docker-compose.yml up -d` and '
          'rerun.',
        );
        return;
      }

      await OTel.reset();
      await OTel.initialize(
        serviceName: 'riverpod-otel-lgtm-itest',
        serviceVersion: '0.0.1',
        endpoint: otlpEndpoint,
      );

      final container = ProviderContainer(
        observers: [OTelRiverpodObserver()],
      );

      late String traceIdHex;
      await OTel.tracer().startActiveSpanAsync<void>(
        name: 'itest-root',
        fn: (rootSpan) async {
          traceIdHex = rootSpan.spanContext.traceId.hexString;
          // One added + one updated event so we can assert both
          // observer hooks produced spans on the wire.
          final counter = NotifierProvider<_Counter, int>(
            _Counter.new,
            name: 'itest-counter',
          );
          container.read(counter);
          container.read(counter.notifier).increment();
          await Future<void>.delayed(Duration.zero);
          container.dispose();
        },
      );

      await OTel.tracerProvider().forceFlush();
      await OTel.shutdown();

      final trace = await _pollTempoForTrace(
        tempoUrl: tempoUrl,
        traceIdHex: traceIdHex,
        timeout: const Duration(seconds: 30),
      );
      expect(
        trace,
        isNotNull,
        reason: 'Tempo never returned trace $traceIdHex. '
            'Check the LGTM container logs.',
      );

      final spans = <Map<String, dynamic>>[];
      for (final batch in (trace!['batches'] as List<dynamic>? ?? const [])) {
        final scopeSpans =
            (batch as Map<String, dynamic>)['scopeSpans'] as List<dynamic>? ??
                const [];
        for (final ss in scopeSpans) {
          final raw = (ss as Map<String, dynamic>)['spans'] as List<dynamic>? ??
              const [];
          for (final s in raw) {
            spans.add(s as Map<String, dynamic>);
          }
        }
      }
      expect(spans, isNotEmpty, reason: 'Trace had no spans');

      final names = spans.map((s) => s['name'] as String).toSet();
      expect(names, contains('provider.added:itest-counter'));
      expect(names, contains('provider.updated:itest-counter'));

      final addedSpan = spans.firstWhere(
        (s) => s['name'] == 'provider.added:itest-counter',
      );
      final attrKeys = <String>{
        for (final a in addedSpan['attributes'] as List<dynamic>? ?? const [])
          (a as Map<String, dynamic>)['key'] as String,
      };
      expect(attrKeys, contains('riverpod.provider.name'));
      expect(attrKeys, contains('riverpod.event'));
      expect(attrKeys, contains('riverpod.value.type'));
    }, timeout: const Timeout(Duration(minutes: 1)));
  });
}

class _Counter extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

/// Tempo readiness probe — returns 200 once the embedded backends are up.
Future<bool> _tempoReachable(String tempoUrl) async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    final req = await client.getUrl(Uri.parse('$tempoUrl/ready'));
    final resp = await req.close().timeout(const Duration(seconds: 2));
    await resp.drain<void>();
    client.close();
    return resp.statusCode == 200;
  } on Exception {
    return false;
  }
}

/// TCP probe — disambiguates the OTLP port from anything else listening on 3200.
Future<bool> _portOpen(String endpoint) async {
  try {
    final uri = Uri.parse(endpoint);
    final host = uri.host.isEmpty ? 'localhost' : uri.host;
    final port = uri.hasPort ? uri.port : _defaultOtlpPort;
    final socket =
        await Socket.connect(host, port, timeout: const Duration(seconds: 1));
    socket.destroy();
    return true;
  } on Exception {
    return false;
  }
}

/// Polls `GET {tempoUrl}/api/traces/{trace_id}` until the trace is
/// returned with at least one batch, or [timeout] elapses.
Future<Map<String, dynamic>?> _pollTempoForTrace({
  required String tempoUrl,
  required String traceIdHex,
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  final client = HttpClient();
  try {
    while (DateTime.now().isBefore(deadline)) {
      try {
        final req = await client.getUrl(
          Uri.parse('$tempoUrl/api/traces/$traceIdHex'),
        );
        final resp = await req.close();
        if (resp.statusCode == 200) {
          final body = await resp.transform(utf8.decoder).join();
          final parsed = jsonDecode(body) as Map<String, dynamic>;
          final batches = parsed['batches'] as List<dynamic>? ?? const [];
          if (batches.isNotEmpty) {
            return parsed;
          }
        } else {
          await resp.drain<void>();
        }
      } on Exception {
        // Transient — keep polling.
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  } finally {
    client.close();
  }
  return null;
}
