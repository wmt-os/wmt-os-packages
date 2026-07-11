#!/bin/bash
# Build the xdm armel deb packages
#
# Output: ./dist/*.deb (override: OUT=)
# Requires: mmdebstrap qemu-user-binfmt uidmap
#
# Copyright (C) 2026 Logan Russell <me@lrussell.net>

set -eu
. "$(dirname "$0")/../lib.sh"

WMTOS_REV=1
DCH_MSG="Default the login logo to WMT OS; fix the greeter erasing the frame bevel."

mkdir -p "$OUT"
rm -f "$OUT"/*.deb
mmdebstrap --variant=buildd --architectures=armel --include="devscripts" \
	--customize-hook="copy-in $SRC/patches $SRC/wmt-os.xpm $SRC/wmt-os-bw.xpm /" \
	--chrooted-customize-hook="$(cat <<-EOF
		set -e

		apt-get source xdm
		cd xdm-*
		mv /wmt-os*.xpm debian/local/
		patch -p1 < /patches/01-wmt-os-pixmaps.patch

		# Source patches must join the series or the clean target's unapply breaks
		cp /patches/02-fail-clear-width.patch debian/patches/
		echo 02-fail-clear-width.patch >> debian/patches/series

		export DEBFULLNAME="$BUILDER_NAME" DEBEMAIL="$BUILDER_EMAIL"
		dch -v "\$(dpkg-parsechangelog -S Version)+wmtos$WMTOS_REV" -D trixie "$DCH_MSG"
		apt-get -y --no-install-recommends build-dep ./
		dpkg-buildpackage -b -uc -us -j$(nproc)

		mkdir /out
		mv /*.deb /out/
		EOF
	)" \
	--customize-hook="sync-out /out $OUT" \
	trixie /dev/null "$SRC"/../debian.sources

ls -1 "$OUT"/*.deb
