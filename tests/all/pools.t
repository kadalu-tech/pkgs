# -*- mode: ruby -*-

load "#{File.dirname(__FILE__)}/../reset.t"

EMIT_STDOUT true
USE_REMOTE_PLUGIN "docker"
nodes = ["#{ENV["ARCH"]}-server1", "#{ENV["ARCH"]}-server2", "#{ENV["ARCH"]}-server3"]

nodes.each do |node|
  USE_NODE node
  TEST "systemctl enable kadalu-mgr"
  TEST "systemctl start kadalu-mgr"
end

USE_NODE nodes[0]
puts TEST "curl -i http://#{ENV["ARCH"]}-server1:3000/ping"
puts TEST "kadalu user create admin --password=kadalu"
puts TEST "kadalu user login admin --password=kadalu"
puts TEST "kadalu pool create DEV"
puts TEST "kadalu pool list"
puts TEST "kadalu pool list --json"
puts TEST "kadalu pool delete DEV --mode=script"
puts TEST "kadalu pool list --json"
puts TEST "kadalu user logout"

nodes.each do |node|
  USE_NODE node
  puts TEST "cat /var/log/kadalu/mgr.log"
end
