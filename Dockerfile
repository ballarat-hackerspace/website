FROM debian

EXPOSE 3000
WORKDIR /website
ENTRYPOINT ["./bhackd"]
CMD ["prefork"]

RUN set -x \
  && apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes git libmojolicious-perl libtext-multimarkdown-perl libyaml-tiny-perl libdbd-sqlite3-perl libnetaddr-ip-perl 

COPY . /website/
RUN set -x \
  && cp /website/bhackd.conf.sample /etc/bhackd.conf
