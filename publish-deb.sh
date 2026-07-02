#!/bin/bash
# Publish debs to the apt archive: rsync in, gate on the version grammar, prune,
# reindex, sign, rsync out. Stateless -- the published pool is the only ledger.
# No arguments just reindexes and re-signs; nothing is ever removed by it.
#
# Requires: apt-utils dpkg gnupg rsync
#
# Copyright (C) 2026 Logan Russell <me@lrussell.net>

set -eu
export LC_ALL=C

SRC=$(cd "$(dirname "$0")" && pwd)
. "$SRC/config.sh"

MIRROR="$SRC/mirror"
POOL="$MIRROR/pool/main"
DIST="$MIRROR/dists/trixie"

hex12() { [[ $1 =~ ^[0-9a-f]{12}$ ]]; }

exec 9<"$0"; flock 9 # one publish at a time

# Pull the archive; the remote is the truth
if ! rsync -a --delete "$REMOTE/" "$MIRROR/" 2>/dev/null; then
	case $REMOTE in
	*:*) echo "publish-deb: cannot sync from $REMOTE" >&2; exit 1 ;;
	esac
fi
mkdir -p "$POOL" "$DIST/main/binary-armel"

# The pool in one scan: the highest published version of every package
declare -A have
for f in "$POOL"/*.deb; do
	[ -e "$f" ] || break
	read -r pkg ver < <(dpkg-deb -W "$f")
	if [ -z "${have[$pkg]:-}" ] || dpkg --compare-versions "$ver" gt "${have[$pkg]}"; then
		have[$pkg]=$ver
	fi
done

# Gate every deb; refuse the whole run before touching the archive if any fails
publish=() err=
for deb in "$@"; do
	read -r pkg ver < <(dpkg-deb -W "$deb")
	if [[ "$pkg $ver" == *dirty* ]]; then
		echo "error: $pkg $ver is a dirty build" >&2; err=1; continue
	fi
	cur=${have[$pkg]:-}
	if [ -z "$cur" ]; then
		echo "publish: $pkg $ver"; publish+=("$deb"); have[$pkg]=$ver
	elif hex12 "${pkg##*-}"; then
		echo "skip: $pkg already published"
	elif [[ $ver == *+* ]] && hex12 "${ver##*+}" && [ "${ver##*+}" = "${cur##*+}" ]; then
		echo "skip: $pkg $ver matches published content ($cur)"
	elif dpkg --compare-versions "$ver" gt "$cur"; then
		echo "publish: $pkg $ver (over $cur)"; publish+=("$deb"); have[$pkg]=$ver
	elif dpkg --compare-versions "$ver" eq "$cur"; then
		echo "skip: $pkg $ver already published"
	else
		echo "error: $pkg $ver is older than published $cur" >&2; err=1
	fi
done
[ -z "$err" ] || { echo "publish-deb: refused; the archive is untouched" >&2; exit 1; }
if [ $# -gt 0 ] && [ ${#publish[@]} -eq 0 ]; then
	echo "nothing new to publish"; exit 0
fi

if [ ${#publish[@]} -gt 0 ]; then
	cp "${publish[@]}" "$POOL/"
	# Prune superseded versions, then GC content-addressed packages (-<12hex>,
	# the kernels) that nothing in the pool depends on any more
	for f in "$POOL"/*.deb; do
		read -r pkg ver < <(dpkg-deb -W "$f")
		[ "$ver" = "${have[$pkg]}" ] || { echo "prune: $pkg $ver"; rm "$f"; }
	done
	deps=$(for f in "$POOL"/*.deb; do dpkg-deb -f "$f" Depends; done)
	for f in "$POOL"/*.deb; do
		read -r pkg _ < <(dpkg-deb -W "$f")
		hex12 "${pkg##*-}" || continue
		[[ $deps == *"$pkg"* ]] || { echo "gc: $pkg"; rm "$f"; }
	done
fi

# Reindex, sign, push: pool additions, index swap, then deletions. The index push
# compares content -- same-size regenerations fool rsync's quick check
(cd "$MIRROR" && apt-ftparchive generate "$SRC/apt-ftparchive.conf" >/dev/null)
gzip -9nc "$DIST/main/binary-armel/Packages" > "$DIST/main/binary-armel/Packages.gz"
(cd "$MIRROR" && apt-ftparchive -c "$SRC/apt-ftparchive.conf" release dists/trixie) > "$DIST/Release"
gpg --batch --yes -u "$KEYID" --clearsign -o "$DIST/InRelease" "$DIST/Release"

case $REMOTE in *:*) ;; *) mkdir -p "$REMOTE" ;; esac
rsync -a "$MIRROR/pool" "$REMOTE/"
rsync -ac --delete "$MIRROR/dists" "$REMOTE/"
rsync -a --delete "$MIRROR/pool" "$REMOTE/"
echo "publish-deb: archive updated at $REMOTE"
