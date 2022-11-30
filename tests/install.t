# -*- mode: ruby -*-

EMIT_STDOUT true
USE_REMOTE_PLUGIN "docker"
nodes = ["amd-server1", "amd-server2", "amd-server3", "arm-server1", "arm-server2", "arm-server3"]

# Install Kadalu Storage
nodes.each do |node|
  USE_NODE node
  TEST "echo 'deb https://kadalu.tech/pkgs/1.0.x/ubuntu/22.04 /' | sudo tee /etc/apt/sources.list.d/kadalu.list"
  TEST "curl -fsSL https://kadalu.tech/pkgs/1.0.x/ubuntu/22.04/KEY.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/kadalu.gpg > /dev/null"
  TEST "apt update -y"
  TEST "apt install -y kadalu-storage"
end

# Sanity test
USE_NODE nodes[0]
puts TEST "kadalu version"
