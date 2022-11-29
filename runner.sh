#!/bin/bash
version=$1
dist=$2
major_version=$(cut -d "." -f 1 <<< $version)
minor_version=$(cut -d "." -f 2 <<< $version)

FILE=releases/${major_version}.${minor_version}.x/${dist}.t
if [ -f "$FILE" ]; then
    echo "Version: ${version} Runner: ${FILE}"
    PKG_VERSION=${version} PACKAGING_GPG_SIGNING_KEY=${PACKAGING_GPG_SIGNING_KEY} \
               binnacle -v ${FILE}
else
    echo "No runner available for ${version} ${dist}"
fi
