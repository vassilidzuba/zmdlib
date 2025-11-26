#!/bin/bash

program=tohtml
version=0.0-1

mkdir -p ${program}_$version/usr/local/bin
cp ./zig-out/bin/tohtml ${program}_$version/usr/local/bin
cp ./zig-out/bin/tohtmlsrv ${program}_$version/usr/local/bin
dpkg-deb  --build ${program}_$version
