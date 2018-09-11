FROM debian

EXPOSE 1883

ENTRYPOINT ["/usr/sbin/mosquitto", "-c", "/conf/mosquitto.conf"]

RUN set -x \
  && apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-downgrades mosquitto \
  && mkdir /conf \
  && touch /conf/mosquitto.conf
