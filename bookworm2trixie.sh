Please also refer to http://www.debian.org/releases/trixie/releasenotes and use your brain! If you can’t figure out what one of the commands below does, this is not for you. Expert mode only :)

# upgrade to UTF-8 locales (http://www.debian.org/releases/trixie/amd64/release-notes/ap-old-stuff.en.html#switch-utf8)
dpkg-reconfigure locales

# remove unused config file
rm -rf /etc/network/options /etc/environment

# are there 3rd party packages installed? (https://www.debian.org/releases/trixie/amd64/release-notes/ch-upgrading.de.html#system-status)
aptitude search '~i(!~ODebian)'

# check for ftp protocol in sources lists (https://www.debian.org/releases/trixie/amd64/release-notes/ch-information.en.html#deprecation-of-ftp-apt-mirrors)
rgrep --color "deb ftp" /etc/apt/sources.list*

# Install rename
[ ! -x /usr/bin/rename ] && apt install rename

# Transition and remove entries from older releases
sed -i -E "/(lenny|sarge|squeeze|wheezy|jessie|stretch|buster|volatile|proposed-updates)/d" /etc/apt/sources.list*
# Migrate source list of docker-ctop into our scheme
[ -f /etc/apt/sources.list.d/azlux.list ] && mv /etc/apt/sources.list.d/azlux.list /etc/apt/sources.list.d/bookworm-azlux.list && sed -i s/buster/bookworm/g /etc/apt/sources.list.d/bookworm-azlux.list
# change distro (please move 3rd party sources to /etc/apt/sources.list.d/), maybe look into http://ftp.cyconet.org/debian/sources.list.d/
sed -i s/bookworm/trixie/g /etc/apt/sources.list
sed -i "s/ stable/ trixie/g" /etc/apt/sources.list
sed -i s/bookworm/trixie/g /etc/apt/preferences*
find /etc/apt/sources.list.d -type f -name *bookworm* -exec sed -i 's/bookworm/trixie/g' {} \;
find /etc/apt/sources.list.d -type f -exec sed -i 's/bookworm/trixie/g' {} \;
rename s/bookworm/trixie/ /etc/apt/sources.list.d/*bookworm*
rgrep --color bookworm /etc/apt/sources.list*
apt update

# check package status
dpkg --audit
aptitude search "~ahold" | grep "^.h"
dpkg --get-selections | grep hold
dpkg --get-selections "*" > ~/curr-pkgs.txt
 
# unmark packages auto
aptitude unmarkauto vim net-tools && \
aptitude unmarkauto libapache2-mpm-itk && \
aptitude unmarkauto $(dpkg-query -W 'linux-image-6.1.0*' | cut -f1)
 
# have a look into required and free disk space
apt-get -o APT::Get::Trivial-Only=true dist-upgrade || df -h

# purge already remove packages
apt purge $(dpkg -l | awk '/^rc/ { print $2 }')

# check for a linux-image meta package
dpkg -l "linux-image*" | grep ^ii | grep -i meta || echo "Please have a look into https://www.debian.org/releases/trixie/amd64/release-notes/ch-upgrading.en.html#kernel-metapackage!"
# record session
script -t 2>~/upgrade-trixie.time -a ~/upgrade-trixie.script

# install our preseed so libc doesn't whine
cat > /tmp/trixie.preseed <<EOF
libc6 glibc/upgrade boolean true
libc6 glibc/restart-services string
libc6 libraries/restart-without-asking boolean true
EOF
/usr/bin/debconf-set-selections /tmp/trixie.preseed && rm /tmp/trixie.preseed

# minimal system upgrade
apt upgrade --without-new-pkgs

# randomize crontab
if [ -f /etc/crontab.dpkg-new ]; then CFG=/etc/crontab.dpkg-new; else CFG=/etc/crontab; fi
sed -i 's#root\tcd#root    perl -e "sleep int(rand(300))" \&\& cd#' $CFG
sed -i 's#root\ttest#root\tperl -e "sleep int(rand(3600))" \&\& test#' $CFG

# Migrate chrony config adjustment to sources.d directory
if [ -f /etc/chrony/conf.d/pool.conf ]; then mv /etc/chrony/conf.d/pool.conf /etc/chrony/sources.d/local-ntp-server.sources && sed -i "s/^pool/server/" /etc/chrony/sources.d/local-ntp-server.sources; fi

# full-upgrade
apt full-upgrade

# Migrate (webserver) from php8.2 to php8.4
apt install $(dpkg -l |grep php8.2 | awk '/^i/ { print $2 }' |grep -v ^php8.2-opcache |sed s/php8.2/php/)
sed -i "s/IfModule mod_php7/IfModule mod_php/g" /etc/apache2/sites-available/*
[ -L /etc/apache2/mods-enabled/mpm_prefork.load ] && a2dismod php8.2 && a2enmod php8.4 && systemctl restart apache2; ls -la /etc/php/8.2/*/conf.d/
# php-fpm
tail -10 /etc/php/8.2/fpm/pool.d/www.conf
vi /etc/php/8.4/fpm/pool.d/www.conf 
systemctl disable php8.2-fpm && systemctl stop php8.2-fpm && systemctl restart php8.4-fpm
# nginx
rename s/php82/php84/g /etc/nginx/conf.d/*php82*.conf
sed -i s/php8.2-fpm/php8.4-fpm/g /etc/nginx/conf.d/*.conf /etc/nginx/snippets/*.conf /etc/nginx/sites-available/*
systemctl restart nginx

# Upgrade postgres
if [ "$(dpkg -l | grep "postgresql-15" | awk {'print $2'})" = "postgresql-15" ]; then \
 aptitude install postgresql-17 && \
 pg_dropcluster --stop 17 main && \
 /etc/init.d/postgresql stop && \
 pg_upgradecluster -v 17 15 main && \
 sed -i "s/^manual/auto/g" /etc/postgresql/17/main/start.conf && \
 sed -i "s/^port = .*/port = 5432/" /etc/postgresql/17/main/postgresql.conf && \
 sed -i "s/^shared_buffers = .*/shared_buffers = 128MB/" /etc/postgresql/17/main/postgresql.conf && \
 /etc/init.d/postgresql restart && \
 su - postgres -c 'reindexdb --all'; \
fi
pg_dropcluster 15 main

