FROM debian

EXPOSE 1883
WORKDIR /website-streams
ENTRYPOINT ["./bhackd-streams"]
CMD ["prefork"]

RUN set -x \
  && apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes git libtext-multimarkdown-perl libyaml-tiny-perl libdbd-sqlite3-perl cpanminus make

RUN ["cpanm", "Mojolicious"]

COPY bhackd-streams /website-streams/
RUN set -x \
  && cp /website/bhackd.conf.sample /etc/bhackd.conf

