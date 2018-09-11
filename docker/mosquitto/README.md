# Ballarat Hackerspace - Mosquitto Docker

## Development

To build an image from your checked out and modified source tree:

```
$ docker build -t bhack-mosquitto-dev -f Dockerfile.dev .
$ docker run --rm -it -p 1883:1883 bhack-mosquitto-dev
```

### Fedora

```
$ docker run \
  --name=bhack-mosquitto-dev
  --rm -it \
  -p 1883:1883 \
  -v $(pwd)/conf:/conf:z
```

Now browse to port 3000. If you wish to use a different local port change the
left hand 3000 to the port of your choice.


## Production

If you wish to build an image from what is already committed to github
(ignoring any changes in your source tree):

```
$ docker build -t bhack-mosquitto -f docker/website/Dockerfile .
$ docker run \
  --name=bhack-mosquitto \
  --restart=unless-stopped \
  -v /srv/ballarathackerspace.org.au/conf:/conf \
  -p $PORT:1883 \
  -e TZ=Australia/Melbourne \
  -d bhack-mosquitto:$TAG
```
