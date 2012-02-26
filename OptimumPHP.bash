#!/bin/bash
#
# READ THE README BEFORE ATTEMPTING TO USE THIS SCRIPT.
#
# OptimumPHP, Copyright 2012 P'unk Avenue, LLC. Released under the
# terms of the MIT License. See the LICENSE file.
#

USAGE="Usage: update-php.bash version max-php-processes"

if [ -z "$1" ] ; then
  echo $USAGE
  exit 1
fi

if [ -z "$2" ] ; then
  echo $USAGE
  exit 1
fi

VERSION=$1
LIMIT=$2

CODENAME=`cat /etc/lsb-release | grep DISTRIB_CODENAME | perl -p -e 's/DISTRIB_CODENAME=(\w+)/$1/'`

if [ -z "$CODENAME" ] ; then
  echo "This doesn't smell like an Ubuntu box (or Perl is not installed yet)."
  exit 1
fi

echo "Making sure gcc, Apache, MySQL and various libraries are installed"
apt-get -y install build-essential apache2 libxml2-dev libcurl4-openssl-dev \
  libcurl4-openssl-dev libjpeg-dev libpng-dev libfreetype6-dev libicu-dev \
  libmcrypt-dev mysql-server mysql-client libmysqlclient-dev libxslt-dev \
  autoconf libltdl-dev || 
  { echo "apt-get installs failed"; exit 1; } 

rm -f php-$VERSION.tar.gz &&
rm -rf php-$VERSION
wget --trust-server-names http://us3.php.net/get/php-$VERSION.tar.gz/from/us.php.net/mirror &&
tar -zxf php-$VERSION.tar.gz &&
cd php-$VERSION &&
# CGI (fastcgi) binary. Also installs CLI binary
'./configure' '--enable-fastcgi' '--with-gd' '--with-pdo-mysql' '--with-curl' '--with-mysql' '--with-freetype-dir=/usr' '--with-jpeg-dir=/usr' '--with-mcrypt' '--with-zlib' '--enable-mbstring' '--enable-ftp' '--with-xsl' '--with-openssl' '--with-kerberos' '--enable-exif' '--enable-intl' &&
#5.3.10 won't build in Ubuntu 11.10 without this additional library
perl -pi -e 's/^EXTRA_LIBS = /EXTRA_LIBS = -lstdc++ /' Makefile
make clean &&
make &&
make install &&
pecl channel-update pecl.php.net &&
pecl config-set php_ini /usr/local/lib/php.ini 

echo "Installing pecl packages"

# pecl's conf settings for tmp folders don't cover all of its
# usages of /tmp and /var/tmp. So make sure /var/tmp allows exec. But don't
# mess with it if someone has a tmp partition that isn't actually noexec,
# or a noexec partition that isn't actually tmp
TMPFS=`mount | grep /var/tmp | grep noexec | wc -l`
if [ "$TMPFS" != "0" ] ; then
  echo "Temporarily enabling exec in /var/tmp since PECL is hardcoded to use it"
  mount -o,remount,rw,exec /var/tmp || { echo "Unable to remount /var/tmp with exec permissions"; exit 1; }
fi

(printf "\n" | pecl install -f apc) &&
pecl install -f mongo

# Regardless of whether any of that failed make sure we
# put the tmp folder back to noexec
if [ "$TMPFS" != "0" ] ; then
  echo "Re-disabling exec in /var/tmp"
  mount -o,remount,rw,noexec /var/tmp || { echo "Unable to remount /var/tmp with noexec permissions"; exit 1; } 
fi

CONFIGURED=`grep '^extension=mongo.so' /usr/local/lib/php.ini`

if [ -z "$CONFIGURED" ] ; then
  cat >> /usr/local/lib/php.ini <<EOM
extension=apc.so
apc.enabled=1
; 60mb is enough to hold most modern frameworks in the shared APC cache
apc.shm_size=60M
; You can skip this if you don't want to talk to MongoDB
extension=mongo.so
; PHP doesn't do this for us for some reason
date.timezone=`cat /etc/timezone`
; Allow uploads of reasonably large files,
; such as originals of photos
upload_max_filesize = 32M
post_max_size = 32M
; Allow enough memory to compile the framework on that first pageload before it's all in APC,
; enough memory for big gd manipulations, etc.
memory_limit = 64M
; Losing your work sucks. Half day sessions are fine for most sites. If you're running
; a bank, shorten this
session.gc_maxlifetime = 43200
; Enough time for heavy operations
max_execution_time = 120
; Don't hang up halfway through that upload
max_input_time = 200
; arg_separator must be the traditional one for Apostrophe. IMHO it is not the job of
; every URL manipulating function to assume you're outputting it in HTML markup rather
; than issuing a redirect or similar
arg_separator.input = "&"
EOM
fi

