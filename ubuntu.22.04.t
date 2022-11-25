# -*- mode: ruby -*-
PACKAGING_GPG_SIGNING_KEY = ENV["PACKAGING_GPG_SIGNING_KEY"]

USE_REMOTE_PLUGIN "docker"
EMIT_STDOUT true

container_name = "ubuntu_2204_pkgs_builder"

# Run the container
RUN %{docker stop #{container_name}}
RUN %{docker rm #{container_name}}
TEST %{docker run -d --name #{container_name} -e PACKAGING_GPG_SIGNING_KEY=#{PACKAGING_GPG_SIGNING_KEY} --entrypoint "/usr/bin/tail" 84codes/crystal:1.6.2-ubuntu-22.04 -f /dev/null}

TEST %{docker cp generate_deb_packages_ubuntu_2204.sh #{container_name}:/root/}
TEST %{docker cp changelogs #{container_name}:/root/}

# Run
USE_NODE container_name
TEST "apt update -y"
TEST "apt install -y libunwind-dev"
TEST %{apt install -y --no-install-recommends python3 libtirpc3 init     \
        python3-pip ssh rsync lvm2 less software-properties-common             \
        sudo curl wget git build-essential automake autoconf automake libtool  \
        flex bison libssl-dev pkg-config uuid-dev acl-dev zlib1g-dev           \
        libxml2-dev libxml2-utils liburcu-dev xfsprogs gdb attr                \
        libgoogle-perftools-dev zfsutils-linux screen libsqlite3-dev sqlite3   \
        debmake python3-debian debhelper dh-python                             \
        libaio-dev libdb-dev libfuse-dev libibverbs-dev liblvm2-dev            \
        libncurses5-dev librdmacm-dev libreadline-dev python3-all-dev libglib2.0-dev}

TEST "cd /root && bash -x generate_deb_packages_ubuntu_2204.sh"

USE_NODE "local"

TEST "git clone https://github.com/kadalu-tech/pkgs.git build/output"
TEST "cd build/output && git checkout -b gh-pages origin/gh-pages"

TEST "rm -rf output && mkdir output"
# TODO: Add previous versions when a new version is released
TEST "cp -r build/output/1 output/1"
TEST "rm -rf output/1/ubuntu/22.04 && mkdir -p output/1/ubuntu"
TEST "docker cp #{container_name}:/root/output/1/ubuntu/22.04 output/1/ubuntu/"
