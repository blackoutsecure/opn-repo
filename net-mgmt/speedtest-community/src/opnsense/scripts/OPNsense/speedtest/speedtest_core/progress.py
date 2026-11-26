# Copyright (C) 2026
# SPDX-License-Identifier: BSD-2-Clause

import json
import os
import threading
import time
from typing import Any, Dict, Optional


DEFAULT_PROGRESS_PATH = "/var/run/opnsense-speedtest-progress.json"


def progress_path() -> str:
    return os.environ.get("OPNSENSE_SPEEDTEST_PROGRESS", DEFAULT_PROGRESS_PATH)


def read_progress() -> Dict[str, Any]:
    path = progress_path()
    if not os.path.isfile(path):
        return {"active": False, "phase": "idle", "message": "No measurement is running"}
    try:
        with open(path, "r", encoding="utf-8") as stream:
            payload = json.load(stream)
    except (OSError, ValueError, TypeError):
        return {"active": False, "phase": "unavailable", "message": "Progress is unavailable"}
    if payload.get("active") and time.time() - float(payload.get("updatedAt", 0)) > 600:
        payload["active"] = False
        payload["phase"] = "timed-out"
        payload["message"] = "The measurement stopped reporting progress"
    return payload


class ProgressReporter:
    def __init__(self, path: Optional[str] = None):
        self.path = path or progress_path()
        self.lock = threading.Lock()
        self.started = 0.0
        self.last_write = 0.0
        self.state: Dict[str, Any] = {
            "active": False,
            "phase": "idle",
            "message": "No measurement is running",
            "percent": 0,
            "provider": "",
            "target": "",
            "samples": [],
        }

    def _write(self, force: bool = False) -> None:
        now = time.time()
        if not force and now - self.last_write < 0.2:
            return
        payload = dict(self.state)
        payload["updatedAt"] = now
        if self.started:
            payload["elapsed"] = round(now - self.started, 2)
        directory = os.path.dirname(self.path)
        if directory:
            os.makedirs(directory, exist_ok=True)
        temporary = f"{self.path}.{os.getpid()}.tmp"
        with open(temporary, "w", encoding="utf-8") as stream:
            json.dump(payload, stream, separators=(",", ":"))
        os.chmod(temporary, 0o644)
        os.replace(temporary, self.path)
        self.last_write = now

    def start(self, provider: str, target: str) -> None:
        with self.lock:
            self.started = time.time()
            self.state = {
                "active": True,
                "phase": "preparing",
                "message": "Preparing measurement",
                "percent": 2,
                "provider": provider,
                "target": target,
                "startedAt": self.started,
                "samples": [],
            }
            self._write(force=True)

    def update(
        self,
        phase: str,
        message: str,
        percent: Optional[float] = None,
        **details,
    ) -> None:
        with self.lock:
            self.state["phase"] = phase
            self.state["message"] = message
            if percent is not None:
                self.state["percent"] = max(0, min(100, round(percent, 1)))
            self.state.update(details)
            self._write(force=phase != self.state.get("previousPhase"))
            self.state["previousPhase"] = phase

    def sample(self, direction: str, mbps: float, elapsed: float, percent: float) -> None:
        absolute_time = max(0.0, time.time() - self.started)
        sample = {
            "time": round(absolute_time, 3),
            "phaseTime": round(elapsed, 3),
            "direction": direction,
            "mbps": round(max(0.0, mbps), 3),
            "percent": max(0, min(100, round(percent, 1))),
        }
        with self.lock:
            samples = self.state.setdefault("samples", [])
            if not samples or absolute_time - float(samples[-1].get("time", 0)) >= 0.2:
                samples.append(sample)
                if len(samples) > 180:
                    del samples[:-180]
            self._write()

    def complete(self, result: Dict[str, Any]) -> None:
        with self.lock:
            samples = self.state.setdefault("samples", [])
            if not samples:
                samples.append(
                    {
                        "time": round(time.time() - self.started, 3),
                        "direction": "result",
                        "mbps": max(
                            float(result.get("download", 0)),
                            float(result.get("upload", 0)),
                        ),
                        "percent": 100,
                        "summary": True,
                        "download": result.get("download"),
                        "upload": result.get("upload"),
                        "latency": result.get("latency"),
                    }
                )
            result["samples"] = list(samples)
            self.state.update(
                {
                    "active": False,
                    "phase": "complete",
                    "message": "Measurement complete",
                    "percent": 100,
                    "finishedAt": time.time(),
                    "result": result,
                }
            )
            self._write(force=True)

    def fail(self, message: str) -> None:
        with self.lock:
            self.state.update(
                {
                    "active": False,
                    "phase": "error",
                    "message": message,
                    "finishedAt": time.time(),
                    "error": message,
                }
            )
            self._write(force=True)

    def samples(self):
        with self.lock:
            return list(self.state.get("samples", []))
