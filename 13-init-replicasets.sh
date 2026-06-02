#!/usr/bin/env bash
set -euo pipefail
source /vagrant/00-env.sh
source "${MONGO_CONF_DIR}/node.env"

cat > /usr/local/sbin/mongodb-init-replicaset.sh <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
source /vagrant/00-env.sh
source "${MONGO_CONF_DIR}/node.env"

HOST="${MONGO_NODE_HOST}"
MONGOSH="${MONGO_BIN}/mongosh"
TLS_ARGS=(--tls --tlsCAFile "${LOCAL_CA}" --tlsAllowInvalidHostnames)
FLAG_DIR="${MONGO_HOME}/state"
mkdir -p "${FLAG_DIR}"
chown "${MONGO_USER}:${MONGO_GROUP}" "${FLAG_DIR}" || true

log() { echo "[$(date -Is)] $*"; }

tcp_wait() {
  local host="$1" port="$2" max="${3:-180}" i=0
  until timeout 2 bash -c "</dev/tcp/${host}/${port}" >/dev/null 2>&1; do
    i=$((i+1))
    if [ "$i" -gt "$max" ]; then
      log "ERROR: timeout waiting for TCP ${host}:${port}"
      return 1
    fi
    sleep 2
  done
}

mongo_eval_noauth_or_auth() {
  local host="$1" port="$2" expr="$3"
  if "${MONGOSH}" --quiet "${TLS_ARGS[@]}" --host "$host" --port "$port" --eval "$expr"; then
    return 0
  fi

  if [ -f "${ADMIN_SECRET_FILE}" ]; then
    local pass
    pass="$(admin_password)"
    "${MONGOSH}" --quiet "${TLS_ARGS[@]}" \
      -u "${ADMIN_USER}" -p "$pass" --authenticationDatabase admin \
      --host "$host" --port "$port" --eval "$expr"
    return $?
  fi

  return 1
}

mongo_file_noauth_or_auth() {
  local host="$1" port="$2" file="$3"
  if "${MONGOSH}" --quiet "${TLS_ARGS[@]}" --host "$host" --port "$port" "$file"; then
    return 0
  fi

  if [ -f "${ADMIN_SECRET_FILE}" ]; then
    local pass
    pass="$(admin_password)"
    "${MONGOSH}" --quiet "${TLS_ARGS[@]}" \
      -u "${ADMIN_USER}" -p "$pass" --authenticationDatabase admin \
      --host "$host" --port "$port" "$file"
    return $?
  fi

  return 1
}

wait_for_primary() {
  local host="$1" port="$2" name="$3" max=240 i=0
  until mongo_eval_noauth_or_auth "$host" "$port" 'db.hello().isWritablePrimary' 2>/dev/null | grep -q true; do
    i=$((i+1))
    if [ "$i" -gt "$max" ]; then
      log "ERROR: timeout waiting for primary on ${name} via ${host}:${port}"
      return 1
    fi
    sleep 2
  done
  log "Primary is available for ${name}."
}

ensure_local_admin_user() {
  local host="$1" port="$2" label="$3"
  local flag="${FLAG_DIR}/${label}.admin-user-created"
  [ -f "$flag" ] && { log "${label} admin user already created according to flag."; return 0; }

  local pass
  pass="$(admin_password)"

  cat > "/tmp/create-admin-${label}.js" <<JS
const admin = db.getSiblingDB('admin');
let existingUser = null;
try {
  existingUser = admin.getUser('${ADMIN_USER}');
} catch (e) {
  print('getUser without auth failed or user absent: ' + e.message);
}

if (!existingUser) {
  print('Creating local/admin user ${ADMIN_USER} on ${label}');
  admin.createUser({
    user: '${ADMIN_USER}',
    pwd: '${pass}',
    roles: [ { role: 'root', db: 'admin' } ]
  });
} else {
  print('Admin user already exists on ${label}: ${ADMIN_USER}');
}
JS

  # This first tries the localhost exception. If the user already exists, it falls back to auth.
  mongo_file_noauth_or_auth "$host" "$port" "/tmp/create-admin-${label}.js"

  # Prove the credential works before setting the flag.
  "${MONGOSH}" --quiet "${TLS_ARGS[@]}" \
    -u "${ADMIN_USER}" -p "$pass" --authenticationDatabase admin \
    --host "$host" --port "$port" --eval 'db.getSiblingDB("admin").runCommand({ ping: 1 })' >/dev/null

  touch "$flag"
  chown "${MONGO_USER}:${MONGO_GROUP}" "$flag" || true
  log "Admin credential verified for ${label}."
}

