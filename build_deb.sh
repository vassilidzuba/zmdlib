#!/bin/bash

program=tohtml
version=0.0-1

if [[ $EUID -ne 0 ]]; then
    echo "You must be root to do this." 1>&2
    exit 100
fi
chown -R root:root ${program}_$version

mkdir -p ${program}_$version/usr/local/bin
cp ./zig-out/bin/tohtml ${program}_$version/usr/local/bin
cp ./zig-out/bin/tohtmlsrv ${program}_$version/usr/local/bin
dpkg-deb  --build ${program}_$version
