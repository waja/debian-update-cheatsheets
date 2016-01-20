# when <Directory > config is applied on / instead of DocumentRoot, we need to fix that
cat > /tmp/a2conf_dir_migrate << EOF
grep -i "<directory />" /etc/apache2/sites-enabled/*
for HOST in \$(grep -i "<directory />" /etc/apache2/sites-enabled/* | grep -v 000-default | awk -F':' '{print \$1}' | sed "s/.conf//" | sed "s#^/etc/apache2/sites-enabled/##"); do
	DOCROOT=\$(grep DocumentRoot /etc/apache2/sites-enabled/\${HOST} | awk '{print \$2}');
	sed -i "s#<Directory />#<Directory \${DOCROOT}>#" /etc/apache2/sites-available/\${HOST};
done
echo -e "Migration done.\nRemaining problematic configurations, please investigate:"
grep -i "<directory />" /etc/apache2/sites-enabled/*
EOF
sh /tmp/a2conf_dir_migrate
