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

If you're testing on a remote machine forward port 3000 via ssh (or open access through firewall) and
run:

```
$ ./bhackd prefork
```

Then browse to `http://localhost:3000/` (replace `localhost` as appropriate if you're running the
test instance on another server).
