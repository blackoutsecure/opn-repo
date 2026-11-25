# LibreSpeedtest for OPNsense

[LibreSpeed](https://librespeed.org/) is the only measurement provider.
Version **0.15** bundles the pinned native Rust `librespeed-cli 1.2.1`.
There are **no additional runtime package dependencies**: integration uses
OPNsense's existing PHP/Volt, configd and Python standard library. No compiler,
Go, Node.js, extra Python package, daemon or network listener is installed.

The Blackout Secure Rust guidance favors a narrow, maintained measurement
engine over rewriting the platform's configuration, ACL and history facilities.
The adapter preserves existing cron and CSV contracts.
No unverified Blackout foundation crate is introduced.

The reporting page now includes background measurements with phase/rate
progress, sequential server comparisons, throughput and latency/jitter trends,
filtered/paged history, detailed exports and an optional native cron schedule.
Diagnostics and failures are retained, not silently discarded. Charts reuse
the Chart.js already shipped by OPNsense; no external assets are loaded.
During GUI and scheduled tests, per-phase bars show progress and the live
graph plots the engine's running-average download and upload rates. Server
selection and latency have indeterminate progress because the engine does not
report a percentage for those phases. The live graph contains the current or
most recently tested server in a comparison and resets for the next server.

## Setup and saved defaults

When no custom or administrator-managed server list is available, the plugin
uses the official LibreSpeed.org public list by default. It retrieves the list
from [`servers.php`](https://librespeed.org/backend-servers/servers.php) over
HTTPS, validates the entries, then selects the lowest-latency server. In
**Reporting > Speedtest > Setup and CLI**, disable **Use the official
LibreSpeed.org public server list** to opt out. The registry and selected test
servers can see the firewall's public IP; the plugin does not share results or
send telemetry. List retrieval or validation failures are reported
explicitly; they never fall back to an unexpected server.

Save up to 50 custom HTTPS servers with unique positive IDs and relative
endpoint paths to prefer servers you operate or are authorized to use:

```json
[
  {
    "id": 42,
    "name": "Blackout lab",
    "server": "https://bench.example.net/",
    "dlURL": "garbage.php",
    "ulURL": "empty.php",
    "pingURL": "empty.php",
    "getIpURL": "getIP.php"
  }
]
```

The paths depend on your server backend. The example host is a placeholder,
not a provisioned service. Saved custom servers take priority over the
administrator-managed file; if neither exists, the optional official public
list is used. `0` selects the lowest-latency server; `-1` compares all listed
servers sequentially.
Choose specific IDs or exclude servers from automatic/all-server selection.
Explicit IDs cannot be combined with exclusions. A local source binding is
retained for like-for-like history filtering. Existing CSV data is preserved.

Saving also persists advanced measurement defaults under
`OPNsense/speedtest/general` in `/conf/config.xml`, using native model validation,
configuration locking, revisions and backups. New GUI, cron, API and terminal
runs inherit these defaults; explicit run options override them. No restart is
needed. Leave server JSON empty to use the root-owned file
`/usr/local/etc/speedtest-community/librespeed-servers.json`. Saved nonempty
server JSON takes precedence. If the file is absent, public list discovery
follows the **Use the official LibreSpeed.org public server list** setting;
terminal `--config` explicitly overrides all other sources.
The external server file and CA bundle are not embedded in configuration backups.
Server lists may contain up to 50 entries and 64 KiB. GUI settings are
compacted and must also fit the native configd message limit (3500 encoded
bytes); oversized settings are rejected with an actionable error instead of
being truncated. Use the external file for unusually long lists or URLs.

## Capabilities and boundaries

| Control | Default / supported range |
| --- | --- |
| Mode | Recommended full test (download, upload, latency and jitter); download-only, upload-only, latency/jitter-only. Every mode measures latency and jitter. |
| Duration per direction | 10 seconds; 1-30 |
| HTTP request timeout | 15 seconds; 1-15. Upgrades change the former default of 8 to 15 while preserving other saved values. |
| Concurrent requests | 3; 1-8 |
| Download chunks | 100; 1-1000; server determines chunk size |
| Upload payload | 1024 KiB; 1-16384 |
| IP family | Automatic, IPv4 or IPv6 |
| Source binding | Optional local unicast IP matching the selected family |
| Latency method | HTTP by default; optional ICMP attempt with HTTP fallback |
| HTTP/2 | Optional; multiplexing changes connection/concurrency semantics |
| Upload memory | Optional reduced preallocation; server must accept chunked uploads |
| Private CA | Optional PEM bundle, with certificate verification retained |
| Display units | Mbps, MB/s or MiB/s; stored measurements remain Mbps |
| History retention | Optional days (1-3650) and/or records (1-100000); 0 disables each limit |
| Scheduled measurements | Disabled by default; hourly, daily, weekdays or weekly; selected mode and server IDs |

Source binding does not override routing or multi-WAN policy. FreeBSD interface
binding is not supported by this engine; Linux-only firewall marks are not
exposed. Enabling ICMP does not prove ICMP was used. Packet loss and loaded
latency are not reported. TLS metadata describes the server probe, not every
transfer connection. Larger payloads, concurrency and duration use more memory
and transfer more data; tests can saturate a production link.

Each engine invocation has a 100-240 second deadline, derived from
directions, duration, server count and request timeout. Comparisons invoke
one server at a time; each additional server increases runtime and traffic.
GUI tests use native configd detachment and poll an atomic progress snapshot,
so they continue after leaving the page without holding a long HTTP request.
The status action detects interrupted workers when their lock is no longer
held. Version checks are bounded at 10 seconds.
GUI, cron, terminal-wrapper runs and history clearing share an exclusive lock,
including runs using an alternate history file. A status query reports `busy`
while another history's test, an initializing test, or a history operation
holds the lock.
An unreachable server is recorded as a failure; an explicit comparison
continues with its remaining requested servers without choosing replacements.

### Official Rust CLI coverage

The pinned client's `src/cli.rs` and real native engine are the contract.
The plugin deliberately normalizes output and constrains resource use rather
than forwarding arbitrary arguments through a root command.

| Upstream switches | Plugin integration |
| --- | --- |
| `--help`, `--version` | Wrapper help, setup help, engine status; direct client help lists every native flag |
| `--server` (repeatable), server `-1`, `--exclude` | GUI IDs/all-server comparison/exclusions, repeatable wrapper IDs; sequential measurements share the lock and history |
| `--no-download`, `--no-upload` | Full, download-only, upload-only and latency/jitter modes |
| `--duration`, `--timeout`, `--concurrent`, `--chunks`, `--upload-size` | Saved defaults, per-run GUI/API overrides and wrapper switches; bounded ranges above |
| `--ipv4` / `-4`, `--ipv6` / `-6`, `--source` | IP-family/source controls; selected settings are retained for filtering |
| `--no-icmp` | Default HTTP latency; optional ICMP attempt, with fallback semantics stated |
| `--http2`, `--no-pre-allocate` | Advanced saved/per-run controls, including CLI overrides to disable saved options |
| `--secure`, `--ca-cert` | HTTPS always enforced; optional administrator-managed CA bundle |
| `--local-json` | Validated saved JSON or local file, passed to the engine on stdin; no temporary server-list file |
| `--json`, `--json-stream` | Validated reports and live GUI progress; terminal streaming remains available directly from the native engine |
| `--bytes`, `--mebibytes` | Equivalent GUI display conversions; the upstream JSON/CSV values themselves are always Mbps |
| `--simple`, `--csv`, `--csv-delimiter`, `--csv-header` | Wrapper text/JSON/CSV, stable nine-column export and detailed JSONL; exact upstream formatting/delimiters/header-only output remain direct-client features |
| `--list` | Configured-server picker and wrapper `list`; uses official public discovery when enabled and no local list is configured |
| `--distance` | Direct-client presentation only; plugin does not collect ISP/geolocation distance |
| `--debug` / hidden `--verbose` alias | Direct-client diagnostics only; not forwarded as privileged arbitrary GUI arguments |
| `--server-json` | Remote list fetching intentionally excluded; authorize and save local server definitions instead |
| `--interface`, `--fwmark` | Not exposed: FreeBSD interface binding is unsupported; firewall marks are Linux-specific |
| `--insecure`, `--skip-cert-verify` | Intentionally excluded; neither plaintext tests nor disabled certificate verification is offered |
| `--share`, `--telemetry-json`, `--telemetry-level`, `--telemetry-server`, `--telemetry-path`, `--telemetry-share`, `--telemetry-extra` | Intentionally excluded: no plugin result sharing or telemetry uploads |

Zero/infinite timeouts and unbounded concurrency are not exposed. The engine
retains its upstream flags for independently authorized direct terminal use;
that does not make platform-inapplicable flags work on FreeBSD.

### HTTP administration and HTTPS measurements

The OPNsense GUI can use **HTTP or HTTPS independently** of measurement
endpoints. API requests are same-origin relative URLs and inherit native
session/CSRF handling. There is no need to change the GUI scheme for this plugin.
HTTP administration itself does not encrypt browser traffic.

Measurement endpoints must use HTTPS with verified certificates. For a private
server, install an administrator-managed PEM CA bundle at
`/usr/local/etc/speedtest-community/ca.pem` and enable **private CA**. This replaces
the engine's trust store for that run. Use a separate issuing CA and server leaf
certificate. The GUI certificate and measurement-server certificate are
different concerns; verification cannot be disabled through the plugin.

## Terminal and scheduling

Run from an authorized firewall shell:

```sh
opn-librespeed --help
opn-librespeed list
opn-librespeed run --server 42 --duration 15 --family ipv4
opn-librespeed run --mode latency --format json
opn-librespeed run --mode download --format csv
opn-librespeed run --no-icmp --no-http2 --pre-allocate --system-ca
opn-librespeed run --server 42 --server 84
opn-librespeed run --all-servers
opn-librespeed run --exclude 84
opn-librespeed history --days 30 --format json
opn-librespeed status --format json
opn-librespeed stat
opn-librespeed recent
opn-librespeed log
```

`opn-librespeed` shares the GUI lock and history, defaults to readable text,
supports JSON/CSV output and returns nonzero on errors. `--history` selects an
alternate CSV file without changing the shared lock; `--config` selects an
alternate server list. Runs require permission to use the plugin's shared lock,
normally through a root shell. `--server` and `--all-servers` are mutually
exclusive. Existing `configctl speedtest run [serverid]` cron jobs remain
supported, including automatic selection when the ID is omitted. Review old
server IDs before reenabling jobs; IDs must belong to your configured
LibreSpeed servers.

For one daily run, open **Schedule**, enable the schedule, choose **Daily**,
set the firewall-local hour/minute, and select server `0` (lowest latency),
`-1` (all), or configured IDs such as `42,84`. Save and apply. This updates
exactly one native cron entry with origin `Speedtest` and command
`speedtest scheduled`; saving is not a measurement.
The scheduled action reads the saved mode/server selection and current
measurement defaults at execution time. All scheduled modes enter detailed
history, and scheduled failures also go to syslog.

Repeated saves do not create duplicates. Existing user-created jobs are not
silently edited or converted: an enabled speedtest job blocks enabling the
built-in schedule until it is disabled in native cron. Use native cron for
additional schedules. A failed cron apply is reported as **saved but not
applied** with a retry action. Cron uses the firewall timezone and follows
normal daylight-saving skip/repeat behavior. Source binding is not gateway
selection, and no routes, MSS values, traffic-shaper pipes or firewall rules
are modified.

The bundled `librespeed-cli --help` exposes all upstream options, including
multi-server tests, streaming JSON, CSV and explicit sharing. Direct engine
runs do not enter plugin history or share its lock: do not run them concurrently
with GUI/cron tests. Platform-specific flags remain platform-specific.
`--csv-header` prints only a header; request measurement rows separately.

## Users and groups

Assign native privileges under **System > Access > Users or Groups**:

| Privilege | Access |
| --- | --- |
| LibreSpeed: View results | Page, charts/history/status, dashboard data and exports |
| LibreSpeed: Run measurements | Start full tests and diagnostics |
| LibreSpeed: Configure settings | Read/save server configuration and defaults |
| LibreSpeed: Manage schedule | Manage the plugin's fixed native cron job, not arbitrary cron commands |
| LibreSpeed: Clear history | Delete stored measurements |

Grant View results alongside additional privileges. The original
`page-reporting-speedtest` privilege now grants viewing only: limited accounts
need newly assigned run/configure/schedule/clear privileges after upgrading.
Configuration-read-only users cannot run measurements or mutate settings/history.
The built-in schedule uses its own privilege; advanced native cron editing
still requires the separate **System Settings Cron** privilege. Terminal
access follows operating-system permissions, not GUI ACLs.

## History and upgrades

Full tests retain the nine-column `speedtest.csv` layout and label new server
names with LibreSpeed. Legacy statistics/widgets continue to use full
successful tests, including existing CSV measurements. New JSONL metadata in
`speedtest.csv.jsonl` additionally records every mode and operational failure,
jitter, byte counters, probe TLS, engine version, trigger and measurement
options. New public client IP/ISP information is not retained.
`speedtest.csv.state.json` is an atomic current/latest-run progress snapshot,
not another daemon or history database.

The history API merges legacy CSV and detailed records without counting the
CSV mirror of a modern full test twice. The GUI separates legacy and Rust
measurements, filters by period/server/mode/outcome/trigger/IP-family setting/
source binding, shows average/min/max for measured values only, and paginates
50 rows at a time. Up to 200 pages may be browsed per filter; narrow a filter
or export for larger sets. Throughput and latency/jitter plots use UTC-day
averages, coarsened to at most 500 buckets for long histories. Tables display
absolute timestamps in the **browser's local timezone**; schedule times use
the separately identified **firewall timezone**. Automatic IP family is a
setting, not a claim about the actual socket family; the engine does not
report that separately.

Retention is **off by default**, preserving existing measurements. An explicit
days/count limit applies after a measurement, pruning both files; whichever
limit is stricter wins. Retention may consolidate retained legacy rows into
JSONL while preserving their original CSV columns. Export CSV **and** JSONL
before enabling shorter retention or clearing data. Exports stream all
retained dates independently of UI filters; JSONL includes modern details
and any consolidated legacy rows, while CSV preserves all retained full
tests. Neither file needs world-write or executable permissions. Legacy links
remain in exports but are not opened by the UI. Corrupt detailed history is
reported explicitly, never silently replaced.

Read APIs: `/api/speedtest/service/{history,status,showstat,stat,showrecent,showlog}`.
The `stat` alias repairs the originally documented stats route.
`history` accepts POST filters `days`, `page`, `limit` (1-200), `server`,
`mode`, `status`, `origin`, `family`, `source`, `provider`.
Start using POST `/api/speedtest/service/start/<ids>/<mode>` and follow its
`run_id` through `status`; the legacy synchronous `run` route remains usable.

### Uninstall

Removing the package deletes its default CSV, detailed JSONL and progress snapshot, saved
`OPNsense/speedtest` settings and OPNsense cron jobs using the `speedtest`
configd action; export history first if it should be retained. The uninstaller
waits up to 250 seconds for an active measurement's history lock and reports
any cleanup or cron-apply failure. An in-flight worker stops updating data when
its installed script has been removed. Other cron jobs are untouched. Normal
package upgrades and this repository's `make upgrade` preserve those settings
and history. An explicit package deletion, including a variant switch that
first removes the old package, is treated as an uninstall; export history
before doing so. If cleanup reports an error, inspect the package output and
remove any remaining data after tests have stopped; if the cron apply failed,
run `configctl cron restart` after resolving the error.

Administrator-created `/usr/local/etc/speedtest-community/` server lists and
CA files, alternate `--history` files, configuration backups and user/group
privilege assignments are not deleted. Review and remove them separately if
they are no longer needed. Legacy standalone speed-test packages installed by
older versions are also left alone because they may be used independently.
Cleanup is skipped for an alternate package root; it must be performed within
that installation instead.

The previous packaging framework could declare a package in conflict with
itself, causing a misconfigured firmware status. `Mk/plugins.mk` now omits that
self-conflict while preserving real stable/development conflicts. Source
changes alone do not repair an installed package: build/install **0.14 or newer** for
the matching OPNsense repository, FreeBSD ABI and architecture, then refresh
firmware status. This work does not automatically install or publish it.

## Building the bundled engine

Build on a separate, compatible Rust builder, not on the production firewall.
The recipe requires Rust/Cargo, HTTPS curl, tar, a SHA-256 tool and Python 3
standard library for license collection. It verifies the immutable
`librespeed-cli 1.2.1` source archive SHA-256:

```text
159e3fbdf7250cbc0466f67d45543d4df49413b5b0f520de80243b59ac282836
```

`contrib/build.sh` uses `cargo build --locked --release` with default Rustls
features, verifies the executable version and collects dependency licenses.
The standard build is native: run it on a FreeBSD amd64 builder compatible
with the intended OPNsense ABI. It explicitly selects the compiler's host
target and an engine-local Cargo target directory, so ambient `CARGO_TARGET_DIR`
or cross-target settings cannot make it package a stale or wrong-platform binary.
Relative engine paths are resolved before invoking Cargo.

```sh
cd net-mgmt/speedtest-community
sh contrib/build.sh contrib/.build/engine
LIBRESPEED_TEST_BINARY="$PWD/contrib/.build/engine/bin/librespeed-cli" \
  python3 -B -m unittest discover -s tests -v
make ENGINE_ROOT="$PWD/contrib/.build/engine" package
```

Use the same engine directory for building, testing and packaging. Archive the
compiler version and package manifest with each qualification; the source pin
and lockfile do not by themselves guarantee bit-for-bit reproducible binaries.
Use the repository's normal FreeBSD package builder. For a prebuilt target
engine, supply `ENGINE_ROOT` containing `bin/librespeed-cli`, the verified
`librespeed-cli-1.2.1.crate` and generated `THIRD-PARTY-NOTICES`. The target
package builder checks that the executable runs; cross-built binaries need
matching target headers/libraries and architecture. Cargo remains a build-time
requirement only. The Rust engine still has internal Cargo dependencies;
"no extra runtime packages" does not mean zero dependencies.

The package ships the executable, LGPL-3.0 engine license, pinned engine source
and lockfile archive, and third-party license notices under
`/usr/local/share/speedtest-community/`. Existing integration files retain
their BSD notices.

Regression commands:

```sh
python3 -B -m unittest discover -s tests
LIBRESPEED_TEST_BINARY=/path/to/librespeed-cli python3 -B -m unittest discover -s tests
php tests/test_native.php
```

The optional live test uses a disposable local HTTPS fixture and private CA,
not a public test server. Native PHP tests require OPNsense and check models,
API contracts, privilege patterns and Volt compilation without saving live
configuration or modifying the ACL cache. On FreeBSD, uninstall tests use
temporary configuration and stubbed native hooks; their isolated `pkg -r`
lifecycle test requires root and never runs the real OPNsense package hooks.
For the dependency-free JavaScript regressions on a builder with Node.js,
render the native template using `php tests/test_native.php /tmp/compiled.php
/tmp/rendered.html`, then run `node tests/test_ui.js /tmp/rendered.html`.
This checks asynchronous settings/history safeguards, not browser layout.
For the same script behavior gate without native rendering:
`node tests/test_ui.js src/opnsense/mvc/app/views/OPNsense/Speedtest/index.volt`.
Native checks additionally generate/validate a real cron model without writing
configuration; dynamic action-field cache access is replaced with an isolated
test field. Schedule-controller tests use an in-memory configuration transaction,
not a real `Config::save`.

Adapter coverage includes all four measurement modes, advanced flags and
overrides, certificate failure, real NDJSON progress/result handling,
server comparisons and partial failures, exclusions, legacy merging, history
filters/pagination/statistics, opt-in retention, interrupted runs and cleanup.
The native engine's own tests remain responsible for its direct-client-only
formatting, telemetry and platform-specific internals; they are not falsely
advertised as plugin capabilities.

The GitHub Actions **LibreSpeed Rust release gate** builds the pinned engine on
Ubuntu and in a FreeBSD 15.1 amd64 VM, and runs the adapter and local
verified-HTTPS integration tests on each. The FreeBSD job also runs the
isolated uninstall tests with PHP; the package lifecycle test requires root.
CI tools installed in the disposable VM are not plugin runtime dependencies.
The workflow can be started manually with `workflow_dispatch` once it is on
the default branch, and also runs on relevant pushes and pull requests. A green Linux gate
does not replace native OPNsense framework and target FreeBSD package checks.
The FreeBSD VM job also does not exercise other architectures or OPNsense's
native MVC/ACL implementation.

### Upstream contribution policy

The plugin stays on the verified official `1.2.1` crate until an official
release is deliberately qualified and its pin updated. Native FreeBSD coverage
is proposed in
[librespeed/speedtest-cli-rust#49](https://github.com/librespeed/speedtest-cli-rust/pull/49),
linked to
[librespeed/speedtest-cli-rust#48](https://github.com/librespeed/speedtest-cli-rust/issues/48).
No source portability workaround is assumed necessary merely because official
FreeBSD binary downloads are absent. Existing unrelated upstream revision and
timestamp/probe changes are left to their own pull requests.

## Project and support

- [Blackout plugin issues](https://github.com/blackoutsecure/opn-repo/issues)
- [Rust client documentation and issues](https://github.com/librespeed/speedtest-cli-rust)
- [LibreSpeed server](https://github.com/librespeed/speedtest)
- [Optional Rust server backend](https://github.com/librespeed/speedtest-rust)
- [LibreSpeed project](https://librespeed.org/)

## Ecosystem review and issue disposition

Research covered all **39** matches returned by the open/closed
`repo:mimugmail/opn-repo speedtest in:title,body` search, relevant PR diffs,
cron/multi-WAN discussion comments, focused repository searches and the
OPNsense topic results. This is a bounded snapshot, not a claim that every
GitHub repository or unrelated network-driver regression has been fixed.

| Reports/proposals | Blackout disposition |
| --- | --- |
| [mimugmail/opn-repo#264](https://github.com/mimugmail/opn-repo/issues/264), [mimugmail/opn-repo#283](https://github.com/mimugmail/opn-repo/issues/283), [mimugmail/opn-repo#318](https://github.com/mimugmail/opn-repo/pull/318) | Package self-conflict removed; modern result parsing never depends on a share URL |
| [mimugmail/opn-repo#313](https://github.com/mimugmail/opn-repo/issues/313), [mimugmail/opn-repo#160](https://github.com/mimugmail/opn-repo/issues/160), [mimugmail/opn-repo#109](https://github.com/mimugmail/opn-repo/issues/109), [mimugmail/opn-repo#298](https://github.com/mimugmail/opn-repo/pull/298) | No advanced-mode log toggle, old regex text parser or mandatory sharing; explicit history/error handling |
| [mimugmail/opn-repo#136](https://github.com/mimugmail/opn-repo/issues/136), [mimugmail/opn-repo#152](https://github.com/mimugmail/opn-repo/pull/152) | Stats alias plus structured history/status API, with distinct view/run/configure/schedule/clear ACLs |
| [mimugmail/opn-repo#216](https://github.com/mimugmail/opn-repo/issues/216), [mimugmail/opn-repo#179](https://github.com/mimugmail/opn-repo/issues/179) | Native schedule UI, fixed explicit Python invocation, validated configured IDs, lock/error/history handling; no world-writable CSV workaround |
| [mimugmail/opn-repo#278](https://github.com/mimugmail/opn-repo/issues/278) | Discussion identified server performance at a specific hour, not a cron bug. Pin/compare servers and inspect recorded options/time; no fabricated correction of valid low measurements |
| [mimugmail/opn-repo#237](https://github.com/mimugmail/opn-repo/issues/237), [mimugmail/opn-repo#119](https://github.com/mimugmail/opn-repo/pull/119) | Timezone-aware storage, absolute ordering across DST, explicit browser/firewall timezone labels |
| [mimugmail/opn-repo#307](https://github.com/mimugmail/opn-repo/issues/307), [mimugmail/opn-repo#243](https://github.com/mimugmail/opn-repo/issues/243), [mimugmail/opn-repo#135](https://github.com/mimugmail/opn-repo/issues/135), [mimugmail/opn-repo#258](https://github.com/mimugmail/opn-repo/issues/258) | Explicit authorized server list, manual IDs, comparison/exclusion controls, HTTPS; no stale Ookla geolocation/discovery dependency |
| [mimugmail/opn-repo#151](https://github.com/mimugmail/opn-repo/issues/151), [mimugmail/opn-repo#247](https://github.com/mimugmail/opn-repo/issues/247) | Source binding and IP-family controls are recorded/filterable. **Not full multi-WAN routing**: no unsafe claim that source binding or a Linux interface flag chooses a FreeBSD gateway |
| [mimugmail/opn-repo#185](https://github.com/mimugmail/opn-repo/issues/185), [mimugmail/opn-repo#225](https://github.com/mimugmail/opn-repo/issues/225), [mimugmail/opn-repo#288](https://github.com/mimugmail/opn-repo/issues/288) | Concurrent native Rust measurement engine instead of obsolete Python measurement logic; bounded tunables and like-for-like trends. Does not promise to overcome CPU/server/network bottlenecks or match Ookla |
| [mimugmail/opn-repo#231](https://github.com/mimugmail/opn-repo/issues/231), [mimugmail/opn-repo#230](https://github.com/mimugmail/opn-repo/pull/230), [mimugmail/opn-repo#30](https://github.com/mimugmail/opn-repo/pull/30) | Native 24.7+ dashboard contract retained, with optional links and full-test compatibility |
| [mimugmail/opn-repo#305](https://github.com/mimugmail/opn-repo/issues/305), [mimugmail/opn-repo#150](https://github.com/mimugmail/opn-repo/issues/150), [mimugmail/opn-repo#124](https://github.com/mimugmail/opn-repo/pull/124), [mimugmail/opn-repo#169](https://github.com/mimugmail/opn-repo/pull/169), [mimugmail/opn-repo#82](https://github.com/mimugmail/opn-repo/pull/82), [mimugmail/opn-repo#68](https://github.com/mimugmail/opn-repo/pull/68), [mimugmail/opn-repo#67](https://github.com/mimugmail/opn-repo/issues/67) | Native ABI-matched bundled engine replaces brittle installer scraping and forced incompatible packages; actual repository publication is still a release/distribution step |
| [mimugmail/opn-repo#177](https://github.com/mimugmail/opn-repo/issues/177) | Relative API URLs and native MVC/ACL checks replace obsolete page navigation paths |
| [mimugmail/opn-repo#319](https://github.com/mimugmail/opn-repo/pull/319) | Scheduling, sequential comparison, error visibility and privilege separation inform this implementation. Automated shaper/MSS/routing writes are intentionally **not** imported; those can change production traffic and require separate design/authorization |
| [mimugmail/opn-repo#251](https://github.com/mimugmail/opn-repo/issues/251), [mimugmail/opn-repo#178](https://github.com/mimugmail/opn-repo/issues/178), [mimugmail/opn-repo#26](https://github.com/mimugmail/opn-repo/issues/26), [mimugmail/opn-repo#25](https://github.com/mimugmail/opn-repo/pull/25) | Historical packaging/repository/original-plugin context; no separate repository split or unrelated plugin changes |

Related implementations reviewed for documented capabilities:
[mihakralj/opnsense-speedtest](https://github.com/mihakralj/opnsense-speedtest),
[SurfHost/opnsense-plugin-speedtest](https://github.com/SurfHost/opnsense-plugin-speedtest),
[geraldFS/os-speedtest-librespeed](https://github.com/geraldFS/os-speedtest-librespeed),
[Chanclatoen/opnsense-uplink-speedtest](https://github.com/Chanclatoen/opnsense-uplink-speedtest),
[connorlorente/opnsense-speedtest](https://github.com/connorlorente/opnsense-speedtest),
[mcduffman/patrium-speedtest](https://github.com/mcduffman/patrium-speedtest),
[icon-oclast/opnsense_speedtest_rrd](https://github.com/icon-oclast/opnsense_speedtest_rrd),
[dolphag/OPNsense-mirror-speedtest](https://github.com/dolphag/OPNsense-mirror-speedtest)
(package-mirror benchmarking, not WAN measurement), and the topic-listed
[markchristianlacap/nuxt-net-monitoring](https://github.com/markchristianlacap/nuxt-net-monitoring).
Useful patterns adopted independently are on-box history, source/family
provenance, asynchronous runs, native schedules, retention and comparable
charts. Their extra providers, installers, dependencies and claims of interface
selection are not copied.

Core issues such as
[opnsense/core#4322](https://github.com/opnsense/core/issues/4322)
(firewall-originated multi-WAN routing) and
[opnsense/core#10241](https://github.com/opnsense/core/issues/10241)
(native cron template) remain core concerns. The plugin reuses native cron
rather than shipping a conflicting crontab writer. Network-driver, PPPoE,
offload and TCP-stack regressions found by broad searches are not silently
"fixed" by changing firewall tunables.
