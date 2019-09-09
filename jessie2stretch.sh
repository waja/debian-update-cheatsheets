Please also refer to http://www.debian.org/releases/stretch/releasenotes and use your brain! If you can’t figure out what one of the commands below does, this is not for you. Expert mode only :)


# upgrade to UTF-8 locales (http://www.debian.org/releases/stretch/amd64/release-notes/ap-old-stuff.en.html#switch-utf8)
dpkg-reconfigure locales

# remove unused config file
rm -rf /etc/network/options /etc/environment

# migrate over to systemd (before the upgrade) / you might want reboot if you install systemd
aptitude install systemd systemd-sysv libpam-systemd

# are there 3rd party packages installed? (https://www.debian.org/releases/stretch/amd64/release-notes/ch-upgrading.de.html#system-status)
aptitude search '~i(!~ODebian)'

# check for ftp protocol in sources lists (https://www.debian.org/releases/stretch/amd64/release-notes/ch-information.en.html#deprecation-of-ftp-apt-mirrors)
rgrep --color "deb ftp" /etc/apt/sources.list*

# Transition and remove entries from older releases
sed -i /etch/d /etc/apt/sources.list*
sed -i /lenny/d /etc/apt/sources.list*
sed -i /sarge/d /etc/apt/sources.list*
sed -i /squeeze/d /etc/apt/sources.list*
sed -i /wheezy/d /etc/apt/sources.list*
sed -i /volatile/d /etc/apt/sources.list*
sed -i /proposed-updates/d /etc/apt/sources.list*
# change distro (please move 3rd party sources to /etc/apt/sources.list.d/), maybe look into http://ftp.cyconet.org/debian/sources.list.d/
sed -i s/jessie/stretch/g /etc/apt/sources.list*
sed -i "s/ stable/ stretch/g" /etc/apt/sources.list*
sed -i s/jessie/stretch/g /etc/apt/preferences*
sed -i s/jessie/stretch/g /etc/apt/sources.list.d/*jessie*
rename s/jessie/stretch/g /etc/apt/sources.list.d/*jessie*
sed -i 's/#\(.*stretch\-updates\)/\1/' /etc/apt/sources.list
sed -i 's/#\(.*stretch\-backports\)/\1/' /etc/apt/sources.list.d/stretch-backports.list
rgrep --color jessie /etc/apt/sources.list*
# migrate omsa source
[ -f /etc/apt/sources.list.d/stretch-dell-omsa.list ] && sed -i /openmanage/d /etc/apt/sources.list.d/stretch-dell-omsa.list && echo "deb http://linux.dell.com/repo/community/openmanage/910/stretch stretch main" >> /etc/apt/sources.list.d/stretch-dell-omsa.list
apt-get update

# check package status
dpkg --audit
aptitude search "~ahold" | grep "^.h"
dpkg --get-selections | grep hold
 
# unmark packages auto
aptitude unmarkauto vim net-tools && \
aptitude unmarkauto libapache2-mpm-itk && \
aptitude unmarkauto monitoring-plugins-standard monitoring-plugins-common monitoring-plugins-basic && \
aptitude unmarkauto $(dpkg-query -W 'linux-image-3.16*' | cut -f1)
 
# have a look into required and free disk space
apt-get -o APT::Get::Trivial-Only=true dist-upgrade || df -h

# record session
script -t 2>~/upgrade-stretch.time -a ~/upgrade-stretch.script

# install our preseed so libc doesn't whine
cat > /tmp/stretch.preseed <<EOF
libc6 glibc/upgrade boolean true
libc6 glibc/restart-services string
libc6 libraries/restart-without-asking boolean true
EOF
/usr/bin/debconf-set-selections /tmp/stretch.preseed

# Disable loading defaults.vim
echo '" disable the loading of defaults.vim' >> /etc/vim/vimrc.local
echo "let g:skip_defaults_vim = 1" >> /etc/vim/vimrc.local

# update aptitude first
[ "$(which aptitude)" = "/usr/bin/aptitude" ] && aptitude install aptitude

# minimal system upgrade (keep sysvinit / see http://noone.org/talks/debian-ohne-systemd/debian-ohne-systemd-clt.html#%2811%29)
aptitude upgrade

## fix our xen modification
#rm -rf /etc/grub.d/09_linux_xen
#dpkg-divert --divert /etc/grub.d/09_linux_xen --rename /etc/grub.d/20_linux_xen

# chrony update
if [ -f /etc/chrony/chrony.conf.new ]; then CFG=/etc/chrony/chrony.conf.new; else CFG=/etc/chrony/chrony.conf; fi
sed -i s/2.debian.pool/0.de.pool/g $CFG

# migrate unattended-upgrades config
if [ -f /etc/apt/apt.conf.d/50unattended-upgrades.dpkg-new ]; then CFG=/etc/apt/apt.conf.d/50unattended-upgrades.dpkg-new; \
   else CFG=/etc/apt/apt.conf.d/50unattended-upgrades; fi
sed -i s/jessie/stretch/g $CFG
sed -i s/crontrib/contrib/g $CFG
sed -i "s#// If automatic reboot is enabled and needed, reboot at the specific#// Automatically reboot even if there are users currently logged in.\n//Unattended-Upgrade::Automatic-Reboot-WithUsers \"true\";\n\n// If automatic reboot is enabled and needed, reboot at the specific#" $CFG
cat >> $CFG <<EOF

// Enable logging to syslog. Default is False
// Unattended-Upgrade::SyslogEnable "false";

// Specify syslog facility. Default is daemon
// Unattended-Upgrade::SyslogFacility "daemon";

EOF

# dnsmasq config dir
if [ -f /etc/dnsmasq.conf.dpkg-new ]; then CFG=/etc/dnsmasq.conf.dpkg-new; \
   else CFG=/etc/dnsmasq.conf; fi
sed -i "s%^#conf-dir=/etc/dnsmasq.d/%conf-dir=/etc/dnsmasq.d/%" $CFG

## phpmyadmin
if [ -f /etc/phpmyadmin/config.inc.php.dpkg-new ]; then CFG=/etc/phpmyadmin/config.inc.php.dpkg-new; \
   else CFG=/etc/phpmyadmin/config.inc.php; fi
sed -i "s/\['auth_type'\] = 'cookie'/\['auth_type'\] = 'http'/" $CFG
sed -i "s#//\$cfg\['Servers'\]\[\$i\]\['auth_type'\] = 'http';#\$cfg['Servers'][\$i]['auth_type'] = 'http';#" $CFG

# Move configs from MySQl to MariaDB config location (e.g.)
mv /etc/mysql/conf.d/bind.cnf /etc/mysql/mariadb.conf.d/90-bind.cnf
# In some cases the upgrade of databases seems not work out (problems with mysql.proc)
mysql_upgrade -f -p
# have look into https://mariadb.com/kb/en/the-mariadb-library/moving-from-mysql-to-mariadb-in-debian-9/#configuration-options-for-advanced-database-users

# maybe we want to change some shorewall config stuff again
# shorewall needs to be enabled via systemctl, /etc/default is not used by systemd
systemctl enable shorewall

# Work around changing network interface names after update (https://github.com/systemd/systemd/issues/8446)
# Seen on VMWare guests
CFG="/etc/default/grub"; [ $(grep GRUB_CMDLINE_LINUX ${CFG} | grep 'net.ifnames=0 biosdevname=0') ] || sed -i 's/\(GRUB_CMDLINE_LINUX=".*\)"/\1 net.ifnames=0 biosdevname=0"/' ${CFG} && sed -i 's/GRUB_CMDLINE_LINUX=" /GRUB_CMDLINE_LINUX="/' ${CFG} && update-grub

# full-upgrade
apt-get dist-upgrade

# Migrate php5 packages over to php meta packages
apt install $(dpkg -l |grep php5 | awk '/^i/ { print $2 }' |grep -v ^php5$ |sed s/php5/php/)
# Fix IfModule mod_php5 in apache2 vHosts
sed -i "s/IfModule mod_php5/IfModule mod_php7/g" /etc/apache2/sites-available/*
# are there config needed to me migrated over to php my hand?
ls -la /etc/php5/{apache2,cli}/conf.d/
a2dismod php5; a2enmod php7.0 && systemctl restart apache2; ls -la /etc/apache2/mods-enabled/*php*

# Fix our ssh pub key package configuration
[ -x /var/lib/dpkg/info/config-openssh-server-authorizedkeys-core.postinst ] && \
  /var/lib/dpkg/info/config-openssh-server-authorizedkeys-core.postinst configure

# snmpd now runs as Debian-snmp user, fixing sudo config
sed -i s/snmp/Debian-snmp/ /etc/sudoers.d/*

# Upgrade postgres
# See also https://www.debian.org/releases/stretch/amd64/release-notes/ch-information.de.html#plperl
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

# Fix forbitten dovecot ssl_protocols
sed -i "s/\!SSLv2 \!SSLv3/\!SSLv3/g" /etc/dovecot/local.conf && service dovecot restart

# If you are using bind9 named and chrooted it, apparmor needs to know about it now
echo "/var/lib/named/** rwm," >> /etc/apparmor.d/local/usr.sbin.named && apparmor_parser -r /etc/apparmor.d/usr.sbin.named && systemctl restart bind9

# Install / Upgrade ruby-rmagick to have correct version  for redmine
aptitude install ruby-rmagick apache2

# xen: use our own bridge script again, when we did before
#[ $(grep "^(vif-script vif-bridge-local" /etc/xen/xend-config.sxp | wc -l) -gt 0 ] && \
# sed -i 's/#vif.default.script="vif-bridge"/vif.default.script="vif-bridge-local"/' /etc/xen/xl.conf

# migrate/backup your images (before) migrating to docker overlay2 storage driver
# umount /var/lib/docker/aufs; rm -rf /var/lib/docker/aufs

# remove old squeeze packages left around (keep eyes open!)
apt autoremove && \
apt purge $(dpkg -l | awk '/gcc-4.9/ { print $2 }') && \
apt purge $(aptitude search ?obsolete | grep -v -E 'linux-image|mailscanner|kerio|hpacucli|check-openmanage' | awk '/^i *A/ { print $3 }') && \
apt purge $(aptitude search ?obsolete | grep -v -E 'linux-image|mailscanner|kerio|hpacucli|check-openmanage' | awk '/^i/ { print $2 }') && \
apt purge $(dpkg -l | grep etch | grep -v xen | grep -v unbound | grep -v finch | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep lenny | grep -v xen | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb6|squeeze' | grep -v xen | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb7|wheezy' | grep -v xen | grep -v  -E 'linux-image|mailscanner|openswan|debian-security-support' | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb8|jessie' | grep -v xen | grep -v  -E 'linux-image|debian-security-support' | awk '{ print $2 }') && \
apt -y install deborphan && apt purge $(deborphan | grep -v xen | grep -v -E 'libpam-cracklib|libapache2-mpm-itk')
apt purge $(dpkg -l | awk '/^rc/ { print $2 }')

# for the brave YoloOps crowd
reboot && sleep 180; echo u > /proc/sysrq-trigger ; sleep 2 ; echo s > /proc/sysrq-trigger ; sleep 2 ; echo b > /proc/sysrq-trigger

### not needed until now
# mysql
# remove anonymous mysql access
#mysql -u root -p -e "DELETE FROM mysql.user WHERE User=''; DELETE FROM mysql.db WHERE Db='test' AND Host='%' OR Db='test\\_%' AND Host='%'; FLUSH PRIVILEGES;"

# dont use iptables when creating xen vifs
#cp /etc/xen/scripts/vif-bridge /etc/xen/scripts/vif-bridge-local
#sed -i "s/^    handle_iptable/    true/g" /etc/xen/scripts/vif-bridge-local
#sed -i "s/^(vif-script vif-bridge)/(vif-script vif-bridge-local)/" /etc/xen/xend-config.sxp

# xen
#/bin/sed -i -e 's/^[# ]*\((dom0-min-mem\).*\().*\)$/\1 512\2/' /etc/xen/xend-config.sxp
#sed -i s/XENDOMAINS_RESTORE=true/XENDOMAINS_RESTORE=false/ /etc/default/xendomains
#sed -i s#XENDOMAINS_SAVE=/var/lib/xen/save#XENDOMAINS_SAVE=\"\"# /etc/default/xendomains
#dpkg-divert --divert /etc/grub.d/09_linux_xen --rename /etc/grub.d/20_linux_xen
#echo 'GRUB_CMDLINE_XEN="dom0_mem=512M"' >> /etc/default/grub

# migrate expose.ini
#[ -f /etc/php5/conf.d/expose.ini ] && mv /etc/php5/conf.d/expose.ini \
# /etc/php5/mods-available/local-expose.ini && php5enmod local-expose/90
# migrate local suhosin config
#find /etc/php5/conf.d/ -type f -name "*suhosin.ini" -exec mv '{}' \
# /etc/php5/mods-available/local-suhosin.ini \; && php5enmod local-suhosin/90
