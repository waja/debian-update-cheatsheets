Please also refer to http://www.debian.org/releases/bullseye/releasenotes and use your brain! If you can’t figure out what one of the commands below does, this is not for you. Expert mode only :)

# Crossgrading ?!?
[ "$(dpkg --print-architecture)" == "i386" ] && echo "How about crossgrading to amd64 as described in https://stbuehler.de/blog/article/2017/06/28/debian_buster__upgrade_32-bit_to_64-bit.html?"

# upgrade to UTF-8 locales (http://www.debian.org/releases/bullseye/amd64/release-notes/ap-old-stuff.en.html#switch-utf8)
dpkg-reconfigure locales

# remove unused config file
rm -rf /etc/network/options /etc/environment

# are there 3rd party packages installed? (https://www.debian.org/releases/bullseye/amd64/release-notes/ch-upgrading.de.html#system-status)
aptitude search '~i(!~ODebian)'

# check for ftp protocol in sources lists (https://www.debian.org/releases/bullseye/amd64/release-notes/ch-information.en.html#deprecation-of-ftp-apt-mirrors)
rgrep --color "deb ftp" /etc/apt/sources.list*

# Transition and remove entries from older releases
sed -i /lenny/d /etc/apt/sources.list*
sed -i /sarge/d /etc/apt/sources.list*
sed -i /squeeze/d /etc/apt/sources.list*
sed -i /wheezy/d /etc/apt/sources.list*
sed -i /jessie/d /etc/apt/sources.list*
sed -i /volatile/d /etc/apt/sources.list*
sed -i /proposed-updates/d /etc/apt/sources.list*
# change distro (please move 3rd party sources to /etc/apt/sources.list.d/), maybe look into http://ftp.cyconet.org/debian/sources.list.d/
sed -i s/buster/bullseye/g /etc/apt/sources.list*
sed -i "s/ stable/ bullseye/g" /etc/apt/sources.list*
sed -i s/buster/bullseye/g /etc/apt/preferences*
sed -i s/buster/bullseye/g /etc/apt/sources.list.d/*buster*
rename s/buster/bullseye/g /etc/apt/sources.list.d/*buster*
rgrep --color buster /etc/apt/sources.list*
apt-get update --allow-releaseinfo-change

# check package status
dpkg --audit
aptitude search "~ahold" | grep "^.h"
dpkg --get-selections | grep hold
dpkg --get-selections "*" > ~/curr-pkgs.txt
 
# unmark packages auto
aptitude unmarkauto vim net-tools && \
aptitude unmarkauto libapache2-mpm-itk && \
aptitude unmarkauto $(dpkg-query -W 'linux-image-4.9.0*' | cut -f1)
 
# have a look into required and free disk space
apt-get -o APT::Get::Trivial-Only=true dist-upgrade || df -h

# record session
script -t 2>~/upgrade-bullseye.time -a ~/upgrade-bullseye.script

# install our preseed so libc doesn't whine
cat > /tmp/buster.preseed <<EOF
libc6 glibc/upgrade boolean true
libc6 glibc/restart-services string
libc6 libraries/restart-without-asking boolean true
EOF
/usr/bin/debconf-set-selections /tmp/buster.preseed

# update aptitude first
[ "$(which aptitude)" = "/usr/bin/aptitude" ] && aptitude install aptitude && \
[ "$(which apt)" = "/usr/bin/apt" ] && apt install apt

# minimal system upgrade
aptitude upgrade

# randomize crontab
if [ -f /etc/crontab.dpkg-new ]; then CFG=/etc/crontab.dpkg-new; else CFG=/etc/crontab; fi
sed -i 's#root    cd#root    perl -e "sleep int(rand(300))" \&\& cd#' $CFG
sed -i 's#root\ttest#root\tperl -e "sleep int(rand(3600))" \&\& test#' $CFG

# chrony update, modify the new config to our needs and place it where it is expected.
# Accept MAINTAINERS version (and run this snippet afterwards)
if [ -f /etc/chrony/chrony.conf.new ]; then CFG=/etc/chrony/chrony.conf.new; else CFG=/etc/chrony/chrony.conf; fi
sed s/2.debian.pool/0.de.pool/g /usr/share/chrony/chrony.conf > $CFG

# Fix our ssh pub key package configuration
# Accept MAINTAINERS version (and run this snippet afterwards)
[ -x /var/lib/dpkg/info/config-openssh-server-authorizedkeys-core.postinst ] && \
  /var/lib/dpkg/info/config-openssh-server-authorizedkeys-core.postinst configure

# migrate unattended-upgrades config, modify the new config to our needs and place it where it is expected.
# Keep LOCAL config if asked when upgrading (and run this snippet afterwards, when dpkg is not blocked anymore and choose 'package maintainer version' then, cause this is the one we are adjusting here)
if [ -f /etc/apt/apt.conf.d/50unattended-upgrades.ucf-old ]; then CFG=/etc/apt/apt.conf.d/50unattended-upgrades.ucf-old; else CFG=/etc/apt/apt.conf.d/50unattended-upgrades; fi && \
cp /usr/share/unattended-upgrades/50unattended-upgrades /tmp/ && \
MAIL=$(grep ^Unattended-Upgrade::Mail $CFG | awk -F\" '{print $2}'); sed -i 's#//Unattended-Upgrade::Mail ".*";#Unattended-Upgrade::Mail "'${MAIL}'";#g' /tmp/50unattended-upgrades && \
TIME=$(grep ^Unattended-Upgrade::Automatic-Reboot-Time $CFG | awk -F\" '{print $2}'); if [ "${TIME}" != "" ]; then sed -i 's#//Unattended-Upgrade::Automatic-Reboot-Time "02:00"#Unattended-Upgrade::Automatic-Reboot-Time "'${TIME}'"#' /tmp/50unattended-upgrades; fi
sed -i 's#//      "origin=Debian,codename=${distro_codename}-updates"#        "origin=Debian,codename=${distro_codename}-updates"#' /tmp/50unattended-upgrades && \
sed -i 's#//Unattended-Upgrade::Remove-Unused-Dependencies "false"#Unattended-Upgrade::Remove-Unused-Dependencies "true"#' /tmp/50unattended-upgrades && \
sed -i 's#//Unattended-Upgrade::Automatic-Reboot "false"#Unattended-Upgrade::Automatic-Reboot "true"#' /tmp/50unattended-upgrades && \
sed -i '/codename=..distro_codename.-updates/ s#^//#  #' /tmp/50unattended-upgrades && \
/bin/bash /usr/bin/ucf --three-way --debconf-ok /tmp/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades && \
[ "$CFG" == "/etc/apt/apt.conf.d/50unattended-upgrades.ucf-old" ] && mv $CFG /etc/apt/apt.conf.d/50unattended-upgrades.ucf-save

## phpmyadmin
if [ -f /etc/phpmyadmin/config.inc.php.dpkg-new ]; then CFG=/etc/phpmyadmin/config.inc.php.dpkg-new; \
   else CFG=/etc/phpmyadmin/config.inc.php; fi
sed -i "s/\['auth_type'\] = 'cookie'/\['auth_type'\] = 'http'/" $CFG
sed -i "s#//\$cfg\['Servers'\]\[\$i\]\['auth_type'\] = 'http';#\$cfg['Servers'][\$i]['auth_type'] = 'http';#" $CFG

# transition sshd port changes
sed -i "s/^#Port 22/Port 1234/" /etc/ssh/sshd_config && /etc/init.d/ssh restart

# full-upgrade
apt-get dist-upgrade

# Migrate (webserver) from php7.3 to php7.4
apt install $(dpkg -l |grep php7.3 | awk '/^i/ { print $2 }' |grep -v ^php7.3-opcache |sed s/php7.3/php/)
[ -L /etc/apache2/mods-enabled/mpm_prefork.load ] && a2dismod php7.3 && a2enmod php7.4 && systemctl restart apache2; ls -la /etc/php/7.3/*/conf.d/
# php-fpm
tail -10 /etc/php/7.3/fpm/pool.d/www.conf
vi /etc/php/7.4/fpm/pool.d/www.conf 
systemctl disable php7.3-fpm && systemctl stop php7.3-fpm && systemctl restart php7.4-fpm
# nginx
rename s/php73/php74/g /etc/nginx/conf.d/*php73*.conf
sed -i s/php7.3-fpm/php7.4-fpm/g /etc/nginx/conf.d/*.conf /etc/nginx/snippets/*.conf /etc/nginx/sites-available/*
systemctl restart nginx

# Update old postfix configurations
cp /etc/postfix/main.cf /tmp/main.cf && \
if [ $(postconf -n smtpd_relay_restrictions | wc -l) -eq 0 ]; then sed -i '/^myhostname.*/i smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination' /etc/postfix/main.cf; fi && \
if [ -z $(postconf -nh compatibility_level) ]; then sed -iE 's/^readme_directory = no/readme_directory = no\n\n# See http:\/\/www.postfix.org\/COMPATIBILITY_README.html -- default to 2 on\n# fresh installs.\ncompatibility_level = 2\n\n/' /etc/postfix/main.cf; fi && \
diff -Nur /tmp/postfix/main.cf /etc/postfix/main.cf && \
postfix reload

