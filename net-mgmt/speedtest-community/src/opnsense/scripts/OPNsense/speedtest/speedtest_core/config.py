# Copyright (C) 2026
# SPDX-License-Identifier: BSD-2-Clause

import os
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from typing import Dict, List, Optional
from urllib.parse import urlsplit

from .models import Server


DEFAULT_CONFIG_PATH = "/conf/config.xml"
DEFAULT_LIBRESPEED_LIST_URL = "https://librespeed.org/backend-servers/servers.json"
DEFAULT_CLOUDFLARE_BASE_URL = "https://speed.cloudflare.com"


def parse_boolean(value: Optional[str], default: bool) -> bool:
    if value is None:
        return default
    return value.strip().lower() in ("1", "true", "yes", "on")


def parse_int(node, name: str, default: int, minimum: int, maximum: int) -> int:
    raw = node.findtext(name)
    if raw is None:
        return default
    try:
        return max(minimum, min(maximum, int(raw)))
    except (TypeError, ValueError):
        return default


def child_text(node, name: str, default: str = "") -> str:
    value = node.findtext(name)
    return default if value is None else value.strip()


def normalize_http_url(
    value: str,
    default: str = "",
    allow_query: bool = False,
) -> str:
    value = str(value or "").strip()
    if not value:
        return default
    if (
        len(value) > 2048
        or "\\" in value
        or re.search(r"\s|[\x00-\x1f\x7f]", value)
    ):
        return ""
    if value.startswith("//"):
        value = "https:" + value
    try:
        parsed = urlsplit(value)
        parsed.port
    except ValueError:
        return ""
    if (
        parsed.scheme not in ("http", "https")
        or not parsed.hostname
        or parsed.username
        or parsed.password
        or (parsed.query and not allow_query)
        or parsed.fragment
    ):
        return ""
    return value.rstrip("/")


@dataclass
class Settings:
    providers: Dict[str, bool] = field(
        default_factory=lambda: {"ookla": True, "librespeed": True, "cloudflare": True}
    )
    librespeed_list_url: str = DEFAULT_LIBRESPEED_LIST_URL
    cloudflare_base_url: str = DEFAULT_CLOUDFLARE_BASE_URL
    auto_refresh: bool = True
    refresh_interval: int = 1440
    last_refresh: int = 0
    max_candidates: int = 64
    ping_samples: int = 3
    probe_timeout: int = 3
    probe_workers: int = 12
    test_duration: int = 8
    transfer_streams: int = 3
    servers: List[Server] = field(default_factory=list)


def _model_node(root: ET.Element) -> Optional[ET.Element]:
    for path in ("./OPNsense/speedtest", "./opnsense/OPNsense/speedtest"):
        node = root.find(path)
        if node is not None:
            return node
    return None


def load_settings(config_path: Optional[str] = None) -> Settings:
    path = config_path or os.environ.get("OPNSENSE_SPEEDTEST_CONFIG", DEFAULT_CONFIG_PATH)
    settings = Settings()
    if not os.path.isfile(path):
        return settings

    root = ET.parse(path).getroot()
    node = _model_node(root)
    if node is None:
        return settings

    for provider in ("ookla", "librespeed", "cloudflare"):
        field_name = provider + "Enabled"
        settings.providers[provider] = parse_boolean(
            node.findtext(field_name), settings.providers[provider]
        )

    settings.librespeed_list_url = normalize_http_url(
        child_text(node, "librespeedListUrl"),
        DEFAULT_LIBRESPEED_LIST_URL,
        allow_query=True,
    )
    settings.cloudflare_base_url = normalize_http_url(
        child_text(node, "cloudflareBaseUrl"), DEFAULT_CLOUDFLARE_BASE_URL
    )
    settings.auto_refresh = parse_boolean(node.findtext("autoRefresh"), True)
    settings.refresh_interval = parse_int(node, "refreshInterval", 1440, 60, 525600)
    settings.last_refresh = parse_int(node, "lastRefresh", 0, 0, 4102444800)
    settings.max_candidates = parse_int(node, "maxCandidates", 64, 1, 100)
    settings.ping_samples = parse_int(node, "pingSamples", 3, 1, 10)
    settings.probe_timeout = parse_int(node, "probeTimeout", 3, 1, 20)
    settings.probe_workers = parse_int(node, "probeWorkers", 12, 1, 32)
    settings.test_duration = parse_int(node, "testDuration", 8, 2, 30)
    settings.transfer_streams = parse_int(node, "transferStreams", 3, 1, 8)

    servers = []
    for server_node in node.findall("./servers/server"):
        provider = child_text(server_node, "provider").lower()
        if provider not in settings.providers:
            continue
        port_raw = child_text(server_node, "port")
        try:
            port = max(1, min(65535, int(port_raw))) if port_raw else 0
        except ValueError:
            port = 0
        servers.append(
            Server(
                uuid=server_node.attrib.get("uuid", ""),
                enabled=parse_boolean(server_node.findtext("enabled"), True),
                available=parse_boolean(server_node.findtext("available"), True),
                provider=provider,
                name=child_text(server_node, "name", provider),
                server_id=child_text(server_node, "serverId"),
                location=child_text(server_node, "location"),
                country=child_text(server_node, "country"),
                base_url=normalize_http_url(child_text(server_node, "baseUrl")),
                host=child_text(server_node, "host"),
                port=port,
                download_path=child_text(server_node, "downloadPath"),
                upload_path=child_text(server_node, "uploadPath"),
                ping_path=child_text(server_node, "pingPath"),
                ip_path=child_text(server_node, "ipPath"),
                source=child_text(server_node, "source", "custom"),
            )
        )
    settings.servers = servers
    return settings
