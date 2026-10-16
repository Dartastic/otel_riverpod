<!-- dartastic-header:start -->
# OpenTelemetry instrumentation for `riverpod`

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![OpenTelemetry Specification](https://img.shields.io/badge/OpenTelemetry-Specification-blueviolet)](https://opentelemetry.io/docs/specs/otel/)

`otel_riverpod` is an [OpenTelemetry](https://opentelemetry.io/) instrumentation for `riverpod` that
easily adds standard observability to applications that use `riverpod`.  This package depends on 
[dartastic_opentelemetry_api](https://pub.dev/packages/dartastic_opentelemetry_api).

This package can be used with any OTel backend because it's compliant with the OpenTelemetry Specification.

This package supports Android, iOS, Linux, macOS, Web and Windows, for versions of `riverpod` that support those platforms. It is WASM-ready.

This Apache-2.0 package is professionally maintained and supported with 💙 by Michael Bushe,
Dart and Flutter Maintainer at OpenTelemetry and the creator of [dartastic_opentelemetry](https://pub.dev/packages/dartastic_opentelemetry)
and [dartastic_opentelemetry_api](https://pub.dev/packages/dartastic_opentelemetry_api). This package is professionally supported by
[Dartastic.io](https://dartastic.io).

---
## Dartastic.io: AI Code Healing and Real User Monitoring for Flutter

**See what your users experience. Find problems with Flutter apps in production. Fix them with AI.**

[Dartastic.io](https://dartastic.io) brings AI code healing, real user monitoring, and OpenTelemetry observability together in one platform built for Dart and Flutter. (Patents pending)

![Dartastic AI answering "Why did crashes jump after the last release?" over a Flutter App Health dashboard](https://dartastic.io/img/pub-dev/HomePageCrashesQuestion.png)

### Dartastic AI — From Production Problems to Code Fixes

Dartastic AI analyzes production telemetry alongside your application source code to diagnose problems and propose fixes.

- **Investigate production issues** using crashes, errors, traces, metrics, and real user telemetry.
- **Find the offending code** by connecting observed problems with your application's source in Dartastic Pub or your source code repos.
- **Generate code patches** that address the underlying problems.
- **Create actionable issues** in your issue tracker, complete with findings and the proposed code patch.

### Dartastic RUM — See What Your Users See

Understand how people actually experience your Flutter application.

- **Replay user sessions** in the Dartastic Observatory session player.
- **Choose your replay fidelity**, from privacy-preserving widget outlines to pixel-level reproductions of the user experience.
- **Investigate real user problems** using session replay and production observability data.

![Dartastic RUM Session Replay](https://dartastic.io/img/pub-dev/session-replay.png)

### Dartastic Observatory — Observability Built for Flutter

A complete observability backend where Flutter and Dart are first-class citizens.

- **Flutter-specific dashboards** for application performance, health, and reliability.
- **Alerts and notifications** through email, Slack, and PagerDuty.
- **Dartastic Cloud Observatory** — Start with a 30-day free trial on isolated, shared infrastructure, as low as $39/mo.
- **Dartastic Hosted Observatory** — Run the observability stack in a private managed environment, sized from Mini to Enterprise XL.
- **Dartastic Self-Hosted Observatory** — The whole platform inside your own network. Your keys, your cluster, with nothing leaving your perimeter.

### Dartastic Native OTel Runtime — Native OpenTelemetry Performance

Collect production telemetry without burdening Flutter's main isolate.

- **Native OpenTelemetry runtime** that moves telemetry processing off the main isolate.
- **Native crash reporting** for problems that Dart can't catch.
- **Widget performance diagnostics** to identify janky widgets.
- **On-device PII filtering** before sensitive data leaves your application.
- **Source-level error diagnostics** powered by the Dartastic Symbolizer API.
- **Platform-native metrics** for iOS, Android, and Linux, including iOS MetricKit and Android Vitals.
- **OpenTelemetry compatibility** — Send telemetry to Dartastic Observatory or any OpenTelemetry platform.

### Dartastic Labs — OpenTelemetry Integrations

Instrument more of your application without writing everything yourself.

- **650+ open-source integrations** for Dart and Flutter libraries and services, including Dio, Shelf, Logger, Anthropic, AWS, Azure, and Stripe. Look for otel_* on pub.dev.

### More Dartastic Tools

**[Dartastic Pub](https://dartastic.io/pub)**

A private Dart package registry for sharing packages and plugins with your team, partners, and customers.

**[Dartastic Symbolizer](https://dartastic.io/symbolizer)**

Turn production errors into lines of source code through a web API, while keeping your source code artifacts private.

### Professional Support and Training

Dartastic.io offers commercial support for the open-source `dartastic_opentelemetry` and `dartastic_opentelemetry_api` packages and the complete Dartastic product suite.

- **Professional support** with available around-the-clock coverage and response times under four hours on qualifying plans.
- **OpenTelemetry training** for teams instrumenting Dart, Flutter, mobile, and web applications.

### Open Standards. No Mandatory Backend.

The Dartastic OpenTelemetry API and SDK are open source and standards-based. You can use them independently of Dartastic's commercial services and send telemetry to any compatible OpenTelemetry backend.

Dartastic's commercial products add native performance, advanced diagnostics, session replay, AI-assisted remediation, and managed observability services.

**[Explore Dartastic.io](https://dartastic.io)**

---
<!-- dartastic-header:end -->

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

| Constructor arg           | Default                                            | Effect                                                                                                                                    |
|---------------------------|----------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| `tracer`                  | `OTel.tracerProvider().getTracer('otel_riverpod')` | The tracer that emits the spans.                                                                                                          |
| `recordValues`            | `false`                                            | When `true`, records `toString()` of provider values on `added` / `updated` events. Off by default because state often carries user data. |
| `recordUpdates`           | `true`                                             | When `false`, suppresses `didUpdateProvider` spans entirely — useful for chatty providers in production.                                  |
| `valueAttributeMaxLength` | `256`                                              | Cap on any `toString()`-derived attribute. Longer strings get clipped with `…`.                                                           |

## Span shape

| Attribute                        | Source                                                     | When set                                |
|----------------------------------|------------------------------------------------------------|-----------------------------------------|
| `riverpod.provider.name`         | `provider.name` or runtime type                            | always                                  |
| `riverpod.provider.type`         | `provider.runtimeType` (`Provider`, `NotifierProvider`, …) | always                                  |
| `riverpod.provider.auto_dispose` | `provider.isAutoDispose`                                   | always                                  |
| `riverpod.event`                 | `added` / `updated` / `failed` / `disposed`                | always                                  |
| `riverpod.provider.family`       | `provider.from?.name`                                      | family providers                        |
| `riverpod.provider.argument`     | `provider.argument.toString()` (clipped)                   | family providers                        |
| `riverpod.value.type`            | `value.runtimeType`                                        | when value is non-null                  |
| `riverpod.value`                 | `value.toString()` (clipped)                               | only when `recordValues: true`          |
| `riverpod.previous_value`        | `previousValue.toString()` (clipped)                       | `updated` events + `recordValues: true` |
| `riverpod.mutation`              | `ProviderObserverContext.mutation.toString()`              | when triggered by a `@mutation`         |

- **Span name** is `provider.<event>:<name>`, e.g.
  `provider.updated:counter`.
- **Span kind** is the default (`INTERNAL`).
- **Span status** is `Error` only on `providerDidFail`; everything
  else stays unset.

## Context propagation

Every span takes its parent from the OpenTelemetry context that is
current when the observer hook fires. Whether that is the context of
the code that caused the change depends on how Riverpod runs it:

| What happens                                                                | Parent of the span (and of spans started there) |
|-----------------------------------------------------------------------------|-------------------------------------------------|
| A notifier method called from your code (`ref.read(p.notifier).go()`)       | The caller's span                               |
| `ref.listen` / `container.listen` callbacks                                 | The caller's span                               |
| A dependent provider rebuilt by `ProviderContainer`'s scheduler (pure Dart) | The caller's span                               |
| A dependent provider rebuilt by `ProviderScope` on the next frame (Flutter) | **Not** the caller's span                       |
| A provider built lazily on first read                                       | The reader's span                               |

In Flutter, `ProviderScope` flushes pending rebuilds during the next
frame, outside the zone that invalidated them. Riverpod gives
observers no record of which update caused a rebuild, so this package
does not guess one. Riverpod's own `ProviderObserverContext.mutation`
is null for those rebuilds for the same reason.

If work caused by a user action should nest under that action's span
(a network call after a tap, say), start it from the notifier method
the action calls, not from the body of a provider that depends on the
notifier.

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
