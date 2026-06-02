#!/usr/bin/env bash
set -euo pipefail
source /vagrant/00-env.sh

SUDO_FILE="/etc/sudoers.d/mongodb"
cat > "${SUDO_FILE}" <<SUDOERS
${MONGO_USER} ALL=(root) NOPASSWD: /usr/bin/systemctl start mongod.service
${MONGO_USER} ALL=(root) NOPASSWD: /usr/bin/systemctl stop mongod.service
${MONGO_USER} ALL=(root) NOPASSWD: /usr/bin/systemctl restart mongod.service
${MONGO_USER} ALL=(root) NOPASSWD: /usr/bin/systemctl status mongod.service
${MONGO_USER} ALL=(root) NOPASSWD: /usr/bin/systemctl start mongos.service
${MONGO_USER} ALL=(root) NOPASSWD: /usr/bin/systemctl stop mongos.service
${MONGO_USER} ALL=(root) NOPASSWD: /usr/bin/systemctl restart mongos.service
${MONGO_USER} ALL=(root) NOPASSWD: /usr/bin/systemctl status mongos.service
${MONGO_USER} ALL=(root) NOPASSWD: /usr/bin/journalctl -u mongod.service *
${MONGO_USER} ALL=(root) NOPASSWD: /usr/bin/journalctl -u mongos.service *
SUDOERS
chmod 0440 "${SUDO_FILE}"
visudo -cf "${SUDO_FILE}"
