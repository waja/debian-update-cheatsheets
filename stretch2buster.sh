Please also refer to http://www.debian.org/releases/buster/releasenotes and use your brain!


# upgrade to UTF-8 locales (http://www.debian.org/releases/buster/amd64/release-notes/ap-old-stuff.en.html#switch-utf8)
dpkg-reconfigure locales

# remove unused config file
rm -rf /etc/network/options /etc/environment

# migrate over to systemd (before the upgrade) / you might want reboot if you install systemd
aptitude install systemd systemd-sysv libpam-systemd

# are there 3rd party packages installed? (https://www.debian.org/releases/buster/amd64/release-notes/ch-upgrading.de.html#system-status)
aptitude search '~i(!~ODebian)'

# check for ftp protocol in sources lists (https://www.debian.org/releases/buster/amd64/release-notes/ch-information.en.html#deprecation-of-ftp-apt-mirrors)
rgrep --color "deb ftp" /etc/apt/sources.list*

# Transition and remove entries from older releases
sed -i /etch/d /etc/apt/sources.list*
sed -i /lenny/d /etc/apt/sources.list*
sed -i /sarge/d /etc/apt/sources.list*
sed -i /squeeze/d /etc/apt/sources.list*
sed -i /wheezy/d /etc/apt/sources.list*
sed -i /jessie/d /etc/apt/sources.list*
sed -i /volatile/d /etc/apt/sources.list*
sed -i /proposed-updates/d /etc/apt/sources.list*
# change distro (please move 3rd party sources to /etc/apt/sources.list.d/), maybe look into http://ftp.cyconet.org/debian/sources.list.d/
sed -i s/stretch/buster/g /etc/apt/sources.list*
sed -i "s/ stable/ buster/g" /etc/apt/sources.list*
sed -i s/stretch/buster/g /etc/apt/preferences*
sed -i s/stretch/buster/g /etc/apt/sources.list.d/*stretch*
rename s/stretch/buster/g /etc/apt/sources.list.d/*stretch*
rgrep --color stretch /etc/apt/sources.list*
apt-get update

# check package status
dpkg --audit
aptitude search "~ahold" | grep "^.h"
dpkg --get-selections | grep hold
 
# unmark packages auto
aptitude unmarkauto vim net-tools && \
aptitude unmarkauto libapache2-mpm-itk && \
aptitude unmarkauto $(dpkg-query -W 'linux-image-4.9.0*' | cut -f1)
 
# have a look into required and free disk space
apt-get -o APT::Get::Trivial-Only=true dist-upgrade || df -h

# record session
script -t 2>~/upgrade-buster.time -a ~/upgrade-buster.script

# install our preseed so libc doesn't whine
cat > /tmp/stretch.preseed <<EOF
libc6 glibc/upgrade boolean true
libc6 glibc/restart-services string
libc6 libraries/restart-without-asking boolean true
EOF
/usr/bin/debconf-set-selections /tmp/stretch.preseed

# update aptitude first
[ "$(which aptitude)" = "/usr/bin/aptitude" ] && aptitude install aptitude

# minimal system upgrade
aptitude upgrade

# chrony update
if [ -f /etc/chrony/chrony.conf.new ]; then CFG=/etc/chrony/chrony.conf.new; else CFG=/etc/chrony/chrony.conf; fi
sed -i s/2.debian.pool/0.de.pool/g $CFG

# migrate unattended-upgrades config
if [ -f /etc/apt/apt.conf.d/50unattended-upgrades.dpkg-new ]; then CFG=/etc/apt/apt.conf.d/50unattended-upgrades.dpkg-new; \
   else CFG=/etc/apt/apt.conf.d/50unattended-upgrades; fi
sed -i s/stretch/buster/g $CFG
sed -i s/crontrib/contrib/g $CFG
sed -i "s#// If automatic reboot is enabled and needed, reboot at the specific#// Automatically reboot even if there are users currently logged in.\n//Unattended-Upgrade::Automatic-Reboot-WithUsers \"true\";\n\n// If automatic reboot is enabled and needed, reboot at the specific#" $CFG
cat >> $CFG <<EOF

// Enable logging to syslog. Default is False
// Unattended-Upgrade::SyslogEnable "false";

// Specify syslog facility. Default is daemon
// Unattended-Upgrade::SyslogFacility "daemon";

EOF

## phpmyadmin
if [ -f /etc/phpmyadmin/config.inc.php.dpkg-new ]; then CFG=/etc/phpmyadmin/config.inc.php.dpkg-new; \
   else CFG=/etc/phpmyadmin/config.inc.php; fi
sed -i "s/\['auth_type'\] = 'cookie'/\['auth_type'\] = 'http'/" $CFG
sed -i "s#//\$cfg\['Servers'\]\[\$i\]\['auth_type'\] = 'http';#\$cfg['Servers'][\$i]['auth_type'] = 'http';#" $CFG

# full-upgrade
apt-get dist-upgrade

# remove old squeeze packages left around (keep eyes open!)
apt autoremove && \
apt purge $(dpkg -l | awk '/gcc-4.9/ { print $2 }') && \
apt purge $(aptitude search ?obsolete | grep -v -E 'linux-image|mailscanner' | awk '/^i *A/ { print $3 }') && \
apt purge $(aptitude search ?obsolete | grep -v -E 'linux-image|mailscanner' | awk '/^i/ { print $2 }') && \
apt purge $(dpkg -l | grep etch | grep -v xen | grep -v unbound | grep -v finch | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep lenny | grep -v xen | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb6|squeeze' | grep -v xen | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb7|wheezy' | grep -v xen | grep -v  -E 'linux-image|mailscanner|openswan|debian-security-support' | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb8|jessie' | grep -v xen | grep -v  -E 'linux-image|debian-security-support' | awk '{ print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb9|stretch' | grep -v xen | grep -v  -E 'linux-image|debian-security-support' | awk '{ print $2 }') && \
apt -y install deborphan && apt purge $(deborphan | grep -v xen | grep -v -E 'libpam-cracklib|libapache2-mpm-itk')
apt purge $(dpkg -l | awk '/^rc/ { print $2 }')

# for the brave YoloOps crowd
reboot && sleep 180; echo u > /proc/sysrq-trigger ; sleep 2 ; echo s > /proc/sysrq-trigger ; sleep 2 ; echo b > /proc/sysrq-trigger

### not needed until now
# Fix our ssh pub key package configuration
[ -x /var/lib/dpkg/info/config-openssh-server-authorizedkeys-core.postinst ] && \
  /var/lib/dpkg/info/config-openssh-server-authorizedkeys-core.postinst configure

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
