#!/usr/bin/env bash
# Central configuration for the MongoDB sharded cluster lab.
# All MongoDB runtime files are kept under /mnt/mongodb/* as requested.

set -euo pipefail

export MONGO_VERSION="8.3.2"
export MONGO_PLATFORM="ubuntu2204"
export MONGO_ARCH="x86_64"
export MONGO_DIST="mongodb-linux-${MONGO_ARCH}-${MONGO_PLATFORM}-${MONGO_VERSION}"
export MONGO_TARBALL_URL="https://fastdl.mongodb.org/linux/${MONGO_DIST}.tgz"

# MongoDB Shell and Database Tools are released separately from MongoDB Server.
export MONGOSH_VERSION="2.8.3"
export MONGOSH_TARBALL_URL="https://downloads.mongodb.com/compass/mongosh-${MONGOSH_VERSION}-linux-x64.tgz"
export MONGO_TOOLS_VERSION="100.15.0"
export MONGO_TOOLS_TARBALL_URL="https://fastdl.mongodb.org/tools/db/mongodb-database-tools-${MONGO_PLATFORM}-${MONGO_ARCH}-${MONGO_TOOLS_VERSION}.tgz"
export INSTALL_DATABASE_TOOLS="true"

export MONGO_USER="mongodb"
export MONGO_GROUP="mongodb"
export MONGO_UID="1124"
export MONGO_GID="1124"

export MONGO_BASE="/mnt/mongodb"
export MONGO_HOME="${MONGO_BASE}/home"
export MONGO_DATA="${MONGO_BASE}/data"
export MONGO_LOG="${MONGO_BASE}/log"
export MONGO_BACKUP="${MONGO_BASE}/backup"
export MONGO_BIN="${MONGO_HOME}/bin"
export MONGO_CONF_DIR="${MONGO_HOME}/conf"
export MONGO_SECURITY_DIR="${MONGO_HOME}/security"
export MONGO_TLS_DIR="${MONGO_HOME}/tls"
export MONGO_RUN_DIR="/run/mongodb"

export CONFIG_RS="cfgRS"
export SHARD1_RS="shard01RS"
export SHARD2_RS="shard02RS"

export CONFIG_PORT="27019"
export SHARD_PORT="27018"
export MONGOS_PORT="27017"

export CLUSTER_CIDR_PREFIX="192.168.57"
export DOMAIN="lab.local"

export CONFIG_NODES="cfg1:192.168.57.11 cfg2:192.168.57.12 cfg3:192.168.57.13"
export SHARD1_NODES="shard1a:192.168.57.21 shard1b:192.168.57.22 shard1c:192.168.57.23"
export SHARD2_NODES="shard2a:192.168.57.31 shard2b:192.168.57.32 shard2c:192.168.57.33"
export MONGOS_NODES="mongos1:192.168.57.41 mongos2:192.168.57.42"
export ALL_NODES="${CONFIG_NODES} ${SHARD1_NODES} ${SHARD2_NODES} ${MONGOS_NODES}"

export ADMIN_USER="clusterAdmin"
export ADMIN_SECRET_FILE="/vagrant/secrets/mongodb/admin_password"
export KEYFILE_SHARED="/vagrant/secrets/mongodb/mongodb-keyfile"
export KEYFILE_LOCAL="${MONGO_SECURITY_DIR}/mongodb-keyfile"

export CA_KEY_SHARED="/vagrant/secrets/mongodb/ca.key"
export CA_CRT_SHARED="/vagrant/secrets/mongodb/ca.crt"
export LOCAL_CA="${MONGO_TLS_DIR}/ca.crt"
export LOCAL_CERT_KEY="${MONGO_TLS_DIR}/mongodb.pem"
export TLS_REQUIRE_CLIENT_CERT="false"

# WiredTiger cache sizes are intentionally small for a laptop lab.
export CONFIG_WT_CACHE_GB="0.25"
export SHARD_WT_CACHE_GB="0.50"

hostname_short() { hostname -s; }

node_ip() {
  ip -4 addr show | awk -v p="${CLUSTER_CIDR_PREFIX}" '$1 == "inet" && $2 ~ p { split($2,a,"/"); print a[1]; exit }'
}

node_role() {
  local h="$(hostname_short)"
  case "$h" in
    cfg1|cfg2|cfg3) echo "config" ;;
    shard1a|shard1b|shard1c) echo "shard1" ;;
    shard2a|shard2b|shard2c) echo "shard2" ;;
    mongos1|mongos2) echo "mongos" ;;
    *) echo "unknown" ;;
  esac
}

node_port() {
  case "$(node_role)" in
    config) echo "${CONFIG_PORT}" ;;
    shard1|shard2) echo "${SHARD_PORT}" ;;
    mongos) echo "${MONGOS_PORT}" ;;
    *) echo "27017" ;;
  esac
}

configdb_string() {
  echo "${CONFIG_RS}/cfg1:${CONFIG_PORT},cfg2:${CONFIG_PORT},cfg3:${CONFIG_PORT}"
}

shard1_string() {
  echo "${SHARD1_RS}/shard1a:${SHARD_PORT},shard1b:${SHARD_PORT},shard1c:${SHARD_PORT}"
}

shard2_string() {
  echo "${SHARD2_RS}/shard2a:${SHARD_PORT},shard2b:${SHARD_PORT},shard2c:${SHARD_PORT}"
}

mongosh_common_tls_args() {
  echo "--tls --tlsCAFile ${LOCAL_CA} --tlsAllowInvalidHostnames"
}

admin_password() {
  cat "${ADMIN_SECRET_FILE}"
}
