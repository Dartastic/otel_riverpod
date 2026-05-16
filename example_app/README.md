# otel_riverpod example app

A standalone runnable demo of `otel_riverpod` exporting
telemetry to a local LGTM stack (Grafana + Loki + Tempo + Mimir).

## Run

```sh
# 1. Start the LGTM stack (from the dartastic-pro repo root)
docker compose -f tool/lgtm/docker-compose.yml up -d

# 2. Run the app
cd dart/otel_riverpod/example_app
dart pub get
dart run bin/main.dart
```

## What it does

Five scenarios, each in its own parent span. Inside a single
`run-scenarios` root trace you'll see all 19 spans (5 scenario
parents + 14 observer events):

| Scenario | Observer hook exercised |
|---|---|
| `plain-provider-add` | `didAddProvider` on a `Provider<String>` |
| `notifier-update` | `didAddProvider` + two `didUpdateProvider`s from a `NotifierProvider<int>` |
| `family-with-argument` | `didAddProvider` with `riverpod.provider.family` + `argument` attributes |
| `auto-dispose-and-recycle` | `didAddProvider` + `didDisposeProvider` for an auto-dispose provider |
| `failing-provider` | `providerDidFail` — span status flipped to Error, `recordException` event attached |

The example uses `recordValues: true` so the value content shows up
in Tempo. Production apps should leave the default (off) because
provider state often carries user data.

## Where to look

Grafana → Explore → Tempo datasource:

- Service name: `riverpod-otel-example-app`
- Open the `run-scenarios` trace to see the waterfall of all
  scenarios and their observer events as child spans.
- Click any `provider.added:*` / `provider.updated:*` /
  `provider.failed:*` span to inspect the `riverpod.*` attribute set.

## Env

| Variable | Default | Purpose |
|---|---|---|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://localhost:4318` | OTLP HTTP endpoint (the SDK's default protocol). For gRPC, also set `OTEL_EXPORTER_OTLP_PROTOCOL=grpc` and point at port 4317. |
