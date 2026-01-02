#!/usr/bin/env bash

set -xeuo pipefail

dnf5 install -y @cosmic-desktop-environment

systemctl enable cosmic-greeter.service

systemctl set-default graphical.target
