# -*- mode: ruby -*-
PACKAGING_GPG_SIGNING_KEY = ENV["PACKAGING_GPG_SIGNING_KEY"]
PKG_VERSION = ENV.fetch("PKG_VERSION", "1.0.0-beta.2")
MOANA_TAG = ENV.fetch("MOANA_TAG", "1.0.0-beta.2")
GLUSTERFS_BRANCH = ENV.fetch("GLUSTERFS_BRANCH", "kadalu_1")
MAJOR_VERSION = "1"
DISTRO_VERSION = "22.04"
DISTRO = "ubuntu"

containers = [
  "kadalu_ubuntu_builder_amd64",
  "kadalu_ubuntu_builder_arm64"
]

# Configuration: Set STDOUT printing messages and
# the remote plugin
EMIT_STDOUT true
USE_REMOTE_PLUGIN "docker"

# Cleanup: Stop and delete all the running
# containers and then cleanup and recreate the
# build directory.
RUN "docker stop #{containers[0]}"
RUN "docker rm #{containers[0]}"
RUN "docker stop #{containers[1]}"
RUN "docker rm #{containers[1]}"
RUN "rm -rf build"
RUN "mkdir build"

# Clone GlusterFS repo
TEST "git clone https://github.com/kadalu/glusterfs.git build/glusterfs"

# Clone Moana repo
TEST "git clone https://github.com/kadalu/moana.git build/moana"

# Run amd64 container
TEST %{docker run -d --name #{containers[0]}                              \
              -e PACKAGING_GPG_SIGNING_KEY="#{PACKAGING_GPG_SIGNING_KEY}" \
              --entrypoint "/usr/bin/tail" ubuntu:22.04 -f /dev/null}

# Run arm64 container using Qemu
TEST "docker run --rm --privileged multiarch/qemu-user-static --reset -p yes"
TEST %{docker run -d --name #{containers[1]}                              \
              -e PACKAGING_GPG_SIGNING_KEY="#{PACKAGING_GPG_SIGNING_KEY}" \
              --entrypoint "/usr/bin/tail" arm64v8/ubuntu:22.04 -f /dev/null}

# List the running container
TEST "docker ps"

