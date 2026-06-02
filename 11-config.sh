#!/usr/bin/env bash
set -euo pipefail
source /vagrant/00-env.sh
source "${MONGO_CONF_DIR}/node.env"

ROLE="${MONGO_NODE_ROLE}"
HOST="${MONGO_NODE_HOST}"
IP="${MONGO_NODE_IP}"
PORT="${MONGO_NODE_PORT}"
CONF="${MONGO_CONF_DIR}/mongodb.conf"
PIDFILE="${MONGO_RUN_DIR}/mongodb.pid"

mkdir -p "${MONGO_CONF_DIR}" "${MONGO_DATA}" "${MONGO_LOG}" "${MONGO_BACKUP}" "${MONGO_RUN_DIR}"

TLS_CLIENT_CERT_LINE="allowConnectionsWithoutCertificates: true"
if [ "${TLS_REQUIRE_CLIENT_CERT}" = "true" ]; then
  TLS_CLIENT_CERT_LINE="allowConnectionsWithoutCertificates: false"
fi

common_header() {
cat <<YAML
# Managed by Vagrant provisioning. Edit 00-env.sh and rerun 11-config.sh for deterministic changes.
processManagement:
  fork: false
  pidFilePath: ${PIDFILE}

systemLog:
  destination: file
  path: ${MONGO_LOG}/mongodb.log
  logAppend: true
  verbosity: 0

net:
  port: ${PORT}
  bindIp: 127.0.0.1,${IP},${HOST},${HOST}.${DOMAIN}
  maxIncomingConnections: 20000
  tls:
    mode: requireTLS
    certificateKeyFile: ${LOCAL_CERT_KEY}
    CAFile: ${LOCAL_CA}
    ${TLS_CLIENT_CERT_LINE}

security:
  keyFile: ${KEYFILE_LOCAL}
  authorization: enabled

setParameter:
  enableLocalhostAuthBypass: true
YAML
}

case "${ROLE}" in
  config)
    cat > "${CONF}" <<YAML
$(common_header)

storage:
  dbPath: ${MONGO_DATA}
  wiredTiger:
    engineConfig:
      cacheSizeGB: ${CONFIG_WT_CACHE_GB}

replication:
  replSetName: ${CONFIG_RS}

sharding:
  clusterRole: configsvr

operationProfiling:
  mode: slowOp
  slowOpThresholdMs: 100
YAML
    ;;

  shard1)
    cat > "${CONF}" <<YAML
$(common_header)

storage:
  dbPath: ${MONGO_DATA}
  wiredTiger:
    engineConfig:
      cacheSizeGB: ${SHARD_WT_CACHE_GB}

replication:
  replSetName: ${SHARD1_RS}

sharding:
  clusterRole: shardsvr

operationProfiling:
  mode: slowOp
  slowOpThresholdMs: 100
YAML
    ;;

  shard2)
    cat > "${CONF}" <<YAML
$(common_header)

storage:
  dbPath: ${MONGO_DATA}
  wiredTiger:
    engineConfig:
      cacheSizeGB: ${SHARD_WT_CACHE_GB}

replication:
  replSetName: ${SHARD2_RS}

sharding:
  clusterRole: shardsvr

operationProfiling:
  mode: slowOp
  slowOpThresholdMs: 100
YAML
    ;;

  mongos)
    cat > "${CONF}" <<YAML
# Managed by Vagrant provisioning. Edit 00-env.sh and rerun 11-config.sh for deterministic changes.
processManagement:
  fork: false
  pidFilePath: ${PIDFILE}

systemLog:
  destination: file
  path: ${MONGO_LOG}/mongos.log
  logAppend: true
  verbosity: 0

net:
  port: ${PORT}
  bindIp: 127.0.0.1,${IP},${HOST},${HOST}.${DOMAIN}
  maxIncomingConnections: 20000
  tls:
    mode: requireTLS
    certificateKeyFile: ${LOCAL_CERT_KEY}
    CAFile: ${LOCAL_CA}
    ${TLS_CLIENT_CERT_LINE}

security:
  keyFile: ${KEYFILE_LOCAL}

sharding:
  configDB: $(configdb_string)
YAML
    ;;

  *)
    echo "ERROR: unknown MongoDB node role ${ROLE}" >&2
    exit 1
    ;;
esac

chown -R "${MONGO_USER}:${MONGO_GROUP}" "${MONGO_CONF_DIR}" "${MONGO_DATA}" "${MONGO_LOG}" "${MONGO_BACKUP}" "${MONGO_RUN_DIR}"
chmod 750 "${MONGO_CONF_DIR}" "${MONGO_DATA}" "${MONGO_LOG}" "${MONGO_BACKUP}"
chmod 640 "${CONF}"

echo "Generated MongoDB config: ${CONF} for role ${ROLE}."
