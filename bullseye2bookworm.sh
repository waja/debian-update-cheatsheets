Please also refer to http://www.debian.org/releases/bookworm/releasenotes and use your brain! If you can’t figure out what one of the commands below does, this is not for you. Expert mode only :)

# Crossgrading ?!?
[ "$(dpkg --print-architecture)" == "i386" ] && echo "How about crossgrading to amd64 as described in https://stbuehler.de/blog/article/2017/06/28/debian_buster__upgrade_32-bit_to_64-bit.html?"

# upgrade to UTF-8 locales (http://www.debian.org/releases/bookworm/amd64/release-notes/ap-old-stuff.en.html#switch-utf8)
dpkg-reconfigure locales

# remove unused config file
rm -rf /etc/network/options /etc/environment

# are there 3rd party packages installed? (https://www.debian.org/releases/bookworm/amd64/release-notes/ch-upgrading.de.html#system-status)
aptitude search '~i(!~ODebian)'

# check for ftp protocol in sources lists (https://www.debian.org/releases/bookworm/amd64/release-notes/ch-information.en.html#deprecation-of-ftp-apt-mirrors)
rgrep --color "deb ftp" /etc/apt/sources.list*

# Transition and remove entries from older releases
sed -iE "/(lenny|sarge|squeeze|wheezy|jessie|stretch|buster|volatile|proposed-updates)/d" /etc/apt/sources.list*
# change distro (please move 3rd party sources to /etc/apt/sources.list.d/), maybe look into http://ftp.cyconet.org/debian/sources.list.d/
sed -i s/bullseye/bookworm/g /etc/apt/sources.list*
sed -i "s/ stable/ bookworm/g" /etc/apt/sources.list*
sed -i s/bullseye/bookworm/g /etc/apt/preferences*
sed -i s/bullseye/bookworm/g /etc/apt/sources.list.d/*bullseye*
sed -i "s/non-free$/non-free non-free-firmware/" /etc/apt/sources.list
rename s/bullseye/bookworm/ /etc/apt/sources.list.d/*bullseye*
rgrep --color bullseye /etc/apt/sources.list*
apt update

# Remove changes to /etc/apt/apt.conf.d/50unattended-upgrades from ucf database
ucf -p /etc/apt/apt.conf.d/50unattended-upgrades

# check package status
dpkg --audit
aptitude search "~ahold" | grep "^.h"
dpkg --get-selections | grep hold
dpkg --get-selections "*" > ~/curr-pkgs.txt
 
# unmark packages auto
aptitude unmarkauto vim net-tools && \
aptitude unmarkauto libapache2-mpm-itk && \
aptitude unmarkauto monitoring-plugins-contrib && \
aptitude unmarkauto $(dpkg-query -W 'linux-image-5.10.0*' | cut -f1)
 
# have a look into required and free disk space
apt-get -o APT::Get::Trivial-Only=true dist-upgrade || df -h

# purge already remove packages
apt purge $(dpkg -l | awk '/^rc/ { print $2 }')

# check for a linux-image meta package
dpkg -l "linux-image*" | grep ^ii | grep -i meta || echo "Please have a look into https://www.debian.org/releases/bookworm/amd64/release-notes/ch-upgrading.en.html#kernel-metapackage!"
# record session
script -t 2>~/upgrade-bookworm.time -a ~/upgrade-bookworm.script

# install our preseed so libc doesn't whine
cat > /tmp/bookworm.preseed <<EOF
libc6 glibc/upgrade boolean true
libc6 glibc/restart-services string
libc6 libraries/restart-without-asking boolean true
EOF
/usr/bin/debconf-set-selections /tmp/bookworm.preseed && rm /tmp/bookworm.preseed

# minimal system upgrade
apt upgrade --without-new-pkgs

# Install zstd to add zstd compress support to update-initramfs
apt install zstd

# full-upgrade
apt full-upgrade

# randomize crontab
if [ -f /etc/crontab.dpkg-new ]; then CFG=/etc/crontab.dpkg-new; else CFG=/etc/crontab; fi
sed -i 's#root    cd#root    perl -e "sleep int(rand(300))" \&\& cd#' $CFG
sed -i 's#root\ttest#root\tperl -e "sleep int(rand(3600))" \&\& test#' $CFG

# (re)configure snmpd
if [ -f /etc/snmp/snmpd.conf.dpkg-new ]; then CFG=/etc/snmp/snmpd.conf.dpkg-new; \
   else CFG=/etc/snmp/snmpd.conf; fi
grep ^rocommunity /etc/snmp/snmpd.conf > /etc/snmp/snmpd.conf.d/rocommunity.conf
grep ^extend /etc/snmp/snmpd.conf > /etc/snmp/snmpd.conf.d/extend.conf
sed -i s/^rocommunity/#rocommunity/ $CFG

# Migrate (webserver) from php7.4 to php8.2
apt install $(dpkg -l |grep php7.4 | awk '/^i/ { print $2 }' |grep -v ^php7.4-opcache |sed s/php7.4/php/)
[ -L /etc/apache2/mods-enabled/mpm_prefork.load ] && a2dismod php7.4 && a2enmod php8.2 && systemctl restart apache2; ls -la /etc/php/7.4/*/conf.d/
# php-fpm
tail -10 /etc/php/7.4/fpm/pool.d/www.conf
vi /etc/php/8.2/fpm/pool.d/www.conf 
systemctl disable php7.4-fpm && systemctl stop php7.4-fpm && systemctl restart php8.2-fpm
# nginx
rename s/php74/php83/g /etc/nginx/conf.d/*php74*.conf
sed -i s/php7.4-fpm/php8.2-fpm/g /etc/nginx/conf.d/*.conf /etc/nginx/snippets/*.conf /etc/nginx/sites-available/*
systemctl restart nginx

# Upgrade postgres
if [ "$(dpkg -l | grep "postgresql-13" | awk {'print $2'})" = "postgresql-13" ]; then \
 aptitude install postgresql-15 && \
 pg_dropcluster --stop 15 main && \
 /etc/init.d/postgresql stop && \
 pg_upgradecluster -v 15 13 main && \
 sed -i "s/^manual/auto/g" /etc/postgresql/15/main/start.conf && \
 sed -i "s/^port = .*/port = 5432/" /etc/postgresql/15/main/postgresql.conf && \
 sed -i "s/^shared_buffers = .*/shared_buffers = 128MB/" /etc/postgresql/15/main/postgresql.conf && \
 /etc/init.d/postgresql restart && \
 su - postgres -c 'reindexdb --all'; \
fi
pg_dropcluster 13 main

