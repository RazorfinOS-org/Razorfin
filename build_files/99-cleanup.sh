#!/usr/bin/env bash

set -xeuo pipefail

dnf5 clean all

rm -rf /tmp/* /var/tmp/* || true

rm -rf /var/cache/dnf/* || true
