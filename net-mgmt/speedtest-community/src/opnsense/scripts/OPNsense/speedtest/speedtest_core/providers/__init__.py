# Copyright (C) 2026
# SPDX-License-Identifier: BSD-2-Clause

from .cloudflare import CloudflareAdapter
from .librespeed import LibreSpeedAdapter
from .ookla import OoklaAdapter


def provider_adapters():
    return {
        "ookla": OoklaAdapter(),
        "librespeed": LibreSpeedAdapter(),
        "cloudflare": CloudflareAdapter(),
    }
