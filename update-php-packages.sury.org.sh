#!/bin/bash
# Update PHP packages from packages.sury.org on Debian 11, 12 and 13.

# Fetch repository setup
apt install curl; curl https://packages.sury.org/php/README.txt | bash

# check package status
dpkg --audit
aptitude search "~ahold" | grep "^.h"
dpkg --get-selections | grep hold
dpkg --get-selections "*" > ~/curr-pkgs.txt

# have a look into required and free disk space
apt-get -o APT::Get::Trivial-Only=true dist-upgrade || df -h

# purge already remove packages
apt purge $(dpkg -l | awk '/^rc/ { print $2 }')

# record session
script -t 2>~/upgrade-php-$(lsb_release -sc).time -a ~/upgrade-php-$(lsb_release -sc).script

# install our preseed so libc doesn't whine
cat > /tmp/upgrade-php-$(lsb_release -sc).preseed <<EOF
libc6 glibc/upgrade boolean true
libc6 glibc/restart-services string
libc6 libraries/restart-without-asking boolean true
EOF
/usr/bin/debconf-set-selections /tmp/upgrade-php-$(lsb_release -sc).preseed && rm /tmp/upgrade-php-$(lsb_release -sc).preseed

# Pin packages
mkdir -p /etc/apt/preferences.d && \
  { phpquery -V | awk '{p=($1=="7.4"||$1=="8.0")?"1:":""; printf "Package: *\nPin: version %s%s.*\nPin-Priority: 990\n\n",p,$1}'; printf 'Package: *\nPin: origin packages.sury.org\nPin-Priority: 1\n'; } > \
  /etc/apt/preferences.d/sury-php

# minimal upgrade
apt update; apt install -y --only-upgrade *php$(phpquery -V)*

# minimal system upgrade
apt upgrade --without-new-pkgs

# remove old squeeze packages left around (keep eyes open!)
apt autoremove && \
wget https://ftp.de.debian.org/debian/pool/main/d/deborphan/deborphan_1.7.35_amd64.deb -O /tmp/deborphan_1.7.35_amd64.deb && apt install /tmp/deborphan_1.7.35_amd64.deb && apt purge $(deborphan | grep -v xen | grep -v -E 'libpam-cracklib|libapache2-mpm-itk')
apt purge $(dpkg -l | awk '/^rc/ { print $2 }')
