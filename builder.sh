#!/bin/sh

usage() {
    echo "$0 <output> <branch> [--with-xen] [--with-grub] [--versions] [package ...]"
    echo
    echo " --with-xen  include Xen hypervisor"
    echo " --with-grub include Grub configuration"
    echo " --versions  will only list the kernel package version"
    echo "             which will be used"
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
grub=false
versions=false
flavor="vanilla"
cmdline_xen=""
cmdline_kernel="modules=loop,squashfs,sd-mod,usb-storage quiet"

while [ $# -gt 0 ]; do
    arg="$1"
    shift
    case "$arg" in
    --help)
        usage
        exit 0
        ;;
    --with-xen)
        xen=true
        ;;
    --with-grub)
        grub=true
        ;;
    --versions)
        versions=true
        ;;
    esac
done

pkgs=$(pkgargs $@)

set -e

tmp=$(mktemp -d)
repos=$(mktemp)
cat <<EOF >"${repos}"
http://dl-cdn.alpinelinux.org/alpine/${branch}/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF

if [ "$versions" = true ]; then
    db=$(mktemp -d)
    apk --quiet --root "${db}" --repositories-file "${repos}" --keys-dir /etc/apk/keys \
        add --initdb --update-cache
    apk --root "${db}" --repositories-file "${repos}" --keys-dir /etc/apk/keys \
        search -x linux-${flavor}
    exit $?
fi

set -x

update-kernel --repositories-file "${repos}" ${pkgs}  "${tmp}"

if [ "$xen" = true ]; then
    xenfile=$(mktemp)
    apk fetch --repositories-file "${repos}" --no-cache --stdout xen-hypervisor --quiet | tar -C "${tmp}" --strip-components=1 -xz boot
fi

if [ "$grub" = true ]; then
    mkdir -p "${tmp}/grub"
    cfg="${tmp}/grub/grub.cfg"
    : > "${cfg}"
    if [ "$xen" = true ]; then
        cat <<EOF >> "${cfg}"
menuentry "Xen/Linux ${flavor}" {
    multiboot2 /boot/xen.gz ${cmdline_xen}
    module2 /boot/vmlinuz-${flavor} ${cmdline_kernel}
    module2 /boot/initramfs-${flavor}
}

EOF
    fi
    cat <<EOF >> "${cfg}"
menuentry "Linux ${flavor}" {
    linux /boot/vmlinuz-${flavor} ${cmdline_kernel}
    initrd /boot/initramfs-${flavor}
}
EOF
fi

mkdir -p "${output}"
cp -a "${tmp}"/* "${output}"/
rm "${repos}"
rm -r "${tmp}"
