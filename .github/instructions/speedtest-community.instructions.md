---
applyTo: "net-mgmt/speedtest-community/**"
---

# LibreSpeed plugin

- Keep the plugin LibreSpeed-only. Do not add Ookla clients, telemetry, runtime
  downloads, daemons, or extra runtime packages. Public server discovery may
  use only the official HTTPS LibreSpeed.org registry, must be user-disableable,
  must validate every server entry, and must explain that tests expose the
  firewall's public IP to selected servers.
- Use the pinned, checksum-verified Rust engine and its locked dependencies.
  Update the source archive, checksum, bundled notices and tests together when
  changing the engine version.
- Keep the official release as runtime upstream. Use the Blackout Secure fork
  for focused upstream contributions, not an unreviewed permanent engine fork.
  Build, test and package the same native FreeBSD engine directory.
- Use native OPNsense models, ACLs, configd and existing Python for integration;
  preserve the cron action and nine-column historical CSV format.
- Keep detailed JSONL records complementary to the legacy full-test CSV.
  Preserve old data unless retention is explicitly enabled, bound history
  responses/chart buckets, and never count both representations of a run.
- Run comparisons sequentially under the existing lock. Use native configd
  detachment and atomic status snapshots for GUI progress, not a new daemon.
- Keep the optional schedule in native cron with the fixed plugin command
  and its own privilege. Preserve manual cron jobs and reject duplicates;
  report saved-but-unapplied configuration explicitly.
- Keep GUI API requests same-origin for HTTP or HTTPS administration. Require
  verified HTTPS for measurement endpoints; never disable certificate checks.
- Keep settings validation and run/clear permissions enforced in the backend,
  not only in the UI. Do not save live firewall configuration during tests.
- On uninstall remove only plugin-owned history, saved model data, and its
  configd cron jobs; preserve administrator-managed files and backup history.
  Never purge during package or development upgrades, and test uninstall
  hooks with isolated configuration and package databases.
- Run the Rust release gate in `.github/workflows/speedtest-release-gate.yml`
  and the native OPNsense checks documented in the plugin README. A Linux CI
  pass does not replace target FreeBSD package and framework validation; the
  generic FreeBSD VM gate does not replace native OPNsense model/API/ACL checks.
