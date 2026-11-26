#!/usr/local/bin/python3
# -*- coding: utf-8 -*-
#
# Copyright (C) 2021 M. Kralj
# Copyright (C) 2026
# SPDX-License-Identifier: BSD-2-Clause

import json
import sys
import traceback

from speedtest_core.config import load_settings
from speedtest_core.errors import SpeedtestError
from speedtest_core.history import append_result, clear_history, read_log, recent_result, statistics_result
from speedtest_core.orchestrator import SpeedtestOrchestrator
from speedtest_core.progress import ProgressReporter, read_progress


def json_output(payload) -> None:
    print(json.dumps(payload, separators=(",", ":")))


def run(argv):
    command = argv[1].lower() if len(argv) > 1 else "run"
    settings = load_settings()

    if command in ("l", "log"):
        limit = int(argv[2]) if len(argv) > 2 and argv[2].isdigit() else 50
        return read_log(min(max(limit, 1), 5000))
    if command == "results":
        limit = int(argv[2]) if len(argv) > 2 and argv[2].isdigit() else 1000
        return read_log(min(max(limit, 1), 10000))
    if command in ("r", "recent"):
        return recent_result()
    if command in ("s", "stat"):
        return statistics_result()
    if command == "clear":
        clear_history()
        return {"status": "ok"}
    if command == "progress":
        return read_progress()

    orchestrator = SpeedtestOrchestrator(settings)
    if command in ("v", "version"):
        return orchestrator.legacy_ookla_version()
    if command == "providers":
        return orchestrator.provider_status()
    if command in ("t", "list"):
        return orchestrator.list_servers(argv[2] if len(argv) > 2 else "ookla")
    if command == "discover":
        return orchestrator.discover(argv[2] if len(argv) > 2 else "all")

    if len(argv) == 1:
        provider, server = "ookla", "0"
    elif command == "run" and len(argv) == 2:
        provider, server = "auto", "auto"
    elif command == "run":
        provider = argv[2] if len(argv) > 2 else "auto"
        server = argv[3] if len(argv) > 3 else "auto"
    elif command.isdigit() or command == "0":
        provider, server = "ookla", command
    else:
        raise SpeedtestError(f"Unknown speedtest command: {command}")
    progress = ProgressReporter()
    orchestrator = SpeedtestOrchestrator(settings, progress=progress)
    try:
        result = orchestrator.run(provider, server)
        append_result(result)
        return result
    except Exception as exc:
        progress.fail(str(exc))
        raise


def main() -> None:
    try:
        json_output(run(sys.argv))
    except SpeedtestError as exc:
        json_output({"error": str(exc)})
    except Exception as exc:
        traceback.print_exc(file=sys.stderr)
        json_output({"error": f"Speedtest failed: {type(exc).__name__}: {exc}"})


if __name__ == "__main__":
    main()
