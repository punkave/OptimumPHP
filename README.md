# Optimum PHP

## Introduction

Optimum PHP installs PHP (and Apache and MySQL, if not already present) 
according to best practices. That includes FastCGI to separate PHP page generation
from static file delivery, APC to ensure your PHP framework is not compiled over and
over on every page view, and the inclusion of support for MySQL, MongoDB, LDAP, GD
and other important but frequently missing PHP features. 

For more information about PHP best practices, be sure to read the article
[Faster, PHP! Kill! Kill!](http://punkave.com/window/2010/03/08/faster-php-kill-kill)

## Limitations

This script is currently for Ubuntu and CentOS Linux systems. It has been tested with CentOS 5.6, Ubuntu 10.04 and 11.04. Pull requests to better support more CentOS and Ubuntu versions are welcome. We'll also consider pull requests for other Linux distributions if they don't make the script unmanageably large - let's talk about it.

## What You Get

This script installs the specified version of PHP, from source, obtained 
directly from the official php.net mirrors. PHP is installed to 
`/usr/local/bin`. You get both the php commmand line binary and the PHP 
CGI/FastCGI binary.

Your Apache server will be reconfigured to use FastCGI rather than mod_php 
for drastically better average performance when the server is also responsible
for serving images, CSS, JavaScript, et cetera. A separate process pool for PHP
means your server is not tying up expensive PHP processes just to deliver 
static images. See the article cited above for details.

Your php.ini file will be tweaked with more realistic settings for Symfony,
Drupal, Apostrophe and other PHP frameworks. If you're picky about these things, be
sure to review what this script appends to `/usr/local/lib/php.ini`.

Apache and MySQL are also installed if you don't already have them, as 
well as many required libraries for PHP.

Your PHP build will include functions to access MySQL, MongoDB, LDAP and the gd
graphics functions - all the critical yet often missing stuff.

Only PHP and PHP extensions are installed from source. Everything else is 
installed via your operating system's package manager. We use pecl to install
PHP packages wherever it's not broken, svn only when necessary. We don't believe 
in maintaining anything from source unless you have to, but having the latest 
version of PHP itself is important to us. (Read up on the performance benefits
of PHP 5.4.x. They are significant.)

## Upgrading

You can safely run this script more than once, for instance if you wish to upgrade to a 
newer release of PHP.

## Warnings

Command line PHP will wind up in `/usr/local/bin`. Make sure your PATH looks 
there (even for cron jobs that invoke PHP).

FastCGI does not support overriding php.ini via .htaccess files. If you have
any php_value settings, Apache will display an error. Move those settings 
into php.ini.

If you experience out of memory errors, edit:

    /var/local/fcgi/php-cgi-wrapper.fcgi 

Reduce the PHP_FCGI_CHILDREN setting to a smaller figure. Then restart Apache,
or just do:

    killall php-cgi

Then hit your server with some PHP traffic to make sure you've brought the
setting down enough. Repeat if needed. You'll have best results if your server
has some swap space available to provide headroom.

Read http://punkave.com/window/2010/03/08/faster-php-kill-kill to understand
everything that is happening here and how to deal with anything that doesn't
work out.

## Usage Instructions

To install PHP version 5.4.5 with 15 PHP processes, run this command as root.
Most of the work will be done in `/tmp`, but you don't necesarily have to
put `OptimumPHP.bash` there:

    bash OptimumPHP.bash 5.4.5 15

NOTE: choosing the right number of PHP processes is quite important, so read 
on.

"What's a PHP process?" Each PHP process is a continuously running php-cgi 
process that is reused to handle more connections (and periodically 
restarted). The number of PHP processes you have is the number of simultaneous
requests your server can field without requiring any to wait.

"How many PHP processes can I have?" If your PHP processes top out around 50MB,
then 20 processes will take up 1GB, just about all the RAM on a server with
1GB of RAM (which must also run MySQL, Apache and so on). Do dial that back to
15 processes and you're in good shape.

We strongly recommend a server with some swap space as this allows for some
headroom for unexpected cases.

We have encountered some VPSes (Virtual Private servers) that run out of 
memory twice as fast as they should with fastcgi. Other, newer configurations
work fine. You'll have to experiment.

"What happens if I pick too large a number?" If you have swap space on your
server, it may just slow down. If you have no swap space, it is critical not
to make this setting too large. If you experience out of memory errors,
edit /var/local/fcgi/php-cgi-wrapper.fcgi and reduce the PHP_FCGI_CHILDREN 
setting to a smaller figure. Then restart Apache, or just do:

    killall php-cgi

Then hit your server with some PHP traffic to make sure you've brought the
setting down enough. Repeat if necessary until you find the sweet spot.

"How big are my PHP processes?" Look at the RSIZE value reported in 'top' 
for your Apache processes (if you are using plain old mod_php - if you don't
know, you probably have mod_php). If you are already using FastCGI, look at
your PHP processes. You can subtract a little overhead from Apache processes
since they do contain a bit of non-PHP related stuff.

"Shouldn't I just run lots of PHP processes and use swap space?" Not really.
If you have too much traffic you'll just grind your hard drive and slow down.
Better to let connections queue up and wait gracefully than to completely 
crush your server to the point where you can't ssh in to tune it.

"Why do you do (X) instead of (Y)?" This setup works well for us. You can 
read more about our rationale for it in the article I've cited twice already.
Feedback is welcome there.

## Credits

Optimum PHP was developed by P'unk Avenue, the creators of Apostrophe. 
Apostrophe is an open source content management system based on the Symfony
PHP framework. You can bet we have a need for well-configured PHP servers.

Learn more about the Apostrophe project here:

[Apostrophe, the Open Source Project](http://apostrophenow.org)

[Apostrophe Now, the Hosted Service](http://apostrophenow.com)

## Contact

Tom Boutell mostly maintains this. Feel free to drop him a line at 
[tom@punkave.com](mailto:tom@punkave.com).
