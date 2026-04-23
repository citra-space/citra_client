# CitraClient

Elixir client for the [Citra Space](https://citra.space) API. All bindings
are **generated at compile time** from the live OpenAPI schema at
<https://dev.api.citra.space/openapi.json>, so the client stays in sync with
the API without hand-written wrappers.

## Installation

```elixir
def deps do
  [
    {:citra_client, "~> 0.3.0"}
  ]
end
```

The first `mix compile` (or `mix deps.compile citra_client`) will fetch the
OpenAPI schema from dev, cache it to `priv/openapi.json`, and metaprogram:

  * one struct module per component schema under `CitraClient.Schemas.*`
  * one operations module per OpenAPI tag under `CitraClient.*`
    (e.g. `CitraClient.GroundStations`, `CitraClient.Satellites`,
    `CitraClient.Antennas`, `CitraClient.Weather`)

## Configuration

```elixir
# config/config.exs
config :citra_client, :env, :dev     # or :prod
config :citra_client, :api_token, "..."
```

…or at runtime:

```elixir
CitraClient.set_env(:prod)
CitraClient.set_token(System.get_env("CITRA_PAT"))
```

## Usage

Each generated function takes path parameters as positional arguments,
the request body (if any) as the next positional argument, and query
parameters via a trailing keyword list.

```elixir
# GET /ground-stations
{:ok, %CitraClient.Schemas.GroundStationList{ground_stations: stations}} =
  CitraClient.GroundStations.get_ground_stations()

# GET /ground-stations/{ground_station_id}
{:ok, %CitraClient.Schemas.GroundStation{} = gs} =
  CitraClient.GroundStations.get_ground_station(id)

# POST /ground-stations — pass a struct or a plain map
{:ok, id} =
  CitraClient.GroundStations.create_ground_station(%CitraClient.Schemas.GroundStationInput{
    name: "My station",
    latitude: 40.7128,
    longitude: -74.006,
    altitude: 10.0
  })

# GET /satellites?page=1&pageSize=10 — query params go in opts (snake_case)
{:ok, page} = CitraClient.Satellites.get_satellites(page: 1, page_size: 10)

# GET /weather?lat=...&lon=...&units=metric
{:ok, weather} = CitraClient.Weather.get_weather(lat: 40.7, lon: -74.0, units: "metric")
```

Return shape:

  * `{:ok, decoded}` on 2xx — where `decoded` is a generated struct if the
    response schema is a named component, a list of structs for array
    responses, or the raw decoded JSON otherwise
  * `:ok` for 204 responses
  * `{:error, {status, body}}` on non-2xx

Date/time fields (`format: date-time`) are coerced to `DateTime`, date
fields to `Date`. When encoding a struct back to the API (in a request
body), `DateTime`/`Date` values are converted back to ISO-8601 strings
and field names are converted back to camelCase.

## S3 image upload

The OpenAPI surface only covers *initiating* an image upload
(`POST /my/images`) — the final multipart `PUT` hits AWS directly and is
not described in the schema, so it stays hand-written:

```elixir
:ok = CitraClient.upload_image_to_s3(telescope_id, "/path/to/image.fits")
```

## Dev vs prod schema

Citra exposes a dev and a prod OpenAPI surface. Dev is a superset of prod
(133 shared operations; dev adds ~8 experimental endpoints and a handful
of extra schemas), and the two disagree on about a dozen shared schemas
where dev has added fields ahead of prod. The generator picks a target
with this precedence (highest first):

  1. `CITRA_CLIENT_COMPILE_ENV=dev|prod` environment variable
  2. `config :citra_client, compile_env: :dev | :prod` in the consumer's
     `config/*.exs` (recorded via `Application.compile_env/3`, so changing
     it triggers a rebuild warning for the dep)
  3. Default: `:dev` (the superset)

The two targets:

  * **`dev`** — fetches <https://dev.api.citra.space/openapi.json>. You
    get bindings for every endpoint. The decoder is tolerant of
    missing/extra fields, so the dev-compiled bindings decode prod
    responses correctly for every shared operation; calling a dev-only
    operation against prod returns `{:error, {404, _}}`.
  * **`prod`** — fetches <https://api.citra.space/openapi.json> and pins
    the bindings to the stable prod schema. Use this for release builds
    that must not accidentally call a dev-only endpoint.

From a consumer's `config/prod.exs`:

```elixir
config :citra_client, compile_env: :prod
```

…or for a one-off build:

```
CITRA_CLIENT_COMPILE_ENV=prod mix compile
```

After changing the config, force a dep rebuild so the bindings reflect
the new target: `mix deps.compile citra_client --force`.

The compile target is independent of the *runtime* environment selected
by `CitraClient.set_env/1`, which only picks the base URL:

  * `:dev` (default) — `https://dev.api.citra.space/`
  * `:prod` — `https://api.citra.space/`

`CitraClient.Generated.compile_env/0` reports which spec the current
build was generated from.

## Refreshing the schema

The compiled bindings are frozen at compile time. To pick up API changes:

```
mix clean && mix compile         # full live refetch
# or
rm priv/openapi.dev.json && mix compile --force
```

`priv/openapi.{dev,prod}.json` are tracked as `@external_resource`, so
editing one directly (or replacing it) will invalidate the generated
modules on the next build.

## Offline builds

If the live URL is unreachable, the build falls back to the matching
per-env cache in `priv/` if it exists. To force a specific spec file and
skip the live fetch entirely, set `CITRA_CLIENT_SPEC_PATH` to its path:

```
CITRA_CLIENT_SPEC_PATH=/path/to/openapi.json mix compile
```

`CITRA_CLIENT_SPEC_URL` overrides the fetch URL entirely (useful for
pointing at a staging host).
