#!/usr/bin/env bash
set -euo pipefail
swapoff -a || true
sed -i.bak '/\sswap\s/s/^/#/' /etc/fstab || true
if [ "$(swapon --show | wc -l)" -eq 0 ]; then
  echo "Swap is disabled."
else
  echo "Swap is still active:"
  swapon --show
fi