# transition docker-ce to bookworm package
DOCKER_VER="$(apt-cache policy docker-ce | grep debian-bookworm | head -1 | awk '{print $1}')" && [ -n "${DOCKER_VER}" ] && apt install docker-ce=${DOCKER_VER} docker-ce-cli=${DOCKER_VER}

# transition icingaweb2 to bookworm package
ICINGAWEB2_VER="$(apt-cache policy icingaweb2 | grep "\.bookworm" | head -1 | awk '{print $1}')" && [ -n "${ICINGAWEB2_VER}" ] && apt install icingaweb2=${ICINGAWEB2_VER} icingaweb2-common=${ICINGAWEB2_VER} icingaweb2-module-monitoring=${ICINGAWEB2_VER} php-icinga=${ICINGAWEB2_VER} icingacli=${ICINGAWEB2_VER}

# transition icinga2 to bookworm packages
apt-get install $(dpkg -l | grep icinga2 | grep -v common | awk '{print $2"/icinga-bookworm"}')

# remove old squeeze packages left around (keep eyes open!)
apt autoremove && \
apt purge $(aptitude search ?obsolete | grep -v -E 'linux-image|mailscanner|check-openmanage|check-linux-bonding|webalizer|icinga|srvadmin' | awk '/^i *A/ { print $3 }') && \
apt purge $(aptitude search ?obsolete | grep -v -E 'linux-image|mailscanner|check-openmanage|check-linux-bonding|webalizer|icinga|srvadmi' | awk '/^i/ { print $2 }') && \
apt purge $(dpkg -l | grep etch | grep -v xen | grep -v unbound | grep -v finch | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep lenny | grep -v xen | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb6|squeeze' | grep -v xen | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb7|wheezy' | grep -v xen | grep -v  -E 'linux-image|mailscanner|openswan|debian-security-support' | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb8|jessie|deb9|stretch|deb10|buster' | grep -v xen | grep -v  -E 'linux-image|debian-security-support|icinga2|phpmyadmin' | awk '{ print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb11|bullseye' | grep -v xen | grep -v  -E 'linux-image|debian-security-support|icinga2|phpmyadmin' | awk '{ print $2 }') && \
apt -y install deborphan && apt purge $(deborphan | grep -v xen | grep -v -E 'libpam-cracklib|libapache2-mpm-itk')
apt purge $(dpkg -l | awk '/^rc/ { print $2 }')

# for the brave YoloOps crowd
reboot && sleep 180; echo u > /proc/sysrq-trigger ; sleep 2 ; echo s > /proc/sysrq-trigger ; sleep 2 ; echo b > /proc/sysrq-trigger

### not needed until now

# (re)enable wheel
if [ -f /etc/pam.d/su.dpkg-new ]; then CFG=/etc/pam.d/su.dpkg-new; else CFG=/etc/pam.d/su; fi
sed -i "s/# auth       required   pam_wheel.so/auth       required   pam_wheel.so/" $CFG


## phpmyadmin
if [ -f /etc/phpmyadmin/config.inc.php.dpkg-new ]; then CFG=/etc/phpmyadmin/config.inc.php.dpkg-new; \
   else CFG=/etc/phpmyadmin/config.inc.php; fi
sed -i "s/\['auth_type'\] = 'cookie'/\['auth_type'\] = 'http'/" $CFG
sed -i "s#//\$cfg\['Servers'\]\[\$i\]\['auth_type'\] = 'http';#\$cfg['Servers'][\$i]['auth_type'] = 'http';#" $CFG

# Update old postfix configurations
cp /etc/postfix/main.cf /tmp/main.cf && \
if [ $(postconf -n smtpd_relay_restrictions | wc -l) -eq 0 ]; then sed -i '/^myhostname.*/i smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination' /etc/postfix/main.cf; fi && \
if [ -z $(postconf -nh compatibility_level) ]; then sed -iE 's/^readme_directory = no/readme_directory = no\n\n# See http:\/\/www.postfix.org\/COMPATIBILITY_README.html -- default to 2 on\n# fresh installs.\ncompatibility_level = 2\n\n/' /etc/postfix/main.cf; fi && \
diff -Nur /tmp/postfix/main.cf /etc/postfix/main.cf && \
postfix reload
