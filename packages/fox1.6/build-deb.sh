#!/bin/bash
# Build the fox1.6-utils armel deb package
#
# Output: ./dist/*.deb (override: OUT=)
# Requires: mmdebstrap qemu-user-binfmt uidmap
#
# Copyright (C) 2026 Logan Russell <me@lrussell.net>

set -eu
. "$(dirname "$0")/../lib.sh"

WMTOS_REV=1

mkdir -p "$OUT"
rm -f "$OUT"/*.deb
mmdebstrap --variant=buildd --architectures=armel --include="devscripts imagemagick" \
	--customize-hook="copy-in $SRC/patches /" \
	--chrooted-customize-hook="$(cat <<-EOF
		set -e

		apt-get source fox1.6
		cd fox1.6-*
		patch -p1 < /patches/01-scroll-blank.patch
		patch -p1 < /patches/02-wheel-timing.patch
		patch -p1 < /patches/03-selection-repaint.patch
		patch -p1 < /patches/04-typing-damage.patch
		patch -p1 < /patches/05-utils-package.patch
		patch -p1 < /patches/06-format-security.patch
		patch -p1 < /patches/07-adie-highlighting.patch

		# Reuse each application's window icon as its desktop entry icon
		magick adie/big_gif.gif debian/adie.xpm
		magick calculator/bigcalc.gif debian/calculator.xpm
		magick shutterbug/shutterbug.gif debian/shutterbug.xpm

		export DEBFULLNAME="$BUILDER_NAME" DEBEMAIL="$BUILDER_EMAIL"
		dch -v "\$(dpkg-parsechangelog -S Version)+wmtos$WMTOS_REV" -D trixie \
			"Blank freshly exposed strips when scrolling to stop duplication."
		dch -a "Backport the 1.7 wheel timing so painting keeps pace with the glide."
		dch -a "Repaint the selection as it changes to keep highlighting current."
		dch -a "Repaint only from the change onward when editing a line."
		dch -a "Ship the bundled applications as fox1.6-utils with desktop entries."
		dch -a "Do not treat format-security as an error in the applications."
		dch -a "Ship Adie's syntax file and default colors for highlighting."

		apt-get -y --no-install-recommends build-dep ./
		dpkg-buildpackage -b -uc -us -j$(nproc)

		mkdir /out
		mv /*.deb /out/
		EOF
	)" \
	--customize-hook="sync-out /out $OUT" \
	trixie /dev/null "$SRC"/../debian.sources

ls -1 "$OUT"/*.deb
