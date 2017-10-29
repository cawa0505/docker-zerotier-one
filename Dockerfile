# Dockerfile for ZeroTierOne

FROM alpine:latest as builder

ARG ZT_PKGVER="1.2.4"
ARG ZT_PKGREL="1"

LABEL maintainer="Riadh Habbach <habbachi.riadh@gmail.com>"
LABEL version=$ZT_PKGVER
LABEL description="Containerized ZeroTier One for use on CoreOS or other Docker-only Linux hosts."

# Build deps.
RUN apk add --no-cache --no-progress abuild && \
    apk add --no-cache --no-progress build-base && \
    apk add --no-cache --no-progress gcc binutils

RUN adduser -D abuilder && \
    addgroup abuilder abuild && \
    echo "abuilder    ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER abuilder

ADD ./zerotier-apkbuild /home/abuilder/zerotier-apkbuild/

RUN mkdir -p /var/cache/distfiles && \
    sudo chgrp abuild /var/cache/distfiles && \
    sudo chmod g+w /var/cache/distfiles

WORKDIR /home/abuilder/zerotier-apkbuild/

RUN sudo chown -R abuilder /home/abuilder/zerotier-apkbuild/ && \
    sudo apk update && \
    abuild-keygen -a -i && \
    abuild deps && \
    abuild checksum && \
    abuild -rq -P /home/abuilder/target

FROM alpine:latest as runner

ARG ZT_PKGVER="1.2.4"
ARG ZT_PKGREL="1"

# Install required packages: supervisor, make.
RUN apk add --no-cache --no-progress supervisor && \
    mkdir -p /var/log/supervisor

# Setup supervisord configuration files.
ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY --from=builder /etc/apk/keys /etc/apk/keys
COPY --from=builder /home/abuilder/target/abuilder/*/ /root/zerotierone

RUN cd /root/zerotierone && \
    ls -ali && \
    apk add --no-cache --no-progress zerotier-one-$ZT_PKGVER-$ZT_PKGREL.apk && \
    rm -rf /root/zerotierone

EXPOSE 9993/udp

# Default command when starting the container
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
