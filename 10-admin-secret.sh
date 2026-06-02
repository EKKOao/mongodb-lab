#!/usr/bin/env bash
set -euo pipefail
source /vagrant/00-env.sh

mkdir -p /vagrant/secrets/mongodb
chmod 700 /vagrant/secrets/mongodb

if [ "$(hostname_short)" = "cfg1" ] && [ ! -f "${ADMIN_SECRET_FILE}" ]; then
  echo "Generating MongoDB cluster admin password on cfg1."
  openssl rand -base64 48 | tr -d '=+/[:space:]' | cut -c1-40 > "${ADMIN_SECRET_FILE}"
  chmod 600 "${ADMIN_SECRET_FILE}"
fi

while [ ! -f "${ADMIN_SECRET_FILE}" ]; do
  echo "Waiting for MongoDB admin password from cfg1..."
  sleep 2
done

echo "MongoDB admin secret is available."
