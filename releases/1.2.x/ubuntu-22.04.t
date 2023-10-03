# -*- mode: ruby -*-
PACKAGING_GPG_SIGNING_KEY = ENV["PACKAGING_GPG_SIGNING_KEY"]
PKG_VERSION = ENV["PKG_VERSION"]
MOANA_TAG = PKG_VERSION
GLUSTERFS_TAG = "k#{PKG_VERSION}"
GANESHA_TAG = "V3.5"
VERSION_DIR = "#{PKG_VERSION.split(".")[0]}.#{PKG_VERSION.split(".")[1]}.x"
DISTRO_VERSION = "22.04"
DISTRO = "ubuntu"
CHANGELOGS_DIR = "/root/changelogs"
BUILD_DIR = "/root/build"
PACKAGING_FILES_DIR = "#{BUILD_DIR}/packaging"

containers = [
  "kadalu_ubuntu_builder_amd64",
  "kadalu_ubuntu_builder_arm64"
]

# Configuration: Set STDOUT printing messages and
# the remote plugin
EMIT_STDOUT true
USE_REMOTE_PLUGIN "docker"
EXIT_ON_NOT_OK true

# Cleanup: Stop and delete all the running
# containers and then cleanup and recreate the
# build directory.
containers.each do |container|
  RUN "docker stop #{container}"
  RUN "docker rm #{container}"
end

RUN "rm -rf build"
RUN "mkdir build"

# Clone GlusterFS repo
TEST "git clone https://github.com/kadalu/glusterfs.git build/glusterfs"

# Clone Moana repo
TEST "git clone https://github.com/kadalu/moana.git build/moana"

# Copy packaging dir to build directory
TEST "cp -r build/moana/packaging build/packaging"
TEST "mv build/packaging/nfs-ganesha-kadalu build/packaging/nfs-ganesha"

# TODO: Remove below line after the line removed from repo control file
TEST "sed -i /dh-systemd/d build/packaging/nfs-ganesha/debian/control"

# Clone nfs-ganesha repo
TEST "git clone https://github.com/kadalu/nfs-ganesha.git build/nfs-ganesha"

# Run amd64 container
TEST %{docker run -d --name #{containers[0]}                              \
              -e PACKAGING_GPG_SIGNING_KEY="#{PACKAGING_GPG_SIGNING_KEY}" \
              --entrypoint "/usr/bin/tail" ubuntu:22.04 -f /dev/null}

# Run arm64 container using Qemu
if containers.size > 1
  TEST "docker run --rm --privileged multiarch/qemu-user-static --reset -p yes"
  TEST %{docker run -d --name #{containers[1]}                              \
              -e PACKAGING_GPG_SIGNING_KEY="#{PACKAGING_GPG_SIGNING_KEY}" \
              --entrypoint "/usr/bin/tail" arm64v8/ubuntu:22.04 -f /dev/null}
end

# List the running container
TEST "docker ps"

def build_deb_package(source_dir, tag, name, version)
  pkg = "#{name}-#{version}"
  src_name = File.basename source_dir
  TEST "cd #{source_dir} && git checkout -b #{tag} tags/#{tag}"
  TEST "mv #{source_dir} #{BUILD_DIR}/#{pkg}"
  TEST "cd #{BUILD_DIR} && tar cvzf #{pkg}.tar.gz #{pkg}"
  TEST "mkdir -p #{PACKAGING_FILES_DIR}/#{src_name}/debian/"
  TEST "cp /root/changelogs/#{src_name} #{PACKAGING_FILES_DIR}/#{src_name}/debian/changelog"
  # Copy debian directory from moana repo to build root of respective package
  TEST "cp -r #{PACKAGING_FILES_DIR}/#{src_name}/debian #{BUILD_DIR}/#{pkg}/"
  TEST "cd #{BUILD_DIR}/#{pkg} && sed -i '3s/, dh-systemd//' debian/control"
  TEST "cd #{BUILD_DIR}/#{pkg} && debmake -b\":python3\" && debuild -eVERSION=#{version}"
end

