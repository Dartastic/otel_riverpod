// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

/// Typed attribute keys for `package:riverpod` instrumentation.
///
/// There is no official OTel semantic convention for state-management
/// frameworks yet, so this enum is package-local. It follows the OTel
/// convention of grouping under a namespace (`riverpod.*`) and is
/// stable across the package's 0.x line — renaming a key is a
/// breaking change because it changes downstream queries.
enum RiverpodSemantics implements OTelSemantic {
  /// The provider's user-given `name`, or its runtime type when no
  /// name was set. Picked up by Riverpod's own devtools.
  providerName('riverpod.provider.name'),

  /// The provider's runtime class (e.g. `Provider`, `FutureProvider`,
  /// `NotifierProvider`). Lets you slice spans by provider kind.
  providerType('riverpod.provider.type'),

  /// `true` when the provider is auto-disposed.
  providerAutoDispose('riverpod.provider.auto_dispose'),

  /// If the provider came from a family, the family's name.
  providerFamily('riverpod.provider.family'),

  /// The family argument the provider was instantiated with. Captured
  /// via `toString()` and clipped to a configurable max length so
  /// large arguments don't blow up the trace payload.
  providerArgument('riverpod.provider.argument'),

  /// Which observer hook fired — `added` / `updated` / `failed` /
  /// `disposed`. Mirrors the `ProviderObserver` callback name.
  event('riverpod.event'),

  /// The runtime class of the provider's current value. Always safe
  /// to record — no value content leaks.
  valueType('riverpod.value.type'),

  /// The provider's current value's `toString()`, clipped. Only set
  /// when the observer is constructed with `recordValues: true`,
  /// because state objects often contain user data.
  value('riverpod.value'),

  /// The provider's previous value's `toString()`, clipped. Only set
  /// on `didUpdateProvider` when `recordValues: true`.
  previousValue('riverpod.previous_value'),

  /// `Mutation.toString()` when the event was triggered inside a
  /// `@mutation`-annotated method. Lets you correlate state changes
  /// to the user-named mutation that caused them.
  mutation('riverpod.mutation');

  const RiverpodSemantics(this.key);

  @override
  final String key;

  @override
  String toString() => key;
}