init_config_rs() {
  local flag="${FLAG_DIR}/${CONFIG_RS}.initiated"

  for h in cfg1 cfg2 cfg3; do tcp_wait "$h" "${CONFIG_PORT}" 180; done

  if [ ! -f "$flag" ]; then
    cat > /tmp/init-cfgRS.js <<JS
try {
  const status = rs.status();
  print('Config replica set already initialized: ' + status.set);
} catch (e) {
  print('Initializing config server replica set ${CONFIG_RS}');
  rs.initiate({
    _id: '${CONFIG_RS}',
    configsvr: true,
    members: [
      { _id: 0, host: 'cfg1:${CONFIG_PORT}' },
      { _id: 1, host: 'cfg2:${CONFIG_PORT}' },
      { _id: 2, host: 'cfg3:${CONFIG_PORT}' }
    ]
  });
}
JS
    mongo_file_noauth_or_auth 127.0.0.1 "${CONFIG_PORT}" /tmp/init-cfgRS.js
    touch "$flag"
    chown "${MONGO_USER}:${MONGO_GROUP}" "$flag" || true
    log "${CONFIG_RS} initiation complete."
  else
    log "${CONFIG_RS} already initiated according to flag."
  fi

  wait_for_primary 127.0.0.1 "${CONFIG_PORT}" "${CONFIG_RS}"
  # The sharded-cluster user data is stored on the config servers. Creating this
  # user here makes mongos authentication deterministic once mongos starts.
  ensure_local_admin_user 127.0.0.1 "${CONFIG_PORT}" "${CONFIG_RS}"
}

init_shard_rs() {
  local rsname="$1" port="$2" n1="$3" n2="$4" n3="$5"
  local flag="${FLAG_DIR}/${rsname}.initiated"

  for h in "$n1" "$n2" "$n3"; do tcp_wait "$h" "$port" 180; done

  if [ ! -f "$flag" ]; then
    cat > "/tmp/init-${rsname}.js" <<JS
try {
  const status = rs.status();
  print('Shard replica set already initialized: ' + status.set);
} catch (e) {
  print('Initializing shard replica set ${rsname}');
  rs.initiate({
    _id: '${rsname}',
    members: [
      { _id: 0, host: '${n1}:${port}' },
      { _id: 1, host: '${n2}:${port}' },
      { _id: 2, host: '${n3}:${port}' }
    ]
  });
}
JS
    mongo_file_noauth_or_auth 127.0.0.1 "$port" "/tmp/init-${rsname}.js"
    touch "$flag"
    chown "${MONGO_USER}:${MONGO_GROUP}" "$flag" || true
    log "${rsname} initiation complete."
  else
    log "${rsname} already initiated according to flag."
  fi

  wait_for_primary 127.0.0.1 "$port" "$rsname"
  # Shard-local users are separate from mongos users and are required for direct
  # maintenance/health checks against shard replica sets.
  ensure_local_admin_user 127.0.0.1 "$port" "$rsname"
}

case "${HOST}" in
  cfg1)
    init_config_rs
    ;;
  shard1a)
    init_shard_rs "${SHARD1_RS}" "${SHARD_PORT}" shard1a shard1b shard1c
    ;;
  shard2a)
    init_shard_rs "${SHARD2_RS}" "${SHARD_PORT}" shard2a shard2b shard2c
    ;;
  *)
    log "Replica set initiation is coordinated only from cfg1, shard1a, and shard2a. This node is ${HOST}; exiting."
    ;;
esac
SCRIPT
chmod 0755 /usr/local/sbin/mongodb-init-replicaset.sh

cat > /etc/systemd/system/mongodb-init-replicaset.service <<'UNIT'
[Unit]
Description=Initialize MongoDB replica set for this node role
After=network-online.target mongod.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/mongodb-init-replicaset.sh
UNIT

cat > /etc/systemd/system/mongodb-init-replicaset.timer <<'UNIT'
[Unit]
Description=Retry MongoDB replica set initialization until cluster peers are ready

[Timer]
OnBootSec=45s
OnUnitActiveSec=30s
Persistent=true

[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
systemctl enable --now mongodb-init-replicaset.timer

echo "Replica set initialization timer installed on ${MONGO_NODE_HOST}."
