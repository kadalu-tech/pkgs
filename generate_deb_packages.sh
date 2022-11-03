#!/bin/bash

set -e

MOANA_BRANCH=1.0.0-beta.2
GLUSTERFS_BRANCH=kadalu_1
DISTRO_VERSION=20.04
DISTRO=ubuntu
VERSION=1.0.0-beta.2
MAJOR_VERSION=1
PKG_KADALU_STORAGE_MANAGER=kadalu-storage-manager
PKG_KADALU_STORAGE=kadalu-storage

rm -rf build
mkdir -p build

# Clone and Checkout GlusterFS
git clone https://github.com/kadalu/glusterfs.git build/${PKG_KADALU_STORAGE}-${VERSION}
cd build/${PKG_KADALU_STORAGE}-${VERSION}
git checkout -b ${GLUSTERFS_BRANCH} origin/${GLUSTERFS_BRANCH}
cd ../../

# Clone and Checkout Moana
git clone https://github.com/kadalu/moana.git build/${PKG_KADALU_STORAGE_MANAGER}-${VERSION}
cd build/${PKG_KADALU_STORAGE_MANAGER}-${VERSION}
git fetch --all --tags
git checkout -b ${MOANA_BRANCH} tags/${MOANA_BRANCH}
cd ../../

# Create tar
cd build/
tar cvzf ${PKG_KADALU_STORAGE_MANAGER}-${VERSION}.tar.gz ${PKG_KADALU_STORAGE_MANAGER}-${VERSION}
tar cvzf ${PKG_KADALU_STORAGE}-${VERSION}.tar.gz ${PKG_KADALU_STORAGE}-${VERSION}
cd ..

# Copy Debian meta files
cp -r build/${PKG_KADALU_STORAGE_MANAGER}-${VERSION}/packaging/moana/debian build/${PKG_KADALU_STORAGE_MANAGER}-${VERSION}/
cp -r build/${PKG_KADALU_STORAGE_MANAGER}-${VERSION}/packaging/glusterfs/debian build/${PKG_KADALU_STORAGE}-${VERSION}/

# Overwrite the Changelog file
cp changelogs/moana/changelog-${MAJOR_VERSION} build/${PKG_KADALU_STORAGE_MANAGER}-${VERSION}/debian/changelog
cp changelogs/glusterfs/changelog-${MAJOR_VERSION} build/${PKG_KADALU_STORAGE}-${VERSION}/debian/changelog

# Build Moana deb packages
cd build/${PKG_KADALU_STORAGE_MANAGER}-${VERSION}/
debmake -b":python3"
debuild -eVERSION=${VERSION}
cd ../../

# Build GlusterFS deb packages
cd build/${PKG_KADALU_STORAGE}-${VERSION}/
debmake -b":python3"
debuild
cd ../../

# Clone the existing repo and checkout gh-pages to get the current output directory
git clone https://github.com/kadalu-tech/pkgs.git build/output
cd build/output
git checkout -b gh-pages origin/gh-pages
cd ../../

rm -rf output
mkdir output
# TODO: Add previous versions when a new version is released
cp -r build/output/${MAJOR_VERSION} output/${MAJOR_VERSION}

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
