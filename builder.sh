#!/bin/sh

DEFAULT_CMDLINE_XEN=""
DEFAULT_CMDLINE_KERNEL="modules=loop,squashfs,sd-mod,usb-storage quiet"
DEFAULT_FLAVOR="lts"
DEFAULT_FLAVOR_OLD="vanilla"
NEW_VERSION_MIN="v3.11"

usage() {
    echo "$0 <output> <branch> [--flavor flavor] [--with-xen] [--with-grub] [--cmdline-xen args] [--cmdline-kernel args] [--versions] [package ...]"
    echo
    echo " --flavor         set the kernel package flavor"
    echo "                  default for >=${NEW_VERSION_MIN}: ${DEFAULT_FLAVOR}"
    echo "                  default for <${NEW_VERSION_MIN}:  ${DEFAULT_FLAVOR_OLD}"
    echo " --with-xen       include Xen hypervisor"
    echo " --with-grub      include Grub configuration"
    echo " --cmdline-xen    arguments to Xen hypervisor"
    echo "                  default: \"${DEFAULT_CMDLINE_XEN}\""
    echo " --cmdline-kernel arguments to Linux kernel"
    echo "                  default: \"${DEFAULT_CMDLINE_KERNEL}\""
    echo " --versions       will only list the kernel package version"
    echo "                  which will be used"
    echo
    echo "Examples:"
    echo " $0 /tmp/v3.9/ v3.9"
    echo " $0 /media/sda1/ edge --with-xen wireguard"
    exit 1
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
flavor="${DEFAULT_FLAVOR}"
cmdline_xen="${DEFAULT_CMDLINE_XEN}"
cmdline_kernel="${DEFAULT_CMDLINE_KERNEL}"
pkgs=""

is_old_version() {
    [ "$( echo -e "$branch\n${NEW_VERSION_MIN}" | sort -V | head -n1)" != "${NEW_VERSION_MIN}" ]
}

if [ "${branch}" != "edge" ] && is_old_version; then
    flavor="${DEFAULT_FLAVOR_OLD}"
fi

while [ $# -gt 0 ]; do
    arg="$1"
    shift
    case "$arg" in
    --help)
        usage
        exit 0
        ;;
    --flavor)
        flavor="$1"
        shift
        ;;
    --with-xen)
        xen=true
        ;;
    --with-grub)
        grub=true
        ;;
    --cmdline-xen)
        cmdline_xen="$1"
        shift
        ;;
    --cmdline-kernel)
        cmdline_kernel="$1"
        shift
        ;;
    --versions)
        versions=true
        ;;
    *)
        pkgs="${pkgs} -p ${arg}-${flavor} "
        ;;
    esac
done

set -e

tmp=$(mktemp -d)
repos=$(mktemp)
cat <<EOF >"${repos}"
http://dl-cdn.alpinelinux.org/alpine/${branch}/main
http://dl-cdn.alpinelinux.org/alpine/${branch}/community
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

update-kernel \
    --repositories-file "${repos}" \
    --flavor "${flavor}" \
    ${pkgs} \
    "${tmp}"

if [ "$xen" = true ]; then
    xenfile=$(mktemp)
    apk fetch --repositories-file "${repos}" --no-cache --stdout xen-hypervisor --quiet | tar -C "${tmp}" --strip-components=1 -xz boot
fi

if [ "$grub" = true ]; then
    mkdir -p "${tmp}/grub"
    cfg="${tmp}/grub/grub.cfg"
    cat <<EOF >> "${cfg}"
set timeout=5
set default=0

EOF
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
