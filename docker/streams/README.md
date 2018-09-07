# Website - Streams

## Production

If you wish to build an image from what is already committed to github
(ignoring any changes in your source tree):

```
$ docker build -t bhack-website .
$ docker run \
  --name=bhack-website-streams \
  --restart=unless-stopped \
  -v /srv/ballarathackerspace.org.au/conf:/conf \
  -e BHACKD_CONFIG=/data/bhackd.conf \
  -e TZ=Australia/Melbourne \
  -d bhack-website-streams:$TAG
```