# Did all this work?

SAPIS=`/usr/local/bin/php-config --php-sapis`

if [ "$SAPIS" != "cli cgi" ] ; then
  echo "/usr/local/bin/php-config doesn't see cli and cgi as the installed SAPIs, something didn't work."
  exit 1
fi

VERSION=`/usr/local/bin/php-config --version`

if [ "$VERSION" != "$VERSION" ] ; then
  echo "/usr/local/bin/php-config doesn't report the requested version of PHP, something didn't work."
  exit 1
fi

APC=`/usr/local/bin/php -i | grep apc`

if [ -z "$APC" ] ; then
  echo "No mention of apc in php -i output. A pecl install command failed or wrote to the wrong extensions folder."
  exit 1
fi

MONGO=`/usr/local/bin/php -i | grep mongo`

if [ -z "$MONGO" ] ; then
  echo "No mention of mongo in php -i output. A pecl install command failed or wrote to the wrong extensions folder."
  exit 1
fi

MULTIVERSE=`grep -c multiverse /etc/apt/sources.list`

if [ "$MULTIVERSE" == "0" ] ; then
  echo "Adding multiverse repositories to /etc/apt/sources.list so we can install real fastcgi."
  echo "(fcgid is not an adequate substitute, it doesn't support APC.)"
  cat  >> /etc/apt/sources.list <<EOM
# tom@punkave.com: we want multiverse support so we can have real mod_fastcgi
deb http://us.archive.ubuntu.com/ubuntu/ $CODENAME multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ $CODENAME multiverse
deb http://us.archive.ubuntu.com/ubuntu/ $CODENAME-updates multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ $CODENAME-updates multiverse
EOM
fi

apt-get update &&
apt-get install libapache2-mod-fastcgi &&

cat > /etc/apache2/mods-available/fastcgi.conf <<EOM
<IfModule mod_fastcgi.c>
  # One shared PHP-managed fastcgi for all sites
  Alias /fcgi /var/local/fcgi
  # IMPORTANT: without this we get more than one instance
  # of our wrapper, which itself spawns many PHP processes, so
  # that would be Bad (tm)
  FastCgiConfig -idle-timeout 20 -maxClassProcesses 1
  <Directory /var/local/fcgi>
    # Use the + so we don't clobber other options that
    # may be needed. You might want FollowSymLinks here
    Options +ExecCGI
  </Directory>
  AddType application/x-httpd-php5 .php
  AddHandler fastcgi-script .fcgi
  Action application/x-httpd-php5 /fcgi/php-cgi-wrapper.fcgi
</IfModule>
EOM

mkdir -p /var/local/fcgi/ &&

cat > /var/local/fcgi/php-cgi-wrapper.fcgi <<EOM
#!/bin/sh

# We like to use the same settings we formerly used for apache mod_php. 
# You don't want this if your php.ini is in /etc
PHPRC="/etc/php5/apache2"
export PHPRC
# We can accommodate about 20 50mb processes on a 1GB slice. More than that
# will swap, making people wait and locking us out of our own box.
# Better idea: just make people wait to begin with
PHP_FCGI_CHILDREN=$LIMIT
PHP_FCGI_MAX_REQUESTS=100
export PHP_FCGI_CHILDREN
exec /usr/local/bin/php-cgi -c /usr/local/lib/php.ini
EOM

chmod -R 755 /var/local/fcgi &&
# Chicken and egg problems galore if we don't switch to fastcgi before we switch to worker thread MPM
# Also we use stop, sleep, start because restart is too clever and doesn't finish the job sometimes
echo "Restarting Apache in a FastCGI configuration" &&
if [ -e /etc/apache2/mods-enabled/php5.load ] ; then
  a2dismod php5 
fi && a2enmod fastcgi && a2enmod actions && apache2ctl stop && sleep 5 && apache2ctl start &&
echo "Switching Apache to the Worker MPM configuration" &&
apt-get -y install apache2-mpm-worker &&
echo "Stopping and starting because Apache usually botches that the first time after the switch" &&
sleep 5 && apache2ctl stop && sleep 5 && apache2ctl start && 
echo "DONE! Now go check your websites. If you have trouble see http://punkave.com/window/2010/03/08/faster-php-kill-kill"

