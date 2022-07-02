FROM ubuntu:20.04

ARG S6_OVERLAY_VERSION=v2.2.0.3
ARG S6_OVERLAY_ARCH=amd64
ARG PLEX_BUILD=linux-x86_64
ARG PLEX_DISTRO=debian
ARG DEBIAN_FRONTEND="noninteractive"
ARG INTEL_COMPUTE_RUNTIME_VERSION=22.26.23599
ENV TERM="xterm" LANG="C.UTF-8" LC_ALL="C.UTF-8"

ENTRYPOINT ["/init"]

RUN \
# Update and get dependencies
    apt-get update && \
    apt-get install -y \
      tzdata \
      jq \
      curl \
      xmlstarlet \
      uuid-runtime \
      unrar \
      beignet-opencl-icd \
      ocl-icd-libopencl1 \
    && \
    \
# Fetch and extract S6 overlay
    curl -J -L -o /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.gz https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.gz && \
    tar xzf /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.gz -C / --exclude='./bin' && \
    tar xzf /tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.gz -C /usr ./bin && \
    \
# Add user
    useradd -U -d /config -s /bin/false plex && \
    usermod -G users plex && \
    \
# Setup directories
    mkdir -p \
      /config \
      /transcode \
      /data \
    && \
    \
# Cleanup
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* && \
    rm -rf /var/tmp/*

# Fetch and install Intel Compute Runtime and its deps
RUN INTEL_URLS=$(curl -fsSL "https://api.github.com/repos/intel/compute-runtime/releases/tags/${INTEL_COMPUTE_RUNTIME_VERSION}" | jq -r '.body' | grep wget | sed 's|wget ||g') && \
    mkdir -p /intel && \
    for i in ${INTEL_URLS}; do \
        i=$(echo ${i} | tr -d '\r'); \
        curl -o "/intel/$(basename ${i})" -L "${i}"; \
    done && \
    dpkg -i /intel/*.deb && \
    rm -rf /intel

EXPOSE 32400/tcp 8324/tcp 32469/tcp 1900/udp 32410/udp 32412/udp 32413/udp 32414/udp
VOLUME /config /transcode

ENV CHANGE_CONFIG_DIR_OWNERSHIP="true" \
    HOME="/config"

ARG TAG=beta
ARG URL=

COPY root/ /

RUN \
# Save version and install
    /installBinary.sh

HEALTHCHECK --interval=5s --timeout=2s --retries=20 CMD /healthcheck.sh || exit 1
