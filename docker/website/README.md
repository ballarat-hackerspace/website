# Website

## Development

To build an image from your checked out and modified source tree:

```
$ docker build -t bhack-website-dev -f Dockerfile.dev .
$ docker run --rm -it -p 3000:3000 bhack-website-dev
```

### Fedora

```
$ docker run \
  --name=bhack-website-dev
  --rm -it \
  -p 3000:3000 \
  -v $(pwd)/conf:/conf:z \
  -v $(pwd)/data:/data:z \
  -v $(pwd)/blog:/blog:z \
  -e BHACKD_CONFIG=/conf/bhackd.conf.dev
```

Now browse to port 3000. If you wish to use a different local port change the
left hand 3000 to the port of your choice.


## Production

If you wish to build an image from what is already committed to github
(ignoring any changes in your source tree):

```
$ docker build -t bhack-website .
$ docker run \
  --name=bhack-website \
  --restart=unless-stopped \
  -v /srv/ballarathackerspace.org.au/conf:/conf \
  -v /srv/ballarathackerspace.org.au/data:/data \
  -v /srv/ballarathackerspace.org.au/blog:/blog \
  -p $PORT:3000 \
  -e BHACKD_CONFIG=/data/bhackd.conf \
  -e TZ=Australia/Melbourne \
  -d bhack-website:$TAG
```
