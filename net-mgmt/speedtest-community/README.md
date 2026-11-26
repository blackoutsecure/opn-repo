# Speedtest for OPNsense

Speedtest measures WAN download, upload, latency, jitter, and target quality
through interchangeable public and custom measurement networks. The interface
provides provider-first labels:

- Ookla
- LibreSpeed
- Cloudflare

Technical connection and client details are shown in **Sources and targets >
About Speedtest**, where they can be viewed without cluttering the normal
network selection controls.

Target lists are refreshed automatically when the page first opens, when an
enabled network has no saved targets, or when the configured refresh interval
expires. Public target on/off choices survive refreshes, and custom targets are
not removed.

## User interface

- **Measure** runs an automatic or explicitly selected test, reports live
  status, updates the gauges with available transfer samples, and retains the
  run timeline after completion.
- **Results** lists saved measurements, supports text filtering, and exposes
  provider-supplied client, ISP, network, target, selection, and geo data.
- **Sources and targets** controls enabled networks, selection behavior, public
  list URLs, individual target availability, and custom targets.

Providers that expose only final totals show a truthful status/elapsed-time view
until completion. Providers that expose streamed progress drive the live
throughput graph and gauges in real time.

Measurement engines are implementation details. The plugin uses a compatible
native engine when available and otherwise uses its standard-library fallback;
operators do not need to select or install an engine from the UI.

### Cloudflare and Rust

Cloudflare's official `@cloudflare/speedtest` engine is browser-only: its
throughput timings depend on `PerformanceResourceTiming`, and its official
packet-loss path uses WebRTC/TURN. Running that JavaScript on the firewall would
measure the browser's route instead of OPNsense's route, so the browser engine
is not bundled.

Speedtest therefore uses an independent standard-library HTTP adapter for live
Cloudflare download/upload graphs. When an external `cloudflare-speed-cli`
binary is present, the plugin may additionally run its UDP/STUN diagnostic with
zero-byte transfer durations. Results are explicitly labeled `udp-stun`; this
is a useful native approximation, not a claim of Cloudflare's browser/TURN
measurement.

`cloudflare-speed-cli` is a separate GPL-3.0 program and is not linked into or
copied into the BSD-licensed plugin. The optional Rust engine build installs it
as an external executable, and About Speedtest identifies the version, role,
and license. If unavailable, the normal Cloudflare HTTP test remains fully
functional but reports packet loss as not supplied.

## Direct CLI

The installed command-line wrapper is:

```sh
/usr/local/bin/python3 \
  /usr/local/opnsense/scripts/OPNsense/speedtest/opn_speedtest.py
```

Supported commands:

| Command | Purpose |
| --- | --- |
| `about` | Return package, runtime, engine, and dependency versions. |
| `version` | Return the legacy native CLI version response. |
| `providers` | Return enabled/available networks and capabilities. |
| `list [network]` | List targets. `network` is `all`, `ookla`, `librespeed`, or `cloudflare`. |
| `discover [network]` | Fetch public targets without running a transfer test. |
| `run [network] [target]` | Run a test. Omitting both starts automatic cross-network selection. |
| `progress` | Return current phase, elapsed time, percentage, and available live samples. |
| `results [limit]` | Return saved results as JSON-compatible row data; default 1000, maximum 10000. |
| `log [limit]` | Return recent saved results; default 50, maximum 5000. |
| `stat` | Return aggregate download, upload, latency, and sample counts. |
| `recent` | Return the newest result. |
| `clear` | Clear saved history. |

Legacy compatibility is retained:

```sh
opn_speedtest.py                 # Native Ookla automatic selection
opn_speedtest.py 63762            # Specific numeric Ookla target
opn_speedtest.py run auto auto   # Cross-network automatic selection
```

## Configd / automation

The same commands are exposed through OPNsense `configctl`:

```sh
configctl speedtest version
configctl speedtest about
configctl speedtest providers
configctl speedtest serverlist-provider all
configctl speedtest discover all
configctl speedtest run-provider auto auto
configctl speedtest progress
configctl speedtest results 1000
configctl speedtest showstat
configctl speedtest showrecent
```

Legacy actions remain available for existing cron jobs:

```sh
configctl speedtest run 0
configctl speedtest run 63762
configctl speedtest serverlist
```

## Results and privacy

The original CSV columns remain stable. New columns append the transfer
engine and a `DetailsJson` object containing:

- client IP and any provider-supplied hostname, ISP/network, city, region,
  country, coordinates, VPN status, and timezone;
- target ID, name, URL/host, location, country, sponsor, and edge information;
- selection candidates, live transfer samples, warnings, and provider-specific
  protocol/byte/TLS details.
- Packet loss is appended as a measured percentage plus method. It remains
  blank for providers that do not report packet loss.

Only data supplied by the selected measurement network is recorded. The plugin
does not call a separate geolocation service. History stays local to the
OPNsense host and is removable from the Results tab or with the `clear`
command.

## Package build

The repository uses the OPNsense BSD make plugin framework:

```sh
bmake -C net-mgmt/speedtest-community package
pkg delete -fy os-speedtest-community
pkg add work/pkg/os-speedtest-community-*.pkg
```

Focused Python tests run with:

```sh
python3 -m unittest discover \
  -s net-mgmt/speedtest-community/tests -p 'test_*.py'
```
