#!/bin/bash

set -e

MOANA_BRANCH=0.5.5
GLUSTERFS_BRANCH=kadalu_1
DISTRO_VERSION=20.04
DISTRO=ubuntu
VERSION=0.5.5
MAJOR_VERSION=0

rm -rf build
mkdir -p build

# Clone and Checkout GlusterFS
git clone https://github.com/kadalu/glusterfs.git build/glusterfs-${VERSION}
cd build/glusterfs-${VERSION}
git checkout -b ${GLUSTERFS_BRANCH} origin/${GLUSTERFS_BRANCH}
cd ../../

# Clone and Checkout Moana
git clone https://github.com/kadalu/moana.git build/moana-${VERSION}
cd build/moana-${VERSION}
git fetch --all --tags
git checkout -b ${MOANA_BRANCH} tags/${MOANA_BRANCH}
cd ../../

# Create tar
cd build/
tar cvzf moana-${VERSION}.tar.gz moana-${VERSION}
tar cvzf glusterfs-${VERSION}.tar.gz glusterfs-${VERSION}
cd ..

# Copy Debian meta files
cp -r build/moana-${VERSION}/packaging/moana/debian build/moana-${VERSION}/
cp -r build/moana-${VERSION}/packaging/glusterfs/debian build/glusterfs-${VERSION}/

# Overwrite the Changelog file
cp changelogs/moana/changelog-${VERSION} build/moana-${VERSION}/debian/changelog
cp changelogs/glusterfs/changelog-${VERSION} build/glusterfs-${VERSION}/debian/changelog

# Build Moana deb packages
cd build/moana-${VERSION}/
debmake -b":python3"
debuild -eVERSION=${VERSION}
cd ../../

# Build GlusterFS deb packages
cd build/glusterfs-${VERSION}/
debmake -b":python3"
debuild
cd ../../

# TODO: Clone the existing repo and checkout gh-pages to get the current output directory
output_dir=output/${MAJOR_VERSION}/${DISTRO}/${DISTRO_VERSION}
rm -rf ${output_dir}
mkdir -p ${output_dir}

# Copy generated Deb files
cp build/*.deb ${output_dir}/

# List of packages
cd ${output_dir}
dpkg-scanpackages --multiversion . > Packages
gzip -k -f Packages

# Import the Signing key from env var
echo -n "$PACKAGING_GPG_SIGNING_KEY" | base64 --decode | gpg --import
gpg --list-keys

# Release, Release.gpg & InRelease
apt-ftparchive release . > Release
gpg --local-user "packaging@kadalu.tech" -abs -o - Release > Release.gpg
gpg --local-user "packaging@kadalu.tech" --clearsign -o - Release > InRelease
gpg --armor --export "packaging@kadalu.tech" > KEY.gpg

echo "deb https://kadalu.tech/pkgs/${MAJOR_VERSION}/${DISTRO}/${DISTRO_VERSION} ./" > sources.list
cd ../../../../
