#!/bin/sh

usage() {
    echo "$0 <output> <branch> [--with-xen] [package ...]"
    echo
    echo "Examples:"
    echo " $0 /tmp/v3.9/ v3.9"
    echo " $0 /media/sda1/ edge --with-xen wireguard-vanilla"
    exit 1
}

pkgargs() {
    [ -n $1 ] || return
    for x in $@; do
        echo -n "-p $x "
    done
    echo
}

output=$1
[ -n "${output}" ] || usage
shift

branch=$1
[ -n "${branch}" ] || usage
shift

xen=false
[ "$1" == "--with-xen" ] && xen=true && shift

pkgs=$(pkgargs $@)

set -e

tmp=$(mktemp -d)
repos=$(mktemp)
cat <<EOF >"${repos}"
http://dl-cdn.alpinelinux.org/alpine/${branch}/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF

set -x

update-kernel --repositories-file "${repos}" ${pkgs}  "${tmp}"
if [ "$xen" = true ]; then
    xenfile=$(mktemp)
    apk fetch --repositories-file "${repos}" --no-cache --stdout xen-hypervisor --quiet | tar -C "${tmp}" --strip-components=1 -xz boot
fi
cp -a "${tmp}"/* "${output}"/
rm "${repos}"
rm -r "${tmp}"
