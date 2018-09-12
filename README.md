[![Build Status](https://travis-ci.org/ballarat-hackerspace/website.svg?branch=master)](https://travis-ci.org/ballarat-hackerspace/website)

Ballarat Hackerspace (bhack) website written using the Mojolicious framework.

Now with an integrated MQTT service providing an enriched IoT experience for our
members and those learning IoT fundamentals and machine to machine
communications.

There are three primary components to the bhack website:
  - website,
  - mqtt broker, and
  - mqtt/streams persistence daemon

## Configuring for the server in the space (Debian / Jessie):

```
# apt-get install git libmojolicious-perl libtext-multimarkdown-perl libyaml-tiny-perl libdbd-sqlite3-perl libnetaddr-ip-perl
# cp conf/bhackd.service /etc/systemd/system
# systemctl --system daemon-reload
# systemctl start bhack.service
# systemctl enable bhack.service
```

## Running a test instance

### The docker way

To build an image for a particular component see the specific README in the
`docker` subdirectory.

Before starting the services it is imoprtant to generate an appropriate `.env`
file. An example is shown below.

```
BHACKD_MOSQUITTO_PORT=1883
BHACKD_WEBSITE_PORT=10001
BHACKD_CONFIG=/conf/bhackd.conf
```

Once created you can build/start all the docker containers via:

```
$ docker-compose up
```

### The non docker way

Firstly ensure you have the required dependencies:
 - libmojolicious-perl
 - libtext-multimarkdown-perl
 - libyaml-tiny-perl
 - libdbd-sqlite3-perl, and
 - libnetaddr-ip-perl

If you're testing on a remote machine forward port 3000 via ssh (or open access
through firewall) and run:

```
$ ./bhackd prefork
```

Then browse to `http://localhost:3000/` (replace `localhost` as appropriate if
you're running the test instance on another server).

