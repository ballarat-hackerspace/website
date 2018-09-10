FROM debian

EXPOSE 3000
WORKDIR /website
ENTRYPOINT ["./bhackd"]
CMD ["prefork"]

RUN set -x \
  && apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-downgrades git libtext-multimarkdown-perl libyaml-tiny-perl libdbd-sqlite3-perl libio-socket-ssl-perl libnetaddr-ip-perl cpanminus make \
  && git clone https://github.com/ballarat-hackerspace/website /website \
  && mkdir /data \
  && mkdir /conf \
  && cp /website/conf/bhackd.conf.sample /conf/bhackd.conf

RUN ["cpanm", "Mojolicious"]
