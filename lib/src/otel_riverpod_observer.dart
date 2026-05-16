// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:riverpod/riverpod.dart';

import 'riverpod_semantics.dart';

/// OpenTelemetry instrumentation for `package:riverpod`.
///
/// Each Riverpod observer callback emits one short span on the
/// configured [Tracer]. This gives you a discrete event on the trace
/// timeline for every provider that gets initialized, updated,
/// disposed, or fails — without producing app-lifetime spans for
/// long-lived singleton providers.
///
/// Install in the `ProviderContainer` (pure Dart):
///
/// ```dart
/// final container = ProviderContainer(
///   observers: [OTelRiverpodObserver()],
/// );
/// ```
///
/// or in `ProviderScope` (Flutter — same instance, no wrapper needed):
///
/// ```dart
/// runApp(
///   ProviderScope(
///     observers: [OTelRiverpodObserver()],
///     child: const MyApp(),
///   ),
/// );
/// ```
///
/// Span shape per event:
///
/// | Event | Span name | Status |
/// |---|---|---|
/// | `didAddProvider` | `provider.added:<name>` | unset |
/// | `didUpdateProvider` | `provider.updated:<name>` | unset |
/// | `providerDidFail` | `provider.failed:<name>` | Error + `recordException` |
/// | `didDisposeProvider` | `provider.disposed:<name>` | unset |
///
/// Spans inherit the active context, so a provider event that fires
/// inside a user span (e.g. a route-change span) joins that trace.
final class OTelRiverpodObserver extends ProviderObserver {
  /// Creates an observer.
  ///
  /// - [tracer] — the tracer to use. Defaults to
  ///   `OTel.tracerProvider().getTracer('otel_riverpod')`.
  /// - [recordValues] — when `true`, also record `toString()` of the
  ///   provider's current (and on update, previous) value. Defaults
  ///   to `false` because provider state often carries user data;
  ///   the runtime *type* of values is always recorded.
  /// - [recordUpdates] — when `false`, suppresses spans on
  ///   `didUpdateProvider`. Useful for chatty providers in production.
  ///   Defaults to `true`.
  /// - [valueAttributeMaxLength] — cap on the length of any
  ///   value-derived attribute (`toString()` of argument / value /
  ///   previousValue). Defaults to 256.
  OTelRiverpodObserver({
    Tracer? tracer,
    this.recordValues = false,
    this.recordUpdates = true,
    this.valueAttributeMaxLength = 256,
  }) : _tracer = tracer ??
            OTel.tracerProvider().getTracer('otel_riverpod');

  final Tracer _tracer;

  /// When `true`, the observer records value content (`toString()`) on
  /// add / update events. Off by default; see constructor docs.
  final bool recordValues;

  /// When `false`, `didUpdateProvider` events are silently ignored.
  final bool recordUpdates;

  /// Maximum length of any attribute value derived from a Dart
  /// object's `toString()` (provider argument, value, previous value).
  final int valueAttributeMaxLength;

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    final span = _startEventSpan(context, event: 'added');
    _attachValueAttributes(span, value: value, previousValue: null);
    span.end();
  }

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (!recordUpdates) return;
    final span = _startEventSpan(context, event: 'updated');
    _attachValueAttributes(
      span,
      value: newValue,
      previousValue: previousValue,
    );
    span.end();
  }

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    final span = _startEventSpan(context, event: 'failed');
    // Per OTel spec: recordException event, THEN setStatus.
    span.recordException(error, stackTrace: stackTrace);
    span.setStatus(SpanStatusCode.Error, error.toString());
    span.end();
  }

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    final span = _startEventSpan(context, event: 'disposed');
    span.end();
  }

  APISpan _startEventSpan(
    ProviderObserverContext context, {
    required String event,
  }) {
    final provider = context.provider;
    final name = provider.name ?? provider.runtimeType.toString();

    final attrs = <String, Object>{
      RiverpodSemantics.providerName.key: name,
      RiverpodSemantics.providerType.key: provider.runtimeType.toString(),
      RiverpodSemantics.providerAutoDispose.key: provider.isAutoDispose,
      RiverpodSemantics.event.key: event,
    };

    final family = provider.from;
    if (family != null) {
      attrs[RiverpodSemantics.providerFamily.key] =
          family.name ?? family.runtimeType.toString();
    }

    final argument = provider.argument;
    if (argument != null) {
      attrs[RiverpodSemantics.providerArgument.key] =
          _clip(argument.toString());
    }

    final mutation = context.mutation;
    if (mutation != null) {
      attrs[RiverpodSemantics.mutation.key] = mutation.toString();
    }

    return _tracer.startSpan(
      'provider.$event:$name',
      attributes: OTel.attributesFromMap(attrs),
    );
  }

  void _attachValueAttributes(
    APISpan span, {
    required Object? value,
    required Object? previousValue,
  }) {
    final extras = <String, Object>{};
    if (value != null) {
      extras[RiverpodSemantics.valueType.key] = value.runtimeType.toString();
      if (recordValues) {
        extras[RiverpodSemantics.value.key] = _clip(value.toString());
      }
    }
    if (previousValue != null && recordValues) {
      extras[RiverpodSemantics.previousValue.key] =
          _clip(previousValue.toString());
    }
    if (extras.isNotEmpty) {
      span.addAttributes(OTel.attributesFromMap(extras));
    }
  }

  String _clip(String s) {
    if (s.length <= valueAttributeMaxLength) return s;
    return '${s.substring(0, valueAttributeMaxLength)}…';
  }
}
