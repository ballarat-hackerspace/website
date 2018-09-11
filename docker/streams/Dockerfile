FROM debian

WORKDIR /streams
ENTRYPOINT ["./bhack-streamsd"]

RUN set -x \
  && apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-downgrades git libtext-multimarkdown-perl libyaml-tiny-perl libdbd-sqlite3-perl cpanminus make \
  && git clone https://github.com/ballarat-hackerspace/website /streams \
  && mkdir /data \
  && mkdir /conf \
  && cp /streams/conf/bhackd.conf.sample /conf/bhackd.conf

RUN ["cpanm", "Mojolicious"]
