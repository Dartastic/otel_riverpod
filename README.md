# otel_riverpod

OpenTelemetry instrumentation for [`package:riverpod`](https://pub.dev/packages/riverpod),
built on the [Dartastic OpenTelemetry SDK](https://pub.dev/packages/dartastic_opentelemetry).

Add one `ProviderObserver` and every provider event gets a short span
on the active trace:

- `provider.added:<name>` when a provider initializes.
- `provider.updated:<name>` on each state change.
- `provider.failed:<name>` with `recordException` + `Error` status
  when a provider throws.
- `provider.disposed:<name>` when an auto-dispose provider unloads.

Each span carries the provider's name, runtime type, family argument
(if any), auto-dispose flag, and the value's runtime type. Together
they give you a trace timeline of your state graph that joins the
caller's existing trace, so a UI gesture → mutation → provider
update → HTTP call shows up as a single waterfall.

## Why

Riverpod's `ProviderObserver` is exactly the hook OTel was designed
to plug into, but writing one yourself means picking attribute keys,
deciding what to do on update vs. add vs. fail, and handling the
auto-dispose + family + mutation cases. This package is that
observer, written against a typed semconv enum once.

The integration is **opt-in**: the OTel SDK does not depend on
`riverpod`. Add this package only when you want it.

For Flutter apps using `flutter_riverpod`, see the companion package
`otel_flutter_riverpod` (same observer, exported via
`ProviderScope`).

## Usage

Pure Dart:

```dart
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_riverpod/otel_riverpod.dart';
import 'package:riverpod/riverpod.dart';

Future<void> main() async {
  await OTel.initialize(serviceName: 'my-app');

  final container = ProviderContainer(
    observers: [OTelRiverpodObserver()],
  );

  // Wrap your business logic in a span so the observer's child spans
  // attach to *something* rather than living on standalone traces.
  await OTel.tracer().startActiveSpanAsync<void>(
    name: 'handle-request',
    fn: (_) async {
      container.read(myProvider);
    },
  );

  container.dispose();
  await OTel.shutdown();
}
```

Flutter (via `flutter_riverpod`):

```dart
runApp(
  ProviderScope(
    observers: [OTelRiverpodObserver()],
    child: const MyApp(),
  ),
);
```

## Configuration

| Constructor arg | Default | Effect |
|---|---|---|
| `tracer` | `OTel.tracerProvider().getTracer('otel_riverpod')` | The tracer that emits the spans. |
| `recordValues` | `false` | When `true`, records `toString()` of provider values on `added` / `updated` events. Off by default because state often carries user data. |
| `recordUpdates` | `true` | When `false`, suppresses `didUpdateProvider` spans entirely — useful for chatty providers in production. |
| `valueAttributeMaxLength` | `256` | Cap on any `toString()`-derived attribute. Longer strings get clipped with `…`. |

## Span shape

| Attribute | Source | When set |
|---|---|---|
| `riverpod.provider.name` | `provider.name` or runtime type | always |
| `riverpod.provider.type` | `provider.runtimeType` (`Provider`, `NotifierProvider`, …) | always |
| `riverpod.provider.auto_dispose` | `provider.isAutoDispose` | always |
| `riverpod.event` | `added` / `updated` / `failed` / `disposed` | always |
| `riverpod.provider.family` | `provider.from?.name` | family providers |
| `riverpod.provider.argument` | `provider.argument.toString()` (clipped) | family providers |
| `riverpod.value.type` | `value.runtimeType` | when value is non-null |
| `riverpod.value` | `value.toString()` (clipped) | only when `recordValues: true` |
| `riverpod.previous_value` | `previousValue.toString()` (clipped) | `updated` events + `recordValues: true` |
| `riverpod.mutation` | `ProviderObserverContext.mutation.toString()` | when triggered by a `@mutation` |

- **Span name** is `provider.<event>:<name>`, e.g.
  `provider.updated:counter`.
- **Span kind** is the default (`INTERNAL`).
- **Span status** is `Error` only on `providerDidFail`; everything
  else stays unset.

## Caveats

- The observer calls `OTel.tracerProvider().getTracer(...)` in its
  constructor — `OTel.initialize()` must have run first.
- `providerDidFail` runs for every error a provider sees, including
  errors propagated through `Future` / `Stream`. Expect more than one
  failed span if you re-listen to a still-broken provider.
- If you set `recordValues: true`, make sure your provider state's
  `toString()` is safe to log (no credentials, no PII). The default
  is off precisely so you have to opt in.

## License

Apache 2.0 — see `LICENSE`.
