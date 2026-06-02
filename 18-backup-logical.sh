#!/usr/bin/env bash
set -euo pipefail
source /vagrant/00-env.sh

if [ ! -x "${MONGO_BIN}/mongodump" ]; then
  echo "ERROR: mongodump not installed. Check INSTALL_DATABASE_TOOLS in 00-env.sh." >&2
  exit 1
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="${MONGO_BACKUP}/logical-${TS}"
PASS="$(admin_password)"
mkdir -p "${OUT}"

URI="mongodb://${ADMIN_USER}:${PASS}@mongos1:${MONGOS_PORT}/admin?tls=true&tlsCAFile=${LOCAL_CA}&tlsAllowInvalidHostnames=true"

echo "Writing logical backup to ${OUT}"
"${MONGO_BIN}/mongodump" --uri "${URI}" --out "${OUT}/dump"

"${MONGO_BIN}/mongosh" --quiet --tls --tlsCAFile "${LOCAL_CA}" --tlsAllowInvalidHostnames \
  -u "${ADMIN_USER}" -p "${PASS}" --authenticationDatabase admin \
  --host mongos1 --port "${MONGOS_PORT}" <<'JS' > "${OUT}/cluster-metadata.txt"
print('== listShards ==');
printjson(db.adminCommand({ listShards: 1 }));
print('\n== balancerStatus ==');
printjson(db.adminCommand({ balancerStatus: 1 }));
print('\n== sh.status ==');
sh.status();
JS

cp "${MONGO_CONF_DIR}/mongodb.conf" "${OUT}/mongodb.conf.$(hostname -s)" || true
"${MONGO_BIN}/mongod" --version > "${OUT}/mongod-version.txt"
find "${OUT}" -type f -exec sha256sum {} \; > "${OUT}/SHA256SUMS"

echo "Backup complete: ${OUT}"
