FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        firefox-esr \
        icedtea-netx \
        tigervnc-standalone-server \
        novnc \
        websockify \
        openbox \
        tint2 \
        xfonts-base \
        fonts-dejavu-core \
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

USER bmc
WORKDIR /home/bmc

EXPOSE 8080

# tini stays PID 1 and reaps the children Firefox forks for the KVM viewer
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
