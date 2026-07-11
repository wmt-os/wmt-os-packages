#!/bin/bash
# Build the imlib2 armel deb packages
#
# Output: ./dist/*.deb (override: OUT=)
# Requires: mmdebstrap qemu-user-binfmt uidmap
#
# Copyright (C) 2026 Logan Russell <me@lrussell.net>

set -eu
. "$(dirname "$0")/../lib.sh"

WMTOS_REV=1
DCH_MSG="Fix PNG unaligned access SIGSEGV on armel by building with --enable-packing."

mkdir -p "$OUT"
rm -f "$OUT"/*.deb
mmdebstrap --variant=buildd --architectures=armel --include="devscripts" \
	--customize-hook="copy-in $SRC/patches /" \
	--chrooted-customize-hook="$(cat <<-EOF
		set -e

		apt-get source imlib2
		cd imlib2-*
		patch -p1 < /patches/01-enable-packing.patch

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
