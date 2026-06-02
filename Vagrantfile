# -*- mode: ruby -*-
# vi: set ft=ruby :

# Production-style MongoDB sharded cluster lab
# 3 config servers + 2 shard replica sets x 3 members + 2 mongos routers = 11 VMs

MONGO_NODES = [
  { name: "cfg1",    ip: "192.168.57.11", role: "config", mem: 1024, cpus: 1, disk: "30GB" },
  { name: "cfg2",    ip: "192.168.57.12", role: "config", mem: 1024, cpus: 1, disk: "30GB" },
  { name: "cfg3",    ip: "192.168.57.13", role: "config", mem: 1024, cpus: 1, disk: "30GB" },

  { name: "shard1a", ip: "192.168.57.21", role: "shard1", mem: 1536, cpus: 1, disk: "40GB" },
  { name: "shard1b", ip: "192.168.57.22", role: "shard1", mem: 1536, cpus: 1, disk: "40GB" },
  { name: "shard1c", ip: "192.168.57.23", role: "shard1", mem: 1536, cpus: 1, disk: "40GB" },

  { name: "shard2a", ip: "192.168.57.31", role: "shard2", mem: 1536, cpus: 1, disk: "40GB" },
  { name: "shard2b", ip: "192.168.57.32", role: "shard2", mem: 1536, cpus: 1, disk: "40GB" },
  { name: "shard2c", ip: "192.168.57.33", role: "shard2", mem: 1536, cpus: 1, disk: "40GB" },

  { name: "mongos1", ip: "192.168.57.41", role: "mongos", mem: 1024, cpus: 1, disk: "20GB" },
  { name: "mongos2", ip: "192.168.57.42", role: "mongos", mem: 1024, cpus: 1, disk: "20GB" }
]

PROVISION_SCRIPTS = [
  "01-packages.sh",
  "02-user.sh",
  "03-kernel-tuning.sh",
  "04-storage.sh",
  "05-swap.sh",
  "06-network.sh",
  "07-install-binary.sh",
  "08-certs.sh",
  "09-keyfile.sh",
  "10-admin-secret.sh",
  "11-config.sh",
  "12-service.sh",
  "13-init-replicasets.sh",
  "14-bootstrap-sharded-cluster.sh",
  "15-sudoers.sh"
]

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.box_check_update = false

  MONGO_NODES.each do |node|
    config.vm.define node[:name] do |mongo|
      mongo.vm.hostname = node[:name]
      mongo.vm.network "private_network", ip: node[:ip]

      mongo.vm.provider "virtualbox" do |vb|
        vb.name = node[:name]
        vb.memory = node[:mem]
        vb.cpus = node[:cpus]
      end

      # Dedicated MongoDB disk. Requires Vagrant's built-in disk support.
      mongo.vm.disk :disk, size: node[:disk], name: "#{node[:name]}_mongodb_data"

      mongo.vm.provision "shell", inline: "set -e; test -f /vagrant/00-env.sh; mkdir -p /vagrant/secrets/mongodb /vagrant/backups/mongodb"

      PROVISION_SCRIPTS.each do |script|
        mongo.vm.provision "shell", inline: "set -e; test -f /vagrant/#{script}; bash /vagrant/#{script}"
      end
    end
  end
end
