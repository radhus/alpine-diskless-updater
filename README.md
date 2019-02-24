# alpine diskless updater

This container can be used to prepare updated contents of the `/boot` partition
on an Alpine diskless system.
As `update-kernel` requires a lot of RAM to run, it can be useful to prepare
the contents on another machine.

The tool also supports updating the Xen hypervisor.

Container is available at
[`radhus/alpine-diskless-updater`](https://hub.docker.com/r/radhus/alpine-diskless-updater)

## Usage

```sh
docker run --rm -v $PWD/output:/mnt \
    radhus/alpine-diskless-updater:latest \
    /mnt/out \
    v3.9 \
    --with-xen \
    wireguard-vanilla
```

Run without arguments to get usage help.