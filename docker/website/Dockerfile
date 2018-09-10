FROM debian

EXPOSE 3000
WORKDIR /website
ENTRYPOINT ["./bhackd"]
CMD ["prefork"]

RUN set -x \
  && apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes git libtext-multimarkdown-perl libyaml-tiny-perl libdbd-sqlite3-perl libio-socket-ssl-perl libnetaddr-ip-perl cpanminus make \
  && mkdir /{conf,data} \
  && git clone https://github.com/ballarat-hackerspace/website /website \
  && cp /website/conf/bhackd.conf.sample /conf/bhackd.conf

RUN ["cpanm", "Mojolicious"]
