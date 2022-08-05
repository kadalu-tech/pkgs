FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -yq &&                                                 \
    apt-get install -y --no-install-recommends sudo curl apt-utils        \
      init gnupg wget ca-certificates python3-pip

RUN echo "root:kadalu" | chpasswd

RUN systemctl mask getty.target

cmd ["/usr/sbin/init"]