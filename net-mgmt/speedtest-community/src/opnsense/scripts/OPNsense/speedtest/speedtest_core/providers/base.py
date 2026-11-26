# Copyright (C) 2026
# SPDX-License-Identifier: BSD-2-Clause

from abc import ABC, abstractmethod
from typing import Dict, List

from ..config import Settings
from ..models import ProbeResult, Server, SpeedResult


class ProviderAdapter(ABC):
    provider_id = ""
    label = ""
    supports_discovery = True

    @abstractmethod
    def status(self, settings: Settings) -> Dict:
        raise NotImplementedError

    @abstractmethod
    def discover(self, settings: Settings) -> List[Server]:
        raise NotImplementedError

    @abstractmethod
    def probe(self, server: Server, settings: Settings, progress=None) -> ProbeResult:
        raise NotImplementedError

    @abstractmethod
    def run(self, server: Server, settings: Settings, progress=None) -> SpeedResult:
        raise NotImplementedError
