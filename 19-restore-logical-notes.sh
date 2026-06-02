#!/usr/bin/env bash
set -euo pipefail
source /vagrant/00-env.sh

cat <<'NOTES'
Logical restore example for a lab backup produced by 18-backup-logical.sh:

  PASS=$(sudo cat /vagrant/secrets/mongodb/admin_password)
  BACKUP_DIR=/mnt/mongodb/backup/logical-YYYYMMDDTHHMMSSZ/dump

  /mnt/mongodb/home/bin/mongorestore \
    --uri "mongodb://clusterAdmin:${PASS}@mongos1:27017/admin?tls=true&tlsCAFile=/mnt/mongodb/home/tls/ca.crt&tlsAllowInvalidHostnames=true" \
    --drop \
    "${BACKUP_DIR}"

For production-size sharded clusters, prefer filesystem or block-level snapshots coordinated across:
  - config server replica set
  - every shard replica set
  - cluster metadata

MongoDB's own docs recommend mongodump/mongorestore mainly for small deployments and filesystem/block snapshots for resilient non-disruptive backups.
NOTES
