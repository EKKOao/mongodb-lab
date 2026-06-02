#!/usr/bin/env bash
set -euo pipefail
source /vagrant/00-env.sh
source "${MONGO_CONF_DIR}/node.env"

cat > /usr/local/sbin/mongodb-bootstrap-sharded-cluster.sh <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
source /vagrant/00-env.sh
source "${MONGO_CONF_DIR}/node.env"

if [ "${MONGO_NODE_HOST}" != "mongos1" ]; then
  echo "[$(date -Is)] Sharded cluster bootstrap is coordinated from mongos1 only. This node is ${MONGO_NODE_HOST}; exiting."
  exit 0
fi

MONGOSH="${MONGO_BIN}/mongosh"
TLS_ARGS=(--tls --tlsCAFile "${LOCAL_CA}" --tlsAllowInvalidHostnames)
PASS="$(admin_password)"
AUTH_ARGS=(-u "${ADMIN_USER}" -p "${PASS}" --authenticationDatabase admin)
FLAG_DIR="${MONGO_HOME}/state"
FLAG="${FLAG_DIR}/sharded-cluster.bootstrapped"
mkdir -p "${FLAG_DIR}"
[ -f "${FLAG}" ] && { echo "[$(date -Is)] Sharded cluster already bootstrapped according to flag."; exit 0; }

log() { echo "[$(date -Is)] $*"; }

tcp_wait() {
  local host="$1" port="$2" max="${3:-240}" i=0
  until timeout 2 bash -c "</dev/tcp/${host}/${port}" >/dev/null 2>&1; do
    i=$((i+1))
    if [ "$i" -gt "$max" ]; then
      log "ERROR: timeout waiting for TCP ${host}:${port}"
      return 1
    fi
    sleep 2
  done
}

mongo_eval_auth() {
  local host="$1" port="$2" expr="$3"
  "${MONGOSH}" --quiet "${TLS_ARGS[@]}" "${AUTH_ARGS[@]}" \
    --host "$host" --port "$port" --eval "$expr"
}

mongo_file_auth() {
  local host="$1" port="$2" file="$3"
  "${MONGOSH}" --quiet "${TLS_ARGS[@]}" "${AUTH_ARGS[@]}" \
    --host "$host" --port "$port" "$file"
}

wait_for_primary_auth() {
  local host="$1" port="$2" name="$3" max=240 i=0
  until mongo_eval_auth "$host" "$port" 'db.hello().isWritablePrimary' 2>/dev/null | grep -q true; do
    i=$((i+1))
    if [ "$i" -gt "$max" ]; then
      log "ERROR: timeout waiting for primary/auth on ${name} via ${host}:${port}"
      return 1
    fi
    sleep 2
  done
  log "Primary/auth is available for ${name}."
}

# Wait for all mongod/mongos TCP listeners. Vagrant provisions nodes sequentially,
# so this script is intentionally timer-driven and retry-safe.
for target in \
  "cfg1:${CONFIG_PORT}" "cfg2:${CONFIG_PORT}" "cfg3:${CONFIG_PORT}" \
  "shard1a:${SHARD_PORT}" "shard1b:${SHARD_PORT}" "shard1c:${SHARD_PORT}" \
  "shard2a:${SHARD_PORT}" "shard2b:${SHARD_PORT}" "shard2c:${SHARD_PORT}" \
  "mongos1:${MONGOS_PORT}" "mongos2:${MONGOS_PORT}"; do
  tcp_wait "${target%%:*}" "${target##*:}" 240
done

# The admin user is created deterministically by cfg1 on the config server RS,
# and shard-local users are created by shard1a/shard2a for direct maintenance.
wait_for_primary_auth cfg1 "${CONFIG_PORT}" "${CONFIG_RS}"
wait_for_primary_auth shard1a "${SHARD_PORT}" "${SHARD1_RS}"
wait_for_primary_auth shard2a "${SHARD_PORT}" "${SHARD2_RS}"

# Prove mongos accepts the cluster admin user before adding shards.
mongo_eval_auth 127.0.0.1 "${MONGOS_PORT}" 'db.getSiblingDB("admin").runCommand({ ping: 1 })' >/dev/null
log "mongos1 authentication verified for ${ADMIN_USER}."

cat > /tmp/bootstrap-sharded-cluster.js <<JS
const admin = db.getSiblingDB('admin');

function ensureShard(name, conn) {
  const result = admin.runCommand({ listShards: 1 });
  if (!result.ok) {
    throw new Error('listShards failed: ' + tojson(result));
  }
  const shards = result.shards || [];
  if (!shards.some(s => s._id === name)) {
    print('Adding shard ' + name + ': ' + conn);
    const addResult = sh.addShard(conn);
    printjson(addResult);
  } else {
    print('Shard already present: ' + name);
  }
}

ensureShard('${SHARD1_RS}', '$(shard1_string)');
ensureShard('${SHARD2_RS}', '$(shard2_string)');

printjson(admin.runCommand({ listShards: 1 }));
printjson(admin.runCommand({ balancerStatus: 1 }));
JS

mongo_file_auth 127.0.0.1 "${MONGOS_PORT}" /tmp/bootstrap-sharded-cluster.js

touch "${FLAG}"
chown "${MONGO_USER}:${MONGO_GROUP}" "${FLAG}"
log "Sharded cluster bootstrap completed."
SCRIPT
chmod 0755 /usr/local/sbin/mongodb-bootstrap-sharded-cluster.sh

cat > /etc/systemd/system/mongodb-bootstrap-sharded-cluster.service <<'UNIT'
[Unit]
Description=Bootstrap MongoDB sharded cluster through mongos1
After=network-online.target mongos.service mongodb-init-replicaset.timer
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/mongodb-bootstrap-sharded-cluster.sh
UNIT

cat > /etc/systemd/system/mongodb-bootstrap-sharded-cluster.timer <<'UNIT'
[Unit]
Description=Retry MongoDB sharded cluster bootstrap until all replica sets are ready

[Timer]
OnBootSec=90s
OnUnitActiveSec=30s
Persistent=true

[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
systemctl enable --now mongodb-bootstrap-sharded-cluster.timer

echo "Sharded cluster bootstrap timer installed on ${MONGO_NODE_HOST}."
