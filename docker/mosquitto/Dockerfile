FROM debian

WORKDIR /mosquitto
ENTRYPOINT ["./bhackd-streams"]
CMD ["prefork"]

RUN set -x \
  && apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-downgrades mosquitto

COPY bhackd-streams /website-streams/
RUN set -x \
  && cp /website/bhackd.conf.sample /conf/bhackd.conf
