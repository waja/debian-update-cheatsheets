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

# Set for example a package on hold
PACKAGE="mailscanner"; echo $PACKAGE hold |dpkg --set-selections; aptitude hold $PACKAGE

# check package status
dpkg --audit
aptitude search "~ahold" | grep "^.h"
dpkg --get-selections | grep hold
 
# unmark packages auto
aptitude unmarkauto vim && \
aptitude unmarkauto monitoring-plugins-standard monitoring-plugins-common monitoring-plugins-basic && \
aptitude unmarkauto open-vm-tools-dkms ifenslave && \
aptitude unmarkauto xen-system-amd64 && aptitude unmarkauto $(dpkg-query -W 'xen-linux-system-*' | cut -f1) \
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

# remove php5-suhosin, which doesn't exist in jessie anymore
if [ "$( dpkg -l | grep "^ii.*php5-suhosin" | wc -l)" -ge "1" ]; then \
   apt-get remove php5-suhosin
fi
# remove obsolete php5-ps
if [ "$( dpkg -l | grep "^ii.*php5-ps" | wc -l)" -ge "1" ]; then \
   apt-get remove php5-ps
fi
# minimal system upgrade (keep sysvinit / see http://noone.org/talks/debian-ohne-systemd/debian-ohne-systemd-clt.html#%2811%29)
aptitude upgrade '~U' 'sysvinit-core+'

# (re)enable wheel
if [ -f /etc/pam.d/su.dpkg-new ]; then CFG=/etc/pam.d/su.dpkg-new; else CFG=/etc/pam.d/su; fi
sed -i "s/# auth       required   pam_wheel.so/auth       required   pam_wheel.so/" $CFG

# (re)configure snmpd
COMMUNITY="mycommunity"; \
if [ -f /etc/snmp/snmpd.conf.dpkg-new ]; then CFG=/etc/snmp/snmpd.conf.dpkg-new; \
   else CFG=/etc/snmp/snmpd.conf; fi
sed -i "s^#rocommunity secret  10.0.0.0/16^rocommunity $COMMUNITY^g" $CFG
sed -i s/#agentAddress/agentAddress/ $CFG
sed -i "s/^ rocommunity public/# rocommunity public/" $CFG
sed -i "s/^ rocommunity6 public/# rocommunity6 public/" $CFG
sed -i "s/agentAddress  udp:127/#agentAddress  udp:127/" $CFG

# fix our xen modification
[ -f /etc/grub.d/20_linux_xen ] && rm -rf /etc/grub.d/09_linux_xen && \
 dpkg-divert --divert /etc/grub.d/09_linux_xen --rename /etc/grub.d/20_linux_xen

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
# nat helper needs to be install (http://shorewall.net/Helpers.html#idp8854577312)
ucf /usr/share/shorewall/configfiles/conntrack /etc/shorewall/conntrack

# full-upgrade
aptitude full-upgrade

# Apache2 config migration
# see also /usr/share/doc/apache2/NEWS.Debian.gz
#
# migrate sites into new naming scheme
perl /usr/share/doc/apache2/migrate-sites.pl
# migrate server config snippets into new directory
cat > /tmp/a2confmigrate << EOF
APACHE2BASEDIR="/etc/apache2"; for CONF in \$(ls -l \${APACHE2BASEDIR}/conf.d/ | grep -v ^l | awk '{print \$9}' | grep -v ^$); do
	if ! [ "\${CONF##*.}" == "conf" ]; then
		mv \${APACHE2BASEDIR}/conf.d/"\${CONF}" \${APACHE2BASEDIR}/conf.d/"\${CONF}".conf
		CONF="\${CONF}.conf"
	fi
	mv \${APACHE2BASEDIR}/conf.d/"\${CONF}" \${APACHE2BASEDIR}/conf-available/"\${CONF}"
	# enable this
	CONF=\$(basename "\${CONF}" .conf)
	a2enconf "\${CONF}"
done
EOF
sh /tmp/a2confmigrate
# migrate standard Options config to valid one
sed -i "s/Options ExecCGI/Options +ExecCGI/" /etc/apache2/sites-available/*
# fix probable Piped Logs
sed -i 's/|exec /| /' /etc/apache2/sites-available/*
# check for probably incompatible Apache configration statements (see https://gist.github.com/waja/86a3a055c1fedfba3c58#upstream-changes)
# Even lists conditional statements which might be not a problem
rgrep -iE  "(Order|Allow|Deny|Satisfy) " /etc/apache2/conf-enabled/* | grep -v ":#" && rgrep -iE  "(Order|Allow|Deny|Satisfy) " /etc/apache2/sites-enabled/* | grep -v ":#"
# just in case you have you DocumentRoots in /var/www, you might want to also check for .htaccess containing those
# Even lists conditional statements which might be not a problem
rgrep -iE  "(Order|Allow|Deny|Satisfy) " --include .htaccess /var/www/ | grep -v ":#"

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

# Upgrade postgres
if [ "$(dpkg -l | grep "postgresql-9.1" | awk {'print $2'})" = "postgresql-9.1" ]; then \
 aptitude install postgresql-9.4 && \
 pg_dropcluster --stop 9.4 main && \
 /etc/init.d/postgresql stop && \
 pg_upgradecluster -v 9.4 9.1 main && \
 sed -i "s/^manual/auto/g" /etc/postgresql/9.4/main/start.conf && \
 sed -i "s/^port = .*/port = 5432/" /etc/postgresql/9.4/main/postgresql.conf && \
 sed -i "s/^shared_buffers = .*/shared_buffers = 128MB/" /etc/postgresql/9.4/main/postgresql.conf && \
 /etc/init.d/postgresql restart; \
fi
pg_dropcluster 9.1 main

# xen: use our own bridge script again, when we did before
[ $(grep "^(vif-script vif-bridge-local" /etc/xen/xend-config.sxp | wc -l) -gt 0 ] && \
 sed -i 's/#vif.default.script="vif-bridge"/vif.default.script="vif-bridge-local"/' /etc/xen/xl.conf

# remove old squeeze packages left around (keep eyes open!)
apt-get autoremove && \
apt purge $(aptitude search ?obsolete | grep -v -E 'linux-image|xen-system|check-openmanage|mailscanner|hp-health|hpacucli' | awk '/^i *A/ { print $3 }') && \
apt purge $(aptitude search ?obsolete | grep -v -E 'linux-image|xen-system|check-openmanage|mailscanner|hp-health|hpacucli' | awk '/^i/ { print $2 }') && \
apt purge $(dpkg -l | grep etch | grep -v xen | grep -v unbound | grep -v finch | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep lenny | grep -v xen | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb6|squeeze' | grep -v xen | awk '/^rc/ { print $2 }') && \
apt purge $(dpkg -l | grep -E 'deb7|wheezy' | grep -v xen | grep -v  -E 'linux-image|mailscanner|openswan|debian-security-support' | awk '/^rc/ { print $2 }') && \
apt -y install deborphan && apt purge $(deborphan | grep -v xen | grep -v libpam-cracklib | awk '/^rc/ { print $2 }')
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