containers.each do |container|
  USE_NODE "local"
  # Copy the sources, script and checkout the required branches
  TEST %{docker cp changelogs #{container}:/root/}
  TEST "docker cp build #{container}:/root/"

  USE_NODE container

  TEST "apt-get update -y && apt-get install -y curl gnupg2 ca-certificates"

  # Install Crystal
  TEST "curl -s https://packagecloud.io/install/repositories/84codes/crystal/script.deb.sh | bash"
  TEST "apt-get install -y crystal"

  # Install dependencies in both the containers
  TEST "apt-get install -y libunwind-dev"
  TEST %{apt-get install -y --no-install-recommends python3 libtirpc3 init     \
        python3-pip ssh rsync lvm2 less software-properties-common             \
        sudo curl wget git build-essential automake autoconf automake libtool  \
        flex bison libssl-dev pkg-config uuid-dev acl-dev zlib1g-dev           \
        libxml2-dev libxml2-utils liburcu-dev xfsprogs gdb attr                \
        libgoogle-perftools-dev zfsutils-linux screen libsqlite3-dev sqlite3   \
        debmake python3-debian debhelper dh-python apt-utils                   \
        libaio-dev libdb-dev libfuse-dev libibverbs-dev liblvm2-dev            \
        libncurses5-dev librdmacm-dev libreadline-dev python3-all-dev libglib2.0-dev}

  # Build Moana
  pkg1 = "kadalu-storage-manager-#{PKG_VERSION}"
  TEST "cd /root/build/moana && git checkout -b #{MOANA_TAG} tags/#{MOANA_TAG}"
  TEST "mv /root/build/moana /root/build/#{pkg1}"
  TEST "cd /root/build/ && tar cvzf #{pkg1}.tar.gz #{pkg1}"
  TEST "cp /root/changelogs/moana/changelog-#{MAJOR_VERSION} /root/build/#{pkg1}/packaging/moana/debian/changelog"
  TEST "cp -r /root/build/#{pkg1}/packaging/moana/debian /root/build/#{pkg1}/"
  TEST "cd /root/build/#{pkg1} && debmake -b\":python3\" && debuild -eVERSION=#{PKG_VERSION}"

  # Build GlusterFS
  pkg2 = "kadalu-storage-#{PKG_VERSION}"
  TEST "cd /root/build/glusterfs && git checkout -b #{GLUSTERFS_BRANCH} origin/#{GLUSTERFS_BRANCH}"
  TEST "mv /root/build/glusterfs /root/build/#{pkg2}"
  TEST "cd /root/build/ && tar cvzf #{pkg2}.tar.gz #{pkg2}"
  TEST "cp /root/changelogs/glusterfs/changelog-#{MAJOR_VERSION} /root/build/#{pkg1}/packaging/glusterfs/debian/changelog"
  # Copy debian directory from moana repo to build root of respective package
  TEST "cp -r /root/build/#{pkg1}/packaging/glusterfs/debian /root/build/#{pkg2}/"
  TEST "cd /root/build/#{pkg2} && debmake -b\":python3\" && debuild -eVERSION=#{PKG_VERSION}"
end

USE_NODE containers[0]
TEST "mkdir /root/packages"
TEST "cp /root/build/*.ddeb /root/packages/"
TEST "cp /root/build/*.deb /root/packages/"

USE_NODE "local"

# Copy the deb files to one container
TEST "rm -rf ./tmp && mkdir ./tmp"
TEST "docker cp #{containers[1]}:/root/build ./tmp/"
TEST "mv ./tmp/build/*.deb ./tmp/"
TEST "mv ./tmp/build/*.ddeb ./tmp/"
TEST "rm -rf ./tmp/build"
TEST "docker cp ./tmp/. #{containers[0]}:/root/packages/"

USE_NODE containers[0]
TEST "ls /root/packages"
TEST "cd /root/packages && dpkg-scanpackages --multiversion . > Packages"
TEST "cd /root/packages && gzip -k -f Packages"

# Import the Signing key from env var
TEST "echo -n \"#{PACKAGING_GPG_SIGNING_KEY}\" | base64 --decode | gpg --import"
TEST "gpg --list-keys"

# Release, Release.gpg & InRelease
TEST "cd /root/packages && apt-ftparchive release . > Release"
TEST "cd /root/packages && gpg --local-user \"packaging@kadalu.tech\" -abs -o - Release > Release.gpg"
TEST "cd /root/packages && gpg --local-user \"packaging@kadalu.tech\" --clearsign -o - Release > InRelease"
TEST "cd /root/packages && gpg --armor --export \"packaging@kadalu.tech\" > KEY.gpg"
TEST "echo \"deb https://kadalu.tech/pkgs/#{MAJOR_VERSION}/#{DISTRO}/#{DISTRO_VERSION} ./\" > sources.list"

USE_NODE "local"

# Clone the existing output directory
TEST "rm -rf ./output"
TEST "git clone https://github.com/kadalu-tech/pkgs.git output"
TEST "cd output && git checkout -b gh-pages origin/gh-pages"
TEST "rm -rf output/#{MAJOR_VERSION}/#{DISTRO}/#{DISTRO_VERSION}"
TEST "mkdir -p output/#{MAJOR_VERSION}/#{DISTRO}/#{DISTRO_VERSION}"
TEST "docker cp #{containers[0]}:/root/packages/. output/#{MAJOR_VERSION}/#{DISTRO}/#{DISTRO_VERSION}/"
TEST "rm -rf output/.git*"
TEST "chmod -R 777 output/#{MAJOR_VERSION}/#{DISTRO}/#{DISTRO_VERSION}/*"
TEST "ls output/#{MAJOR_VERSION}/#{DISTRO}/#{DISTRO_VERSION}/"
