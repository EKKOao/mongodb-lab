#!/usr/bin/env bash
set -euo pipefail
source /vagrant/00-env.sh

NODE_IP="$(node_ip)"
if [ -z "${NODE_IP}" ]; then
  echo "ERROR: could not detect ${CLUSTER_CIDR_PREFIX}.0/24 private IP" >&2
  ip addr
  exit 1
fi

mkdir -p "${MONGO_CONF_DIR}"
cat > "${MONGO_CONF_DIR}/node.env" <<ENV
MONGO_NODE_IP=${NODE_IP}
MONGO_NODE_HOST=$(hostname_short)
MONGO_NODE_ROLE=$(node_role)
MONGO_NODE_PORT=$(node_port)
ENV

# Make all cluster hostnames resolvable on every node.
for entry in ${ALL_NODES}; do
  name="${entry%%:*}"
  ip="${entry##*:}"
  if ! grep -qE "[[:space:]]${name}(\.${DOMAIN})?([[:space:]]|$)" /etc/hosts; then
    echo "${ip} ${name} ${name}.${DOMAIN}" >> /etc/hosts
  fi
done

# Optional UFW rules if UFW is active.
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q active; then
  ufw allow from "${CLUSTER_CIDR_PREFIX}.0/24" to any port "${CONFIG_PORT}" proto tcp || true
  ufw allow from "${CLUSTER_CIDR_PREFIX}.0/24" to any port "${SHARD_PORT}" proto tcp || true
  ufw allow from "${CLUSTER_CIDR_PREFIX}.0/24" to any port "${MONGOS_PORT}" proto tcp || true
fi

chown -R "${MONGO_USER}:${MONGO_GROUP}" "${MONGO_CONF_DIR}"
echo "MongoDB node IP: ${NODE_IP}; role: $(node_role); port: $(node_port)"
