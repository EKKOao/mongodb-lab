#!/usr/bin/env bash
set -euo pipefail
source /vagrant/00-env.sh

mkdir -p /vagrant/secrets/mongodb "${MONGO_SECURITY_DIR}"
chmod 700 /vagrant/secrets/mongodb

if [ "$(hostname_short)" = "cfg1" ] && [ ! -f "${KEYFILE_SHARED}" ]; then
  echo "Generating MongoDB internal authentication keyfile on cfg1."
  openssl rand -base64 756 | tr -d '\n' > "${KEYFILE_SHARED}"
  echo >> "${KEYFILE_SHARED}"
  chmod 400 "${KEYFILE_SHARED}"
fi

while [ ! -f "${KEYFILE_SHARED}" ]; do
  echo "Waiting for shared MongoDB keyfile from cfg1..."
  sleep 2
done

cp "${KEYFILE_SHARED}" "${KEYFILE_LOCAL}"
chown "${MONGO_USER}:${MONGO_GROUP}" "${KEYFILE_LOCAL}"
chmod 400 "${KEYFILE_LOCAL}"

echo "MongoDB keyfile installed at ${KEYFILE_LOCAL}."
