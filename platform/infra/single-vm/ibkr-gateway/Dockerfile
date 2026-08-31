# syntax=docker/dockerfile:1.7

FROM eclipse-temurin:11-jre-jammy

ARG IBKR_GATEWAY_URL=https://download2.interactivebrokers.com/portal/clientportal.gw.zip
ARG IBKR_GATEWAY_SHA256=2f2d380b2f9424520ff5f9c11fe45e82ef39459329ac056258a3274bea6f76f9

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl unzip \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system ibkr \
    && useradd --system --gid ibkr --home-dir /opt/ibkr --shell /usr/sbin/nologin ibkr

WORKDIR /opt/ibkr
RUN curl --fail --location --retry 3 --output /tmp/clientportal.gw.zip "${IBKR_GATEWAY_URL}" \
    && echo "${IBKR_GATEWAY_SHA256}  /tmp/clientportal.gw.zip" | sha256sum --check --strict \
    && unzip -q /tmp/clientportal.gw.zip -d /opt/ibkr \
    && rm /tmp/clientportal.gw.zip \
    && chown -R ibkr:ibkr /opt/ibkr

COPY --chown=ibkr:ibkr conf.yaml /opt/ibkr/root/axio7-conf.yaml

USER ibkr
EXPOSE 5000
CMD ["bin/run.sh", "root/axio7-conf.yaml"]
