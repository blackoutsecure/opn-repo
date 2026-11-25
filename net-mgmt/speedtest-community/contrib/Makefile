ENGINE_ROOT?=	${.CURDIR}/.build
LOCALBASE?=	/usr/local

engine:
	@/bin/sh ${.CURDIR}/build.sh "${ENGINE_ROOT}"

install: engine
	@mkdir -p "${DESTDIR}${LOCALBASE}/bin" "${DESTDIR}${LOCALBASE}/share/speedtest-community"
	@install -m 755 "${ENGINE_ROOT}/bin/librespeed-cli" "${DESTDIR}${LOCALBASE}/bin/librespeed-cli"
	@install -m 644 "${ENGINE_ROOT}/librespeed-cli-1.2.1/LICENSE" "${DESTDIR}${LOCALBASE}/share/speedtest-community/LIBRESPEED-LICENSE"
	@install -m 644 "${ENGINE_ROOT}/THIRD-PARTY-NOTICES" "${DESTDIR}${LOCALBASE}/share/speedtest-community/THIRD-PARTY-NOTICES"
	@install -m 644 "${ENGINE_ROOT}/librespeed-cli-1.2.1.crate" "${DESTDIR}${LOCALBASE}/share/speedtest-community/librespeed-cli-1.2.1.crate"

plist:
	@echo "${LOCALBASE}/bin/librespeed-cli"
	@echo "${LOCALBASE}/share/speedtest-community/LIBRESPEED-LICENSE"
	@echo "${LOCALBASE}/share/speedtest-community/THIRD-PARTY-NOTICES"
	@echo "${LOCALBASE}/share/speedtest-community/librespeed-cli-1.2.1.crate"
