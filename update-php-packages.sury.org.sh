#!/bin/bash
# Update PHP packages from packages.sury.org on Debian 11, 12 and 13.

[ -x /usr/sbin/phpquery ] || { echo -e "\n\033[1;41m WARNING: PHP not found! \033[0m\n"; [[ $- == *i* ]] || exit 1; }
# Redirect Bullseye security sources to the archive when needed.
if [ "$( . /etc/os-release; echo "$VERSION_CODENAME" )" = bullseye ]; then
  changed=0
  # Only migrate Debian security mirrors, not third-party repositories using the same suite.
  source_pattern='^[[:space:]]*deb(-src)?[[:space:]]+(\[[^]]*\][[:space:]]+)?https?://(security\.debian\.org/debian-security|deb\.debian\.org/debian-security)[[:space:]]+bullseye-security([[:space:]]|$)'
  for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
    [ -f "$f" ] || continue
    if grep -Eq "$source_pattern" "$f"; then
      tmp=$(mktemp)
      sed -E \
        -e "\~$source_pattern~ s#(^[[:space:]]*deb(-src)?[[:space:]]+(\[[^]]*\][[:space:]]+)?)(https?://[^[:space:]]+)([[:space:]]+bullseye-security)#\\1http://archive.debian.org/debian-security\\5#" \
        -e "\~$source_pattern~ { s#(check-valid-until[[:space:]]*=[[:space:]]*)[^][[:space:]]+#\\1no#; t done; s#^([[:space:]]*deb(-src)?[[:space:]]+\[)([^]]*)(\][[:space:]]+)#\\1\\3 check-valid-until=no\\4#; t done; s#^([[:space:]]*deb(-src)?[[:space:]]+)(https?://[^[:space:]]+)#\\1[check-valid-until=no] \\3#; :done; }" \
        "$f" > "$tmp"
      # Write through the path so symlinked source-list files keep their links.
      if ! cmp -s "$f" "$tmp"; then
        cat "$tmp" > "$f"
        changed=1
      fi
      rm -f "$tmp"
    fi
  done
  [ "$changed" -eq 0 ] || apt-get update
fi

# Add the PHP repository provided by packages.sury.org.
apt install curl &&
  curl --fail --location --show-error https://packages.sury.org/php/README.txt -o /tmp/sury-php-setup.sh &&
  bash /tmp/sury-php-setup.sh

# Allow unattended-upgrades to recognize packages from the Sury PHP repository.
unattended_upgrades=/etc/apt/apt.conf.d/50unattended-upgrades

if [ -f "$unattended_upgrades" ] &&
   ! grep -Eq '^[[:space:]]*"origin=deb\.sury\.org,codename=\$\{distro_codename\}"[[:space:]]*;' "$unattended_upgrades" &&
   grep -Eq '^[[:space:]]*"origin=Debian,codename=\$\{distro_codename\}-security,label=Debian-Security"[[:space:]]*;' "$unattended_upgrades"; then
  sed -i '/^[[:space:]]*"origin=Debian,codename=${distro_codename}-security,label=Debian-Security"[[:space:]]*;/a\
        "origin=deb.sury.org,codename=${distro_codename}";' "$unattended_upgrades"
fi

# Prefer matching-version PHP packages from any repository, while giving packages from
# packages.sury.org a low priority by default. This keeps unrelated Sury packages from
# being preferred over Debian packages; required dependencies may still affect resolution.
# PHP 7.4 and 8.0 package versions use the "1:" epoch, unlike PHP 8.1 and later.
mkdir -p /etc/apt/preferences.d && \
  { phpquery -V | awk '{p=($1=="7.4"||$1=="8.0")?"1:":""; printf "Package: *php*\nPin: version %s%s.*\nPin-Priority: 990\n\n",p,$1}'; printf 'Package: libpcre2*\nPin: origin packages.sury.org\nPin-Priority: 990\n\n'; printf 'Package: *\nPin: origin packages.sury.org\nPin-Priority: 1\n'; } > \
  /etc/apt/preferences.d/sury-php

# Check package-manager state before upgrading: pending package issues, held packages,
# and a snapshot of the currently selected packages.
dpkg --audit
aptitude search "~ahold" | grep "^.h"
dpkg --get-selections | grep hold
dpkg --get-selections "*" > ~/curr-pkgs.txt

# Estimate the upgrade's disk-space requirements and show currently available space.
apt -o APT::Get::Trivial-Only=true dist-upgrade
df -h

# Remove packages that have been deleted but still have configuration files registered.
apt purge $(dpkg -l | awk '/^rc/ { print $2 }')

# Record the interactive upgrade session, including timing information, for later review.
script -t 2>~/upgrade-php-$(lsb_release -sc).time -a ~/upgrade-php-$(lsb_release -sc).script

# Preseed libc6 configuration answers so its upgrade does not prompt for these choices.
cat > /tmp/upgrade-php-$(lsb_release -sc).preseed <<EOF
libc6 glibc/upgrade boolean true
libc6 glibc/restart-services string
libc6 libraries/restart-without-asking boolean true
EOF
/usr/bin/debconf-set-selections /tmp/upgrade-php-$(lsb_release -sc).preseed && rm /tmp/upgrade-php-$(lsb_release -sc).preseed

# Refresh package indexes and upgrade only installed packages matching the active PHP version.
apt update; apt install -y --only-upgrade "*php$(phpquery -V)*" "*libapache2-mod-php$(phpquery -V)*"

# Upgrade installed packages without allowing new packages to be installed.
apt upgrade --without-new-pkgs

# Remove automatically removable packages, then install deborphan to identify additional
# orphaned packages. Keep the explicit exclusions when purging the deborphan results.
apt autoremove && \
arch="$(dpkg --print-architecture)"
deborphan_deb="/tmp/deborphan_1.7.35_${arch}.deb"
wget "https://ftp.de.debian.org/debian/pool/main/d/deborphan/deborphan_1.7.35_${arch}.deb" -O "${deborphan_deb}" && apt install "${deborphan_deb}" && apt purge $(deborphan | grep -v xen | grep -v -E 'libpam-cracklib|libapache2-mpm-itk')

# Remove any remaining packages that are marked as removed but still have configuration files.
apt purge $(dpkg -l | awk '/^rc/ { print $2 }')
