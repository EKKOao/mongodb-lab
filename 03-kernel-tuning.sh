#!/usr/bin/env bash
set -euo pipefail
source /vagrant/00-env.sh

cat > /etc/security/limits.d/mongodb.conf <<LIMITS
${MONGO_USER} soft nofile 64000
${MONGO_USER} hard nofile 64000
${MONGO_USER} soft nproc 64000
${MONGO_USER} hard nproc 64000
${MONGO_USER} soft fsize unlimited
${MONGO_USER} hard fsize unlimited
${MONGO_USER} soft cpu unlimited
${MONGO_USER} hard cpu unlimited
${MONGO_USER} soft as unlimited
${MONGO_USER} hard as unlimited
LIMITS

cat > /etc/sysctl.d/99-mongodb.conf <<SYSCTL
vm.swappiness=1
net.core.somaxconn=65535
net.ipv4.tcp_keepalive_time=120
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_keepalive_probes=8
SYSCTL

sysctl -p /etc/sysctl.d/99-mongodb.conf || true

cat > /etc/systemd/system/disable-transparent-hugepages.service <<'SERVICE'
[Unit]
Description=Disable Transparent Huge Pages for MongoDB
DefaultDependencies=no
After=sysinit.target local-fs.target
Before=mongod.service mongos.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'test -f /sys/kernel/mm/transparent_hugepage/enabled && echo never > /sys/kernel/mm/transparent_hugepage/enabled || true'
ExecStart=/bin/sh -c 'test -f /sys/kernel/mm/transparent_hugepage/defrag && echo never > /sys/kernel/mm/transparent_hugepage/defrag || true'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now disable-transparent-hugepages.service

echo "MongoDB kernel tuning applied."
