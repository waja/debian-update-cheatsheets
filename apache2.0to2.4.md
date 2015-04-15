# Migrating the Apache config files into new places and naming scheme

see https://gist.github.com/waja/86a3a055c1fedfba3c58#file-wheezy2jessie-sh

# Upstream changes

* [Order](http://httpd.apache.org/docs/2.4/mod/mod_access_compat.html#order), [Allow](http://httpd.apache.org/docs/2.4/mod/mod_access_compat.html#allow), [Deny](http://httpd.apache.org/docs/2.4/mod/mod_access_compat.html#deny) and [Satisfy](http://httpd.apache.org/docs/2.4/mod/mod_access_compat.html#satisfy) are obsolete, you should read [Run-Time Configuration Changes](http://httpd.apache.org/docs/2.4/upgrading.html#run-time) or [Beyond just authorization](http://httpd.apache.org/docs/2.4/howto/auth.html#beyond)
* Mixing [Options](http://httpd.apache.org/docs/current/mod/core.html#options) with a + or - with those without is not valid syntax, and will be rejected during server startup by the syntax check with an abort.
* Certificate handleing has changed, obsoletes [SSLCertificateChainFile](http://httpd.apache.org/docs/current/mod/mod_ssl.html#sslcertificatechainfile), please use [SSLCertificateFile](http://httpd.apache.org/docs/current/mod/mod_ssl.html#sslcertificatefile), it may also include intermediate CA certificates, sorted from leaf to root now
* Several other changes can be found in the [Upgrading to 2.4 from 2.2](http://httpd.apache.org/docs/2.4/upgrading.html) documentation


# Some more other handy resources

https://www.digitalocean.com/community/tutorials/migrating-your-apache-configuration-from-2-2-to-2-4-syntax
https://www.linode.com/docs/security/upgrading/updating-virtual-host-settings-from-apache-2-2-to-apache-2-4
http://linoxide.com/linux-how-to/apache-migration-2-2-to-2-4-ubuntu-14-04/