# transition docker-ce to trixie package
DOCKER_VER="$(apt-cache policy docker-ce | grep debian-trixie | head -1 | awk '{print $1}')" && [ -n "${DOCKER_VER}" ] && apt install docker-ce=${DOCKER_VER} docker-ce-cli=${DOCKER_VER}

# transition icingaweb2 to trixie package
ICINGAWEB2_VER="$(apt-cache policy icingaweb2 | grep "\.trixie" | head -1 | awk '{print $1}')" && [ -n "${ICINGAWEB2_VER}" ] && apt install icingaweb2=${ICINGAWEB2_VER} icingaweb2-common=${ICINGAWEB2_VER} icingaweb2-module-monitoring=${ICINGAWEB2_VER} php-icinga=${ICINGAWEB2_VER} icingacli=${ICINGAWEB2_VER}

# transition icinga2 to trixie packages
apt-get install $(dpkg -l | grep icinga2 | grep -v common | awk '{print $2"/icinga-trixie"}')

# Switch to deb822 format for the sources.lists

# remove old squeeze packages left around (keep eyes open!)
apt autoremove && \
apt purge $(aptitude search ?obsolete | grep -v -E 'linux-image|mailscanner|check-openmanage|check-linux-bonding|webalizer|icinga|srvadmin|kerio|hddtemp' | awk '/^i *A/ { print $3 }') && \
apt purge $(aptitude search ?obsolete | grep -v -E 'linux-image|mailscanner|check-openmanage|check-linux-bonding|webalizer|icinga|srvadmin|kerio|hddtemp' | awk '/^i/ { print $2 }') && \
apt purge $(dpkg -l | grep etch | grep -v xen | grep -v unbound | grep -v finch | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep lenny | grep -v xen | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb6|squeeze' | grep -v xen | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb7|wheezy' | grep -v xen | grep -v  -E 'linux-image|mailscanner|openswan|debian-security-support' | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb8|jessie|deb9|stretch|deb10|buster|deb11|bullseye' | grep -v xen | grep -v  -E 'linux-image|debian-security-support|icinga2|phpmyadmin' | awk '{ print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb12|bookworm' | grep -v xen | grep -v  -E 'linux-image|debian-security-support|icinga2|phpmyadmin|megacli' | awk '{ print $2 }') && \
wget http://ftp.de.debian.org/debian/pool/main/d/deborphan/deborphan_1.7.35_amd64.deb -O /tmp/deborphan_1.7.35_amd64.deb && apt install /tmp/deborphan_1.7.35_amd64.deb && apt purge $(deborphan | grep -v xen | grep -v -E 'libpam-cracklib|libapache2-mpm-itk')
apt purge $(dpkg -l | awk '/^rc/ { print $2 }')

# for the brave YoloOps crowd
reboot && sleep 180; echo u > /proc/sysrq-trigger ; sleep 2 ; echo s > /proc/sysrq-trigger ; sleep 2 ; echo b > /proc/sysrq-trigger

### not needed until now

# (re)enable wheel
if [ -f /etc/pam.d/su.dpkg-new ]; then CFG=/etc/pam.d/su.dpkg-new; else CFG=/etc/pam.d/su; fi
sed -i "s/# auth       required   pam_wheel.so/auth       required   pam_wheel.so/" $CFG

# Update old postfix configurations
cp /etc/postfix/main.cf /tmp/main.cf && \
if [ $(postconf -n smtpd_relay_restrictions | wc -l) -eq 0 ]; then sed -i '/^myhostname.*/i smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination' /etc/postfix/main.cf; fi && \
if [ -z $(postconf -nh compatibility_level) ]; then sed -iE 's/^readme_directory = no/readme_directory = no\n\n# See http:\/\/www.postfix.org\/COMPATIBILITY_README.html -- default to 2 on\n# fresh installs.\ncompatibility_level = 2\n\n/' /etc/postfix/main.cf; fi && \
diff -Nur /tmp/postfix/main.cf /etc/postfix/main.cf && \
postfix reload
