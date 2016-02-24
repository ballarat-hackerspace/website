[![Build Status](https://travis-ci.org/ballarat-hackerspace/website.svg?branch=master)](https://travis-ci.org/ballarat-hackerspace/website)

Ballarat Hackerspace website written with for Mojolicious framework.

## Configuring for the server in the space (Debian / Jessie):

```
# apt-get install git libmojolicious-perl libtext-multimarkdown-perl libyaml-tiny-perl libdbd-sqlite3-perl libnetaddr-ip-perl
# cp conf/bhackd.service /etc/systemd/system
# systemctl --system daemon-reload
# systemctl start bhack.service
# systemctl enable bhack.service
```

## Running a test instance

### The non docker way

Firstly ensure you have the required dependencies (libmojolicious-perl
libtext-multimarkdown-perl libyaml-tiny-perl libdbd-sqlite3-perl
libnetaddr-ip-perl)

If you're testing on a remote machine forward port 3000 via ssh (or open access
through firewall) and run:

```
$ ./bhackd prefork
```

Then browse to `http://localhost:3000/` (replace `localhost` as appropriate if
you're running the test instance on another server).

### The docker way

To build an image from your checked out and modified source tree:

```
$ docker build -t bhack-website .
$ docker run --rm -it -p 3000:3000 bhack-website
```

Now browse to port 3000. If you wish to use a different local port change the
left hand 3000 to the port of your choice.

If you wish to build an image from what is already committed to github
(ignoring any changes in your source tree):

```
$ docker build -t bhack-website-git -f Dockerfile.git .
$ docker run --rm -it -p 3000:3000 bhack-website-git
```

