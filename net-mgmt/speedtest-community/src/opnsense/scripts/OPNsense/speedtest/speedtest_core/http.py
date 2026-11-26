# Copyright (C) 2026
# SPDX-License-Identifier: BSD-2-Clause

import json
import os
import threading
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from statistics import mean, median
from typing import Callable, List, Tuple

from .errors import TransferError


USER_AGENT = "OPNsense-Speedtest/1.0"


def with_query(url: str, **values) -> str:
    parsed = urllib.parse.urlsplit(url)
    query = urllib.parse.parse_qsl(parsed.query, keep_blank_values=True)
    query.extend((key, str(value)) for key, value in values.items() if value is not None)
    return urllib.parse.urlunsplit(
        (parsed.scheme, parsed.netloc, parsed.path, urllib.parse.urlencode(query), parsed.fragment)
    )


def endpoint(base_url: str, path: str) -> str:
    base = base_url.rstrip("/") + "/"
    return urllib.parse.urljoin(base, path.lstrip("/"))


def opener():
    return urllib.request.build_opener(urllib.request.ProxyHandler({}))


def open_request(url: str, timeout: float, data: bytes = None, method: str = "GET"):
    request = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "*/*",
            "Cache-Control": "no-cache",
            "Pragma": "no-cache",
            "Content-Type": "application/octet-stream",
            "Content-Encoding": "identity",
        },
    )
    return opener().open(request, timeout=timeout)


def fetch_json(url: str, timeout: float):
    with open_request(url, timeout) as response:
        payload = json.loads(response.read().decode("utf-8"))
    return payload


def measure_http_latency(
    url: str, samples: int, timeout: float
) -> Tuple[float, float, List[float]]:
    timings = []
    for index in range(samples):
        started = time.perf_counter()
        sample_url = with_query(url, r=f"{time.time_ns()}-{index}")
        with open_request(sample_url, timeout) as response:
            response.read(1)
        timings.append((time.perf_counter() - started) * 1000.0)
    latency = median(timings)
    if len(timings) > 1:
        jitter = mean(abs(current - previous) for previous, current in zip(timings, timings[1:]))
    else:
        jitter = 0.0
    return latency, jitter, timings


def timed_download(
    url_factory: Callable[[int], str], duration: int, streams: int, timeout: float
) -> Tuple[float, List[str]]:
    deadline = time.perf_counter() + duration
    started = time.perf_counter()
    total_bytes = 0
    byte_lock = threading.Lock()
    failures = []

    def worker(stream_id: int) -> None:
        nonlocal total_bytes
        local_bytes = 0
        try:
            while time.perf_counter() < deadline:
                remaining = max(0.1, deadline - time.perf_counter())
                with open_request(
                    url_factory(stream_id), min(timeout, max(1.0, remaining + 1))
                ) as response:
                    while time.perf_counter() < deadline:
                        chunk = response.read(65536)
                        if not chunk:
                            break
                        local_bytes += len(chunk)
        except Exception as exc:
            failures.append(f"download stream {stream_id}: {exc}")
        finally:
            with byte_lock:
                total_bytes += local_bytes

    with ThreadPoolExecutor(max_workers=streams) as executor:
        list(executor.map(worker, range(streams)))
    elapsed = max(time.perf_counter() - started, 0.001)
    if total_bytes == 0:
        detail = failures[0] if failures else "no bytes received"
        raise TransferError(f"Download failed: {detail}")
    return total_bytes * 8.0 / elapsed / 1_000_000.0, failures


def timed_upload(
    url_factory: Callable[[int], str], duration: int, streams: int, timeout: float
) -> Tuple[float, List[str]]:
    deadline = time.perf_counter() + duration
    started = time.perf_counter()
    total_bytes = 0
    byte_lock = threading.Lock()
    failures = []
    payload = os.urandom(1024 * 1024)

    def worker(stream_id: int) -> None:
        nonlocal total_bytes
        local_bytes = 0
        try:
            while time.perf_counter() < deadline:
                remaining = max(0.1, deadline - time.perf_counter())
                with open_request(
                    url_factory(stream_id),
                    min(max(timeout, 8.0), max(8.0, remaining + 2)),
                    data=payload,
                    method="POST",
                ) as response:
                    response.read(4096)
                local_bytes += len(payload)
        except Exception as exc:
            failures.append(f"upload stream {stream_id}: {exc}")
        finally:
            with byte_lock:
                total_bytes += local_bytes

    with ThreadPoolExecutor(max_workers=streams) as executor:
        list(executor.map(worker, range(streams)))
    elapsed = max(time.perf_counter() - started, 0.001)
    if total_bytes == 0:
        detail = failures[0] if failures else "no bytes accepted"
        raise TransferError(f"Upload failed: {detail}")
    return total_bytes * 8.0 / elapsed / 1_000_000.0, failures
