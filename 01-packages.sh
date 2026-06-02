#!/usr/bin/env bash
set -euo pipefail
source /vagrant/00-env.sh

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y \
  acl ca-certificates curl wget gnupg lsb-release \
  tar gzip xz-utils jq openssl net-tools iproute2 \
  lvm2 xfsprogs util-linux procps psmisc numactl \
  python3 dnsutils

echo "Base OS packages installed for MongoDB binary deployment."
