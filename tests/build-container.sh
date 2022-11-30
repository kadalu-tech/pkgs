#!/bin/sh
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
docker buildx build --load --platform=linux/amd64 . --tag kadalu-amd/storage-node-testing -f Dockerfile
docker buildx build --load --platform=linux/arm64 . --tag kadalu-arm/storage-node-testing -f Dockerfile
