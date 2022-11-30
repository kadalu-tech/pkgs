# -*- mode: ruby -*-
EMIT_STDOUT true
USE_REMOTE_PLUGIN "docker"
nodes = ["server1", "server2", "server3"]

# Start three or N storage nodes(Containers)
USE_NODE "local"
nodes.each do |node|
  USE_NODE "local"
  RUN "docker stop amd-#{node}"
  RUN "docker rm amd-#{node}"
  RUN "docker stop arm-#{node}"
  RUN "docker rm arm-#{node}"
end

RUN "docker network rm k1"
TEST "docker network create k1"

nodes.each do |node|
  USE_NODE "local"
  TEST "docker run -d -v /sys/fs/cgroup/:/sys/fs/cgroup:ro --privileged --name amd-#{node} --hostname #{node} --network k1 kadalu-amd/storage-node-testing"
  TEST "docker run --rm --privileged multiarch/qemu-user-static --reset -p yes"
  TEST "docker run -d -v /sys/fs/cgroup/:/sys/fs/cgroup:ro --privileged --name arm-#{node} --hostname #{node} --network k1 kadalu-arm/storage-node-testing"
end
