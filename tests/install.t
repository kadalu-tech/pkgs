# -*- mode: ruby -*-

USE_REMOTE_PLUGIN "docker"
nodes = ["server1", "server2", "server3"]

# Install Kadalu Storage
nodes.each do |node|
  USE_NODE node
  TEST "wget -qO- https://kadalu.tech/pkgs/1/ubuntu/20.04/KEY.gpg | sudo tee kadalu_storage.gpg"
  TEST "apt-key add kadalu_storage.gpg"
  TEST "wget -qO /etc/apt/sources.list.d/kadalu_storage.list https://kadalu.tech/pkgs/1/ubuntu/20.04/sources.list"
  TEST "apt update -y"
  TEST "apt install -y kadalu-storage"
end

# Sanity test
USE_NODE nodes[0]
puts TEST "kadalu version"
