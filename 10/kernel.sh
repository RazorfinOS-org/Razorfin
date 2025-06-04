#!/usr/bin/env sh


set -xeuo pipefail


kver=$(cd /usr/lib/modules && echo * | awk '{print $1}')


dracut -vf /usr/lib/modules/$kver/initramfs.img $kver
