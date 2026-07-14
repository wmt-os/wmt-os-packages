# WMT OS Dist Build Settings
#
# Copyright (C) 2026 Logan Russell <me@lrussell.net>

export NICE="${NICE:-19}" # Niceness value

export BUILDER_NAME="${BUILDER_NAME:-WMT OS Builder}"
export BUILDER_EMAIL="${BUILDER_EMAIL:-root@wmt-os.org}"

export ARCHIVE="${ARCHIVE:-/tmp/wmt-os-repo}" # APT archive rsync target (local or remote)
export RELEASES="${RELEASES:-/tmp/wmt-os-releases}" # Release images rsync target (local or remote)
export KEYID="${KEYID:-C88AB20897CC3653}" # Archive signing key in GPG
