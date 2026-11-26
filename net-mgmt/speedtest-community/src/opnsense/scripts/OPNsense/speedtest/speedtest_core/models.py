# Copyright (C) 2026
# SPDX-License-Identifier: BSD-2-Clause

from dataclasses import asdict, dataclass, field
from typing import Any, Dict, List


PROVIDER_LABELS = {
    "ookla": "Ookla (CLI)",
    "librespeed": "LibreSpeed (HTTP)",
    "cloudflare": "Cloudflare (Edge)",
}


@dataclass
class Server:
    provider: str
    name: str
    server_id: str = ""
    uuid: str = ""
    location: str = ""
    country: str = ""
    base_url: str = ""
    host: str = ""
    port: int = 0
    download_path: str = ""
    upload_path: str = ""
    ping_path: str = ""
    ip_path: str = ""
    source: str = "public"
    enabled: bool = True
    metadata: Dict[str, Any] = field(default_factory=dict)

    @property
    def key(self) -> str:
        identifier = self.server_id or self.base_url.rstrip("/")
        return "|".join((self.provider, identifier))

    @property
    def selection_name(self) -> str:
        suffix = self.location.strip()
        return self.name if not suffix or suffix in self.name else f"{self.name}, {suffix}"

    def as_dict(self) -> Dict[str, Any]:
        payload = asdict(self)
        payload["providerLabel"] = PROVIDER_LABELS.get(self.provider, self.provider)
        payload["selectionName"] = self.selection_name
        return payload


@dataclass
class ProbeResult:
    server: Server
    latency: float = 0.0
    jitter: float = 0.0
    samples: List[float] = field(default_factory=list)
    score: float = float("inf")
    error: str = ""

    @property
    def succeeded(self) -> bool:
        return not self.error and bool(self.samples)

    def as_dict(self) -> Dict[str, Any]:
        return {
            "provider": self.server.provider,
            "providerLabel": PROVIDER_LABELS.get(self.server.provider, self.server.provider),
            "serverId": self.server.server_id,
            "serverUuid": self.server.uuid,
            "server": self.server.selection_name,
            "latency": round(self.latency, 2) if self.succeeded else None,
            "jitter": round(self.jitter, 2) if self.succeeded else None,
            "score": round(self.score, 2) if self.succeeded else None,
            "error": self.error,
        }


@dataclass
class SpeedResult:
    provider: str
    timestamp: str
    client_ip: str
    server: Server
    latency: float
    download: float
    upload: float
    server_id_output: Any = None
    link: str = ""
    jitter: float = 0.0
    loaded_latency: float = 0.0
    engine: str = ""
    warnings: List[str] = field(default_factory=list)

    def as_dict(self) -> Dict[str, Any]:
        return {
            "timestamp": self.timestamp,
            "provider": self.provider,
            "providerLabel": PROVIDER_LABELS.get(self.provider, self.provider),
            "clientip": self.client_ip,
            "serverid": (
                self.server.server_id if self.server_id_output is None else self.server_id_output
            ),
            "serveruuid": self.server.uuid,
            "servername": self.server.selection_name,
            "country": self.server.country,
            "location": self.server.location,
            "latency": round(self.latency, 2),
            "jitter": round(self.jitter, 2),
            "loadedLatency": round(self.loaded_latency, 2),
            "download": round(self.download, 2),
            "upload": round(self.upload, 2),
            "link": self.link,
            "engine": self.engine,
            "warnings": self.warnings,
        }
