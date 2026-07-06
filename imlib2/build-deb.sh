#!/bin/sh
# Build the imlib2 armel deb packages
#
# Output: ./dist/*.deb (override: OUT=)
# Build-depends: mmdebstrap qemu-user-binfmt
#
# Copyright (C) 2026 Logan Russell <me@lrussell.net>

set -eu

SRC=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
OUT=${OUT:-$SRC/dist}
. "$SRC"/../config.sh

WMTOS_REV=1
DCH_MSG="Fix PNG unaligned access SIGSEGV on armel by building with --enable-packing."

mkdir -p "$OUT"
rm -f "$OUT"/*.deb
mmdebstrap --variant=buildd --architectures=armel --include="devscripts" \
	--chrooted-customize-hook="apt-get source imlib2 && cd imlib2-* &&
		sed -i 's/--enable-rtld-local-support/& --enable-packing/' debian/rules &&
		export DEBFULLNAME=\"$BUILDER_NAME\" DEBEMAIL=\"$BUILDER_EMAIL\" &&
		dch -v \"\$(dpkg-parsechangelog -S Version)+wmtos$WMTOS_REV\" -D trixie \"$DCH_MSG\" &&
		apt-get -y --no-install-recommends build-dep ./ && dpkg-buildpackage -b -uc -us &&
		mkdir /out && mv /*.deb /out/" \
	--customize-hook="sync-out /out $OUT" \
	trixie /dev/null \
	"https://deb.debian.org/debian" "deb-src https://deb.debian.org/debian trixie main"

ls -1 "$OUT"/*.deb
