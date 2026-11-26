# Copyright (C) 2026
# SPDX-License-Identifier: BSD-2-Clause

import csv
import fcntl
import json
import os
import statistics
from datetime import datetime, timezone
from typing import Dict, List


DEFAULT_HISTORY_PATH = "/usr/local/opnsense/scripts/OPNsense/speedtest/speedtest.csv"
LEGACY_FIELDS = [
    "Timestamp",
    "ClientIp",
    "ServerId",
    "ServerName",
    "Country",
    "DlSpeed",
    "UlSpeed",
    "Latency",
    "Link",
]
FIELDS = LEGACY_FIELDS + [
    "Provider",
    "Jitter",
    "SelectionMethod",
    "Engine",
    "DetailsJson",
    "PacketLoss",
    "PacketLossMethod",
]


def history_path() -> str:
    return os.environ.get("OPNSENSE_SPEEDTEST_HISTORY", DEFAULT_HISTORY_PATH)


def _read_unlocked() -> List[List[str]]:
    path = history_path()
    if not os.path.isfile(path):
        return []
    with open(path, "r", encoding="utf-8", newline="") as stream:
        fcntl.flock(stream.fileno(), fcntl.LOCK_SH)
        reader = csv.reader(stream)
        rows = list(reader)
        fcntl.flock(stream.fileno(), fcntl.LOCK_UN)
    return rows


def ensure_history() -> None:
    path = history_path()
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, exist_ok=True)
    with open(path, "a+", encoding="utf-8", newline="") as stream:
        fcntl.flock(stream.fileno(), fcntl.LOCK_EX)
        stream.seek(0)
        rows = list(csv.reader(stream))
        if not rows:
            csv.writer(stream).writerow(FIELDS)
        elif rows[0] != FIELDS:
            if FIELDS[: len(rows[0])] == rows[0]:
                stream.seek(0)
                stream.truncate()
                writer = csv.writer(stream)
                writer.writerow(FIELDS)
                for row in rows[1:]:
                    writer.writerow((row + [""] * len(FIELDS))[: len(FIELDS)])
            else:
                raise ValueError("Unsupported speedtest CSV header")
        fcntl.flock(stream.fileno(), fcntl.LOCK_UN)


def append_result(result: Dict) -> None:
    ensure_history()
    timestamp = result["timestamp"]
    parsed = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    row = [
        parsed.timestamp(),
        result.get("clientip", ""),
        result.get("serverid", ""),
        result.get("servername", ""),
        result.get("country", ""),
        result.get("download", 0),
        result.get("upload", 0),
        result.get("latency", 0),
        result.get("link", ""),
        result.get("provider", ""),
        result.get("jitter", 0),
        result.get("selection", {}).get("method", "manual"),
        result.get("engine", ""),
        json.dumps(
            {
                "client": result.get("client", {}),
                "server": result.get("serverDetails", {}),
                "network": result.get("network", {}),
                "selection": result.get("selection", {}),
                "samples": result.get("samples", []),
                "warnings": result.get("warnings", []),
            },
            separators=(",", ":"),
            sort_keys=True,
        ),
        "" if result.get("packetLoss") is None else result.get("packetLoss"),
        result.get("packetLossMethod", ""),
    ]
    with open(history_path(), "a", encoding="utf-8", newline="") as stream:
        fcntl.flock(stream.fileno(), fcntl.LOCK_EX)
        csv.writer(stream).writerow(row)
        fcntl.flock(stream.fileno(), fcntl.LOCK_UN)


def read_log(limit: int = 50) -> List[List]:
    ensure_history()
    rows = _read_unlocked()
    normalized = []
    for row in rows[1:]:
        padded = (row + [""] * len(FIELDS))[: len(FIELDS)]
        try:
            padded[0] = datetime.fromtimestamp(float(padded[0]), timezone.utc).isoformat()
        except (TypeError, ValueError, OverflowError):
            continue
        normalized.append(padded)
    normalized.sort(key=lambda item: item[0], reverse=True)
    return normalized[:limit]


def recent_result() -> Dict:
    rows = read_log(1)
    if not rows:
        return {
            "date": "",
            "provider": "",
            "server": "",
            "download": "",
            "upload": "",
            "latency": "",
            "packetLoss": None,
            "packetLossMethod": "",
            "url": "",
            "error": "No speedtest results yet",
        }
    row = rows[0]
    try:
        details = json.loads(row[13]) if row[13] else {}
    except (TypeError, ValueError, json.JSONDecodeError):
        details = {}
    packet_loss = None
    if row[14] != "":
        try:
            packet_loss = float(row[14])
        except (TypeError, ValueError):
            pass
    return {
        "date": row[0],
        "provider": row[9],
        "server": f"{row[2]} {row[3]}".strip(),
        "download": row[5],
        "upload": row[6],
        "latency": row[7],
        "packetLoss": packet_loss,
        "packetLossMethod": row[15],
        "url": row[8],
        "client": details.get("client", {}),
        "network": details.get("network", {}),
    }


def statistics_result() -> Dict:
    ensure_history()
    rows = read_log(limit=1_000_000)
    timestamps = []
    downloads = []
    uploads = []
    latencies = []
    packet_losses = []
    for row in rows:
        try:
            timestamps.append(datetime.fromisoformat(row[0]).timestamp())
            downloads.append(float(row[5]))
            uploads.append(float(row[6]))
            latencies.append(float(row[7]))
            if row[14] != "":
                packet_losses.append(float(row[14]))
        except (TypeError, ValueError, OverflowError):
            continue
    if not timestamps:
        timestamps = [0]
        downloads = [0]
        uploads = [0]
        latencies = [0]
    return {
        "samples": 0 if timestamps == [0] else len(timestamps),
        "period": {
            "oldest": str(datetime.fromtimestamp(min(timestamps), timezone.utc)),
            "youngest": str(datetime.fromtimestamp(max(timestamps), timezone.utc)),
        },
        "latency": {
            "avg": round(statistics.mean(latencies), 2),
            "min": round(min(latencies), 2),
            "max": round(max(latencies), 2),
        },
        "download": {
            "avg": round(statistics.mean(downloads), 2),
            "min": round(min(downloads), 2),
            "max": round(max(downloads), 2),
        },
        "upload": {
            "avg": round(statistics.mean(uploads), 2),
            "min": round(min(uploads), 2),
            "max": round(max(uploads), 2),
        },
        "packetLoss": {
            "samples": len(packet_losses),
            "avg": round(statistics.mean(packet_losses), 2) if packet_losses else None,
            "min": round(min(packet_losses), 2) if packet_losses else None,
            "max": round(max(packet_losses), 2) if packet_losses else None,
        },
    }


def clear_history() -> None:
    path = history_path()
    if os.path.exists(path):
        os.unlink(path)
    ensure_history()
