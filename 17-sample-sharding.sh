#!/usr/bin/env bash
set -euo pipefail
source /vagrant/00-env.sh

MONGOSH="${MONGO_BIN}/mongosh"
PASS="$(admin_password)"
TLS_ARGS=(--tls --tlsCAFile "${LOCAL_CA}" --tlsAllowInvalidHostnames)
AUTH_ARGS=(-u "${ADMIN_USER}" -p "${PASS}" --authenticationDatabase admin)

"${MONGOSH}" --quiet "${TLS_ARGS[@]}" "${AUTH_ARGS[@]}" --host mongos1 --port "${MONGOS_PORT}" <<'JS'
const admin = db.getSiblingDB('admin');
print('Creating sample sharded database and collection...');
sh.enableSharding('appdb');
const app = db.getSiblingDB('appdb');
app.users.createIndex({ tenantId: 1, userId: 1 });
sh.shardCollection('appdb.users', { tenantId: 1, userId: 1 });
for (let i = 0; i < 1000; i++) {
  app.users.updateOne(
    { tenantId: i % 20, userId: i },
    { $set: { tenantId: i % 20, userId: i, name: 'user-' + i, createdAt: new Date() } },
    { upsert: true }
  );
}
printjson(app.users.countDocuments());
printjson(admin.runCommand({ listShards: 1 }));
print('Sample sharding complete.');
JS
