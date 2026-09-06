// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

/// Guards that keep instrumentation out of the functional path.
///
/// Every `OTel.*` entry point in `dartastic_opentelemetry` routes through
/// `OTel._getAndCacheOtelFactory()`, which throws
/// `StateError('OTel.initialize() must be called first.')` until the SDK
/// has been initialized. On a real device that is a normal, expected
/// state, not a programming error: the collector is unreachable, the
/// build flavour skips `OTel.initialize()`, initialization is still in
/// flight, or it failed outright.
///
/// The SDK exposes no public "is OTel initialized" predicate (checked
/// against dartastic_opentelemetry 1.1.0-beta.15), so these helpers guard
/// the telemetry call itself. They never wrap the operation being
/// instrumented, so a `StateError` raised by application code still
/// reaches the caller unchanged.
library;

/// Runs [telemetry] and returns its result, or `null` when the OTel SDK
/// is not initialized.
T? tryTelemetry<T extends Object>(T Function() telemetry) {
  try {
    return telemetry();
    // The SDK signals "not initialized" with a StateError and offers no
    // predicate to test for it, so this Error subtype has to be caught.
    // ignore: avoid_catching_errors
  } on StateError {
    return null;
  }
}

/// Runs [telemetry] for its side effects, ignoring an uninitialized SDK.
void tryTelemetryEffect(void Function() telemetry) {
  try {
    telemetry();
    // See tryTelemetry: the SDK signals "not initialized" with a
    // StateError and offers no predicate to test for it.
    // ignore: avoid_catching_errors
  } on StateError {
    // Deliberately swallowed; see the library doc comment.
  }
}