def install_dependencies
  TEST "apt-get update -y && apt-get install -y curl gnupg2 ca-certificates"

  # Install Crystal
  TEST "curl -s https://packagecloud.io/install/repositories/84codes/crystal/script.deb.sh | bash"
  TEST "apt-get install -y crystal"

  TEST "apt-get install -y libunwind-dev"
  TEST %{DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
        apt-get install -y --no-install-recommends python3 libtirpc3 init     \
        python3-pip ssh rsync lvm2 less software-properties-common             \
        sudo curl wget git build-essential automake autoconf automake libtool  \
        flex bison libssl-dev uuid-dev acl-dev zlib1g-dev           \
        libxml2-dev libxml2-utils liburcu-dev xfsprogs gdb attr                \
        libgoogle-perftools-dev zfsutils-linux screen libsqlite3-dev sqlite3   \
        debmake python3-debian debhelper dh-python apt-utils pkgconf           \
        libaio-dev libdb-dev libfuse-dev libibverbs-dev liblvm2-dev            \
        libncurses5-dev librdmacm-dev libreadline-dev python3-all-dev libglib2.0-dev \
        cmake doxygen libcap-dev libcephfs-dev libdbus-1-dev libkrb5-dev liblttng-ctl-dev \
        liblttng-ust-dev libnfsidmap-dev librados-dev librgw-dev \
        libwbclient-dev lttng-tools nfs-ganesha pyqt5-dev-tools python3-pyqt5 \
        python3-sphinx quilt xfslibs-dev libntirpc-dev nfs-ganesha
}
end

containers.each do |container|
  USE_NODE "local"
  # Copy the sources, script and checkout the required branches
  TEST %{docker cp releases/#{VERSION_DIR}/changelogs #{container}:/root/}
  TEST "docker cp build #{container}:/root/"

  USE_NODE container

  install_dependencies

  # Build Moana
  build_deb_package "/root/build/moana", MOANA_TAG, "kadalu-storage-manager", PKG_VERSION

  # Build GlusterFS
  build_deb_package "/root/build/glusterfs", GLUSTERFS_TAG, "kadalu-storage", PKG_VERSION

  arch = container.split("_")[-1]
  TEST "apt install -y /root/build/kadalu-storage-manager_#{PKG_VERSION}-1_#{arch}.deb"
  TEST "apt install -y /root/build/kadalu-storage_#{PKG_VERSION}-1_#{arch}.deb"
  # Build NFS Ganesha Kadalu
  build_deb_package "/root/build/nfs-ganesha", GANESHA_TAG, "nfs-ganesha-kadalu", PKG_VERSION
end

USE_NODE containers[0]
TEST "mkdir /root/packages"
TEST "cp /root/build/*.ddeb /root/packages/"
TEST "cp /root/build/*.deb /root/packages/"

USE_NODE "local"

# Copy the deb files to one container
TEST "rm -rf ./tmp && mkdir ./tmp"
if containers.size > 1
  TEST "docker cp #{containers[1]}:/root/build ./tmp/"
  TEST "mv ./tmp/build/*.deb ./tmp/"
  TEST "mv ./tmp/build/*.ddeb ./tmp/"
end

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
TEST "echo \"deb https://kadalu.tech/pkgs/#{VERSION_DIR}/#{DISTRO}/#{DISTRO_VERSION} ./\" > sources.list"

USE_NODE "local"

# Clone the existing output directory
TEST "rm -rf ./output"
TEST "git clone https://github.com/kadalu-tech/pkgs.git output"
TEST "cd output && git checkout -b gh-pages origin/gh-pages"
TEST "rm -rf output/#{VERSION_DIR}/#{DISTRO}/#{DISTRO_VERSION}"
TEST "mkdir -p output/#{VERSION_DIR}/#{DISTRO}/#{DISTRO_VERSION}"
TEST "docker cp #{containers[0]}:/root/packages/. output/#{VERSION_DIR}/#{DISTRO}/#{DISTRO_VERSION}/"
TEST "rm -rf output/.git*"
TEST "chmod -R 777 output/#{VERSION_DIR}/#{DISTRO}/#{DISTRO_VERSION}/*"
TEST "ls output/#{VERSION_DIR}/#{DISTRO}/#{DISTRO_VERSION}/"
