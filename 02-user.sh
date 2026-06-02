#!/usr/bin/env bash
set -euo pipefail
source /vagrant/00-env.sh

if ! getent group "${MONGO_GROUP}" >/dev/null; then
  groupadd -g "${MONGO_GID}" -r "${MONGO_GROUP}"
fi

if ! id -u "${MONGO_USER}" >/dev/null 2>&1; then
  useradd -u "${MONGO_UID}" -g "${MONGO_GROUP}" -r -s /usr/sbin/nologin -d "${MONGO_HOME}" "${MONGO_USER}"
fi

mkdir -p "${MONGO_HOME}" "${MONGO_DATA}" "${MONGO_LOG}" "${MONGO_BACKUP}"
chown -R "${MONGO_USER}:${MONGO_GROUP}" "${MONGO_BASE}"

echo "MongoDB service account ready: ${MONGO_USER}:${MONGO_GROUP}"