# transition docker-ce to bullseye package
DOCKER_VER="$(apt-cache policy docker-ce | grep debian-bullseye | head -1 | awk '{print $1}')" && [ -n "${DOCKER_VER}" ] && apt install docker-ce=${DOCKER_VER} docker-ce-cli=${DOCKER_VER}

# transition icingaweb2 to bullseye package
ICINGAWEB2_VER="$(apt-cache policy icingaweb2 | grep "\.bullseye" | head -1 | awk '{print $1}')" && [ -n "${ICINGAWEB2_VER}" ] && apt install icingaweb2=${ICINGAWEB2_VER} icingaweb2-common=${ICINGAWEB2_VER} icingaweb2-module-monitoring=${ICINGAWEB2_VER} php-icinga=${ICINGAWEB2_VER} icingacli=${ICINGAWEB2_VER}

# remove old squeeze packages left around (keep eyes open!)
apt autoremove && \
apt purge $(aptitude search ?obsolete | grep -v -E 'linux-image|mailscanner|phpmyadmin|check-openmanage|check-linux-bonding' | awk '/^i *A/ { print $3 }') && \
apt purge $(aptitude search ?obsolete | grep -v -E 'linux-image|mailscanner|phpmyadmin|check-openmanage|check-linux-bonding' | awk '/^i/ { print $2 }') && \
apt purge $(dpkg -l | grep etch | grep -v xen | grep -v unbound | grep -v finch | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep lenny | grep -v xen | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb6|squeeze' | grep -v xen | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb7|wheezy' | grep -v xen | grep -v  -E 'linux-image|mailscanner|openswan|debian-security-support' | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb8|jessie' | grep -v xen | grep -v  -E 'linux-image|debian-security-support' | awk '{ print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb9|stretch' | grep -v xen | grep -v  -E 'linux-image|debian-security-support|icinga2|phpmyadmin' | awk '{ print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb10|buster' | grep -v xen | grep -v  -E 'linux-image|debian-security-support|icinga2|phpmyadmin' | awk '{ print $2 }') && \
apt -y install deborphan && apt purge $(deborphan | grep -v xen | grep -v -E 'libpam-cracklib|libapache2-mpm-itk')
apt purge $(dpkg -l | awk '/^rc/ { print $2 }')

# for the brave YoloOps crowd
reboot && sleep 180; echo u > /proc/sysrq-trigger ; sleep 2 ; echo s > /proc/sysrq-trigger ; sleep 2 ; echo b > /proc/sysrq-trigger

### not needed until now
# Upgrade postgres
# See also https://www.debian.org/releases/buster/amd64/release-notes/ch-information.de.html#plperl
if [ "$(dpkg -l | grep "postgresql-9.4" | awk {'print $2'})" = "postgresql-9.4" ]; then \
 aptitude install postgresql-9.6 && \
 pg_dropcluster --stop 9.6 main && \
 /etc/init.d/postgresql stop && \
 pg_upgradecluster -v 9.6 9.4 main && \
 sed -i "s/^manual/auto/g" /etc/postgresql/9.6/main/start.conf && \
 sed -i "s/^port = .*/port = 5432/" /etc/postgresql/9.6/main/postgresql.conf && \
 sed -i "s/^shared_buffers = .*/shared_buffers = 128MB/" /etc/postgresql/9.6/main/postgresql.conf && \
 /etc/init.d/postgresql restart; \
fi
pg_dropcluster 9.4 main
