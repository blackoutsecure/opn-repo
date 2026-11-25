PLUGIN_NAME=		speedtest-community
PLUGIN_VERSION=		0.14
PLUGIN_COMMENT=		LibreSpeed network measurements
PLUGIN_LICENSE=		LGPL3
PLUGIN_MAINTAINER=	miha.kralj@outlook.com

# The shared development upgrade target deletes the old package before adding
# the replacement. Preserve this plugin's data during that intentional delete.
.if make(upgrade)
PKG_UPGRADE=		1
.export PKG_UPGRADE
.endif

.include "../../Mk/plugins.mk"
