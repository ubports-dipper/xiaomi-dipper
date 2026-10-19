FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    android-tools-mkbootimg \
    bc \
    bison \
    build-essential \
    ca-certificates \
    cpio \
    curl \
    fakeroot \
    flex \
    git \
    img2simg \
    jq \
    kmod \
    libelf-dev \
    libssl-dev \
    libtinfo5 \
    lz4 \
    python2 \
    python3 \
    sudo \
    unzip \
    wget \
    xz-utils \
    && ln -sf /usr/bin/python2.7 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
