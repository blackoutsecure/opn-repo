# Copyright (C) 2026
# SPDX-License-Identifier: BSD-2-Clause


class SpeedtestError(Exception):
    """A user-visible speedtest failure."""


class ProviderUnavailableError(SpeedtestError):
    """The selected provider is not usable on this system."""


class ServerNotFoundError(SpeedtestError):
    """The selected server no longer exists or is disabled."""


class TransferError(SpeedtestError):
    """A provider transfer did not produce a usable measurement."""
