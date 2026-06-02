#!/usr/bin/env bash
set -euo pipefail
source /vagrant/00-env.sh

VG="vg_mongodb"

bytes_to_gb() { awk -v b="$1" 'BEGIN { printf "%.0f", b/1024/1024/1024 }'; }

find_candidate_disk() {
  while read -r name type rm size mount; do
    [ "$type" = "disk" ] || continue
    [ "$rm" = "0" ] || continue

    # Skip the root/system disk and tiny VirtualBox helper disks.
    if lsblk -nr "/dev/${name}" -o MOUNTPOINT | grep -q '^/'; then
      continue
    fi
    if pvs "/dev/${name}" >/dev/null 2>&1; then
      continue
    fi

    gb=$(bytes_to_gb "$size")
    [ "$gb" -ge 15 ] || continue
    echo "/dev/${name}"
    return 0
  done < <(lsblk -bdnr -o NAME,TYPE,RM,SIZE,MOUNTPOINT)
  return 1
}

mkdir -p "${MONGO_BASE}" "${MONGO_HOME}" "${MONGO_DATA}" "${MONGO_LOG}" "${MONGO_BACKUP}"

if ! vgs "${VG}" >/dev/null 2>&1; then
  DISK="$(find_candidate_disk || true)"
  if [ -n "${DISK}" ]; then
    echo "Using dedicated MongoDB disk: ${DISK}"
    pvcreate -ff -y "${DISK}"
    vgcreate "${VG}" "${DISK}"
  else
    echo "No suitable dedicated disk found; using directory layout under /mnt/mongodb."
  fi
fi

vg_free_gb() {
  vgs --noheadings --units g --nosuffix -o vg_free "${VG}" 2>/dev/null | awk '{printf "%.0f", $1}'
}

create_lv_if_possible() {
  local lv="$1" size="$2" path="$3"
  if vgs "${VG}" >/dev/null 2>&1; then
    if ! lvs "${VG}/${lv}" >/dev/null 2>&1; then
      echo "Creating LV ${lv} (${size}) for ${path}; VG free before create: $(vg_free_gb)G"
      if ! lvcreate -L "${size}" -n "${lv}" "${VG}"; then
        echo "ERROR: failed to create ${lv} (${size}). Check the Vagrant disk size and existing LVs." >&2
        vgs "${VG}" || true
        lvs "${VG}" || true
        exit 1
      fi
      mkfs.xfs -f "/dev/${VG}/${lv}"
    fi
    mkdir -p "${path}"
    if ! grep -q "${path} " /proc/mounts; then
      mount "/dev/${VG}/${lv}" "${path}"
      grep -q "/dev/${VG}/${lv} ${path} " /etc/fstab || echo "/dev/${VG}/${lv} ${path} xfs defaults,noatime 0 0" >> /etc/fstab
    fi
  else
    mkdir -p "${path}"
  fi
}

ROLE="$(node_role)"
case "${ROLE}" in
  config)
    # Config servers store metadata, not user data; keep data modest and reserve backup/log space.
    create_lv_if_possible mongodb_home   4G "${MONGO_HOME}"
    create_lv_if_possible mongodb_data   8G "${MONGO_DATA}"
    create_lv_if_possible mongodb_log    3G "${MONGO_LOG}"
    create_lv_if_possible mongodb_backup 6G "${MONGO_BACKUP}"
    ;;
  shard1|shard2)
    # Shards hold user data; give them the largest volume.
    create_lv_if_possible mongodb_home   4G "${MONGO_HOME}"
    create_lv_if_possible mongodb_data  20G "${MONGO_DATA}"
    create_lv_if_possible mongodb_log    4G "${MONGO_LOG}"
    create_lv_if_possible mongodb_backup 8G "${MONGO_BACKUP}"
    ;;
  mongos)
    # Routers do not persist database data, but we keep the required directory layout.
    create_lv_if_possible mongodb_home   4G "${MONGO_HOME}"
    mkdir -p "${MONGO_DATA}"
    create_lv_if_possible mongodb_log    3G "${MONGO_LOG}"
    create_lv_if_possible mongodb_backup 6G "${MONGO_BACKUP}"
    ;;
  *)
    echo "ERROR: unknown MongoDB role ${ROLE}" >&2
    exit 1
    ;;
esac

mkdir -p "${MONGO_HOME}" "${MONGO_DATA}" "${MONGO_LOG}" "${MONGO_BACKUP}"
chown -R "${MONGO_USER}:${MONGO_GROUP}" "${MONGO_BASE}"
chmod 0750 "${MONGO_BASE}" "${MONGO_HOME}" "${MONGO_DATA}" "${MONGO_LOG}" "${MONGO_BACKUP}"

lsblk
