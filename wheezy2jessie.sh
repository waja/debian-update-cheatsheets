Please also refer to http://www.debian.org/releases/jessie/releasenotes and use your brain!


# upgrade to UTF-8 locales (http://www.debian.org/releases/jessie/amd64/release-notes/ap-old-stuff.en.html#switch-utf8)
dpkg-reconfigure locales

# remove unused config file
rm -rf /etc/network/options /etc/environment
 
# Transition and remove entries from older releases
sed -i s#/backports.org/debian#/ftp.de.debian.org/debian#g /etc/apt/sources.list*
sed -i s/debian-backports/debian/g /etc/apt/sources.list*
sed -i /etch/d /etc/apt/sources.list*
sed -i /lenny/d /etc/apt/sources.list*
sed -i /sarge/d /etc/apt/sources.list*
sed -i /squeeze/d /etc/apt/sources.list*
sed -i /volatile/d /etc/apt/sources.list*
sed -i /proposed-updates/d /etc/apt/sources.list*
# change distro (please move 3rd party sources to /etc/apt/sources.list.d/), maybe look into http://ftp.cyconet.org/debian/sources.list.d/
sed -i s/wheezy/jessie/g /etc/apt/sources.list*
sed -i "s/ stable/ jessie/g" /etc/apt/sources.list*
sed -i s/wheezy/jessie/g /etc/apt/preferences*
sed -i s/wheezy/jessie/g /etc/apt/sources.list.d/*wheezy*
rename s/wheezy/jessie/g /etc/apt/sources.list.d/*wheezy*
aptitude update

# check package status
dpkg --audit
aptitude search "~ahold" | grep "^.h"
dpkg --get-selections | grep hold
 
# unmark packages auto
aptitude unmarkauto vim
aptitude unmarkauto $(dpkg-query -W 'linux-image-3.2.*' | cut -f1)
 
# have a look into required and free disk space
apt-get -o APT::Get::Trivial-Only=true dist-upgrade || df -h

# record session
script -t 2>~/upgrade-jessie.time -a ~/upgrade-jessie.script

# install our preseed so libc doesn't whine
cat > /tmp/jessie.preseed <<EOF
libc6 glibc/upgrade boolean true
libc6 glibc/restart-services string
libc6 libraries/restart-without-asking boolean true
EOF
/usr/bin/debconf-set-selections /tmp/jessie.preseed

# update aptitude first
[ "$(which aptitude)" = "/usr/bin/aptitude" ] && aptitude install aptitude

# minimal system upgrade (keep sysvinit / see http://noone.org/talks/debian-ohne-systemd/debian-ohne-systemd-clt.html#%2811%29)
aptitude upgrade '~U' 'sysvinit-core+'

# (re)enable wheel
if [ -f /etc/pam.d/su.dpkg-new ]; then CFG=/etc/pam.d/su.dpkg-new; else CFG=/etc/pam.d/su; fi
sed -i "s/# auth       required   pam_wheel.so/auth       required   pam_wheel.so/" $CFG

# (re)configure snmpd
if [ -f /etc/snmp/snmpd.conf.dpkg-new ]; then CFG=/etc/snmp/snmpd.conf.dpkg-new; \
   else CFG=/etc/snmp/snmpd.conf; fi
sed -i "s^#rocommunity secret  10.0.0.0/16^rocommunity mycommunity^g" $CFG
sed -i s/#agentAddress/agentAddress/ $CFG
sed -i "s/^ rocommunity public/# rocommunity public/" $CFG
sed -i "s/^ rocommunity6 public/# rocommunity6 public/" $CFG
sed -i "s/agentAddress  udp:127/#agentAddress  udp:127/" $CFG

# chrony update
if [ -f /etc/chrony/chrony.conf.new ]; then CFG=/etc/chrony/chrony.conf.new; else CFG=/etc/chrony/chrony.conf; fi
sed -i s/debian.pool/de.pool/g $CFG

# randomize crontab
if [ -f /etc/crontab.dpkg-new ]; then CFG=/etc/crontab.dpkg-new; else CFG=/etc/crontab; fi
sed -i 's#root    cd#root    perl -e "sleep int(rand(300))" \&\& cd#' $CFG
sed -i 's#root\ttest#root\tperl -e "sleep int(rand(3600))" \&\& test#' $CFG

# phpmyadmin
if [ -f /etc/phpmyadmin/config.inc.php.dpkg-new ]; then CFG=/etc/phpmyadmin/config.inc.php.dpkg-new; \
   else CFG=/etc/phpmyadmin/config.inc.php; fi
sed -i "s/\['auth_type'\] = 'cookie'/\['auth_type'\] = 'http'/" $CFG
sed -i "s#//\$cfg\['Servers'\]\[\$i\]\['auth_type'\] = 'http';#\$cfg['Servers'][\$i]['auth_type'] = 'http';#" $CFG

# maybe we want to change some shorewall config stuff again
sed -i s/^startup=0/startup=1/ /etc/default/shorewall

# full-upgrade
aptitude full-upgrade

# Apache2 config migration
# see also /usr/share/doc/apache2/NEWS.Debian.gz
#
# migrate sites into new naming scheme
perl /usr/share/doc/apache2/migrate-sites.pl
# migrate server config snippets into new directory
APACHE2BASEDIR="/etc/apache2"; for CONF in $(ls -l ${APACHE2BASEDIR}/conf.d/ | grep -v ^l | awk {'print $9'} | grep -v ^$); do
	if ! [ ${CONF##*.} == "conf" ]; then
		mv ${APACHE2BASEDIR}/conf.d/${CONF} ${APACHE2BASEDIR}/conf.d/${CONF}.conf
		CONF="${CONF}.conf"
	fi
	mv ${APACHE2BASEDIR}/conf.d/${CONF} ${APACHE2BASEDIR}/conf-available/${CONF}
	# enable this
	CONF=$(basename ${CONF} .conf)
	a2enconf ${CONF}
done
# migrate standard Options config to valid one
sed -i "s/Options ExecCGI/Options +ExecCGI/" /etc/apache2/sites-available/*
# fix probable Piped Logs
sed -i 's/|exec /| /' /etc/apache2/sites-available/*
# check for probably incompatible Apache configration statements (see https://gist.github.com/waja/86a3a055c1fedfba3c58#upstream-changes)
rgrep -iE  "(Order|Allow|Deny|Satisfy) " /etc/apache2/conf-enabled/* | grep -v ":#" && rgrep -iE  "(Order|Allow|Deny|Satisfy) " /etc/apache2/sites-enabled/* | grep -v ":#"

# serveral changes may be needed to adjust content of config files
# see https://gist.github.com/waja/86a3a055c1fedfba3c58#file-apache2.0to2.4.md

# migrate redmine plugins
mv /usr/share/redmine/vendor/plugins/* /usr/share/redmine/plugins/ && rmdir /usr/share/redmine/vendor/plugins/
# Remove inconsistent link in /usr/share/redmine/vendor/rails
rm /usr/share/redmine/vendor/rails
# migrate database config for mysql
sed -i "s/adapter: mysql/adapter: mysql2/" /etc/redmine/default/database.yml

# Fixing Typo bug in claav-daemon (http://bugs.debian.org/778507)
sed -i "s/DEBCONFILE/DEBCONFFILE/" /var/lib/dpkg/info/clamav-daemon.postinst

# remove old squeeze packages left around (keep eyes open!)
apt-get autoremove
aptitude search ?obsolete
dpkg -l | grep etch | grep -v xen | grep -v unbound | grep -v finch | awk '{print $2}' | xargs aptitude -y purge
dpkg -l | grep lenny | grep -v xen | awk '{print $2}' | xargs aptitude -y purge
dpkg -l | grep squeeze | grep -v xen | awk '{print $2}' | xargs aptitude -y purge
dpkg -l | grep -E 'deb7|wheezy' | grep -v xen | grep -v linux-image | awk '{print $2}' | xargs aptitude -y purge
aptitude -y install deborphan && deborphan | grep -v xen | grep -v libpam-cracklib | xargs aptitude -y purge
dpkg -l | grep ^r | awk '{print $2}' | xargs aptitude -y purge

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
