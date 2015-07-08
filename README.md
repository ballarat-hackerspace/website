Ballarat Hackerspace website written with for Mojolicious framework.


Configuring for the space (Debian / Jessie):

```
# apt-get install git libmojolicious-perl libtext-multimarkdown-perl libyaml-tiny-perl
# cp conf/bhackd.service /etc/systemd/system
# systemctl --system daemon-reload
# systemctl start bhack.service
# systemctl enable bhack.service
```
