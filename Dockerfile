# Two images from one file. The default, built from the last stage, runs KVM
# viewers on Debian's icedtea-netx. The java8 target runs them on Java 8 under
# IcedTea-Web's own release, for viewers that need what later Java dropped.

# Unzipped here so that unzip stays out of the java8 image
FROM debian:trixie-slim AS icedtea-web
ARG ICEDTEA_WEB_URL=https://github.com/AdoptOpenJDK/IcedTea-Web/releases/download/icedtea-web-1.8.8/icedtea-web-1.8.8.linux.bin.zip
ARG ICEDTEA_WEB_SHA256=5f7ce19e17637de3576bc7dce9545d229fb635cf5f6f67d19dc85653f21e0778
RUN apt-get update \
    && apt-get install -y --no-install-recommends unzip \
    && rm -rf /var/lib/apt/lists/*
ADD --checksum=sha256:${ICEDTEA_WEB_SHA256} ${ICEDTEA_WEB_URL} /tmp/icedtea-web.zip
RUN unzip -q /tmp/icedtea-web.zip -d /tmp \
    && mv /tmp/icedtea-web-image /opt/icedtea-web

FROM debian:trixie-slim AS base

ENV DEBIAN_FRONTEND=noninteractive

# Japanese for BMCs whose UI and viewer are in it. Not fonts-noto-cjk, which
# adds Chinese and Korean at eight times the size
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        firefox-esr \
        tigervnc-standalone-server \
        novnc \
        websockify \
        openbox \
        tint2 \
        xfonts-base \
        fonts-dejavu-core \
        fonts-ipafont-gothic \
        ca-certificates \
        tini \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash bmc

# Firefox enterprise policies: JNLP handler, no updates, no first-run pages.
# Debian's firefox-esr reads this from its distribution directory, not /etc.
# about:policies says whether the path is still one Firefox reads.
COPY policies.json /usr/lib/firefox-esr/distribution/policies.json

# IcedTea-Web: allow unsigned / self-signed vendor KVM applets.
# Only the per-user path takes effect, so it lives in the bmc home directory.
# itweb-settings get <key> prints the effective values.
COPY deployment.properties /home/bmc/.config/icedtea-web/deployment.properties

# Openbox: start Firefox maximized rather than at its own default size
COPY openbox-rc.xml /home/bmc/.config/openbox/rc.xml

# Entry point for the served site: noVNC ships no index.html, and its defaults
# clip the session and wait for a Connect click.
COPY novnc-index.html /usr/share/novnc/index.html

COPY entrypoint.sh /entrypoint.sh

# Set modes explicitly: the unprivileged user has to read these files,
# and the source tree's modes must not decide whether it can.
RUN chmod 0755 /entrypoint.sh \
    && chmod 0644 /usr/lib/firefox-esr/distribution/policies.json \
                  /usr/share/novnc/index.html \
                  /home/bmc/.config/icedtea-web/deployment.properties \
    && chown -R bmc:bmc /home/bmc/.config

WORKDIR /home/bmc

EXPOSE 8080

# tini stays PID 1 and reaps the children Firefox forks for the KVM viewer
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]

# Not Debian's icedtea-netx: viewers served only as Pack200 archives need it
# unpacked, which Debian's build no longer does, and Java 14 and later cannot.
# Java 9 and later also refuse JVM options such as -XX:PermSize that JNLPs pass
FROM base AS java8
ADD --checksum=sha256:a46d5d3ab75c3c86dddf1bfd2957a067a24b1c6b2d2ed2bc69294bf970c5160b \
    https://packages.adoptium.net/artifactory/api/gpg/key/public /etc/apt/keyrings/adoptium.asc
RUN chmod 0644 /etc/apt/keyrings/adoptium.asc \
    && echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb trixie main" \
        > /etc/apt/sources.list.d/adoptium.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends temurin-8-jre \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
COPY --from=icedtea-web /opt/icedtea-web /opt/icedtea-web
# policies.json hands .jnlp files to this path in either image
RUN ln -s /opt/icedtea-web/bin/javaws /usr/local/bin/javaws
USER bmc

FROM base AS netx
RUN apt-get update \
    && apt-get install -y --no-install-recommends icedtea-netx \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN ln -s /usr/bin/javaws /usr/local/bin/javaws
USER bmc
