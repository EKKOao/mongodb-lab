#!/usr/bin/env bash
set -euo pipefail
source /vagrant/00-env.sh

MONGOSH="${MONGO_BIN}/mongosh"
PASS="$(admin_password)"
TLS_ARGS=(--tls --tlsCAFile "${LOCAL_CA}" --tlsAllowInvalidHostnames)
AUTH_ARGS=(-u "${ADMIN_USER}" -p "${PASS}" --authenticationDatabase admin)

run_mongosh() {
  local host="$1" port="$2" expr="$3"
  "${MONGOSH}" --quiet "${TLS_ARGS[@]}" "${AUTH_ARGS[@]}" --host "$host" --port "$port" --eval "$expr"
}

echo "== MongoDB binary versions =="
"${MONGO_BIN}/mongod" --version | head -n 1
"${MONGO_BIN}/mongos" --version | head -n 1
"${MONGOSH}" --version

echo

echo "== Auth material sanity =="
echo "Admin user: ${ADMIN_USER}"
echo "Password file: ${ADMIN_SECRET_FILE}"
echo "Password length: $(wc -c < "${ADMIN_SECRET_FILE}" | tr -d ' ') bytes including newline"
echo "CA file: ${LOCAL_CA}"

echo

echo "== Sharded cluster health through mongos1 =="
"${MONGOSH}" --quiet "${TLS_ARGS[@]}" "${AUTH_ARGS[@]}" --host mongos1 --port "${MONGOS_PORT}" <<'JS'
const admin = db.getSiblingDB('admin');
print('ping:');
printjson(admin.runCommand({ ping: 1 }));
print('\ncurrent user:');
printjson(db.runCommand({ connectionStatus: 1, showPrivileges: false }).authInfo.authenticatedUsers);
print('\nlistShards:');
printjson(admin.runCommand({ listShards: 1 }));
print('\nbalancerStatus:');
printjson(admin.runCommand({ balancerStatus: 1 }));
print('\nsh.status():');
sh.status();
JS

echo

echo "== Replica set summaries =="
for target in "cfg1:${CONFIG_PORT}" "shard1a:${SHARD_PORT}" "shard2a:${SHARD_PORT}"; do
  host="${target%%:*}"
  port="${target##*:}"
  echo "-- ${target} --"
  run_mongosh "$host" "$port" 'const s=rs.status(); print(s.set + " primary=" + s.members.filter(m=>m.stateStr==="PRIMARY").map(m=>m.name).join(",") + " members=" + s.members.length);'
done

echo

echo "== Final result =="
echo "MongoDB sharded cluster health check completed successfully."
