#!/usr/bin/env bash
set -euo pipefail
source /vagrant/00-env.sh
source "${MONGO_CONF_DIR}/node.env"

ROLE="${MONGO_NODE_ROLE}"
CONF="${MONGO_CONF_DIR}/mongodb.conf"
SERVICE_NAME="mongod"
BIN="${MONGO_BIN}/mongod"
LOGFILE="${MONGO_LOG}/mongodb.log"

if [ "${ROLE}" = "mongos" ]; then
  SERVICE_NAME="mongos"
  BIN="${MONGO_BIN}/mongos"
  LOGFILE="${MONGO_LOG}/mongos.log"
fi

cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<SERVICE
[Unit]
Description=MongoDB ${ROLE} service
Documentation=https://www.mongodb.com/docs/manual/
After=network-online.target disable-transparent-hugepages.service
Wants=network-online.target

[Service]
Type=simple
User=${MONGO_USER}
Group=${MONGO_GROUP}
RuntimeDirectory=mongodb
RuntimeDirectoryMode=0750
WorkingDirectory=${MONGO_HOME}
ExecStartPre=+/bin/mkdir -p ${MONGO_RUN_DIR} ${MONGO_DATA} ${MONGO_LOG} ${MONGO_BACKUP}
ExecStartPre=+/bin/chown -R ${MONGO_USER}:${MONGO_GROUP} ${MONGO_RUN_DIR} ${MONGO_BASE}
ExecStart=${BIN} --config ${CONF}
Restart=always
RestartSec=5
LimitNOFILE=64000
LimitNPROC=64000
TasksMax=infinity
TimeoutStartSec=120
TimeoutStopSec=120
KillSignal=SIGTERM
UMask=0027

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
if [ "${SERVICE_NAME}" = "mongod" ]; then
  systemctl disable --now mongos.service >/dev/null 2>&1 || true
else
  systemctl disable --now mongod.service >/dev/null 2>&1 || true
fi
systemctl enable "${SERVICE_NAME}.service"

set +e
systemctl restart "${SERVICE_NAME}.service"
restart_rc=$?
sleep 5
systemctl is-active --quiet "${SERVICE_NAME}.service"
active_rc=$?
set -e

if [ "$restart_rc" -ne 0 ] || [ "$active_rc" -ne 0 ]; then
  echo "MongoDB service failed or did not become active. Status follows:"
  systemctl status "${SERVICE_NAME}.service" --no-pager || true
  echo "MongoDB journal follows:"
  journalctl -u "${SERVICE_NAME}.service" --no-pager -n 120 || true
  echo "MongoDB log follows:"
  tail -n 120 "${LOGFILE}" || true
  echo "MongoDB config follows:"
  sed -n '1,220p' "${CONF}" || true
  exit 1
fi

systemctl status "${SERVICE_NAME}.service" --no-pager | sed -n '1,14p'
