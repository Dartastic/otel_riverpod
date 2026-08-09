# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-08-10

### Added

- `example/otel_riverpod_example.dart` — a runnable, pub.dev-visible
  example driving every observer hook against a standard OTLP
  endpoint.

### Removed

- The internal `example_app/` (never shipped in the pub archive),
  superseded by `example/`.

## [0.1.0-beta.1] - 2026-05-16

### Added

- `OTelRiverpodObserver` — a `ProviderObserver` that emits one short
  span per Riverpod observer callback (`didAddProvider`,
  `didUpdateProvider`, `providerDidFail`, `didDisposeProvider`). Each
  span carries the OTel semconv-style `riverpod.*` attributes
  (provider name / type / argument / family / auto-dispose flag,
  value type, plus mutation when present).
- `RiverpodSemantics` — typed attribute-key enum implementing
  `OTelSemantic`, package-local because OTel has no upstream
  semantic convention for state-management frameworks yet.
- `providerDidFail` is recorded via `recordException` then
  `setStatus(SpanStatusCode.Error, ...)`, in OTel-spec order.
- `recordValues` flag (off by default) for capturing value content
  on add / update events; `valueAttributeMaxLength` for clipping.
- Targets `riverpod: ^3.0.0`. Works with both pure-Dart
  `ProviderContainer` and Flutter's `ProviderScope`.
