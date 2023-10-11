# -*- mode: ruby -*-

EMIT_STDOUT true
USE_REMOTE_PLUGIN "docker"
nodes = ["amd-server1", "amd-server2", "amd-server3", "arm-server1", "arm-server2", "arm-server3"]

nodes.each do |node|
  USE_NODE node
  RUN "systemctl stop kadalu-mgr"
  RUN "systemctl disable kadalu-mgr"
  RUN "rm -rf /var/lib/kadalu"
end
