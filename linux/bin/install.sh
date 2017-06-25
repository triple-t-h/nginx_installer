 #!/bin/bash
 #===============================================================================
 #
 #          FILE: install.sh
 #
 #         USAGE: ./install.sh
 #
 #   DESCRIPTION:  Version 1.0 Install and configures a local Web server with nginx and php
 #
 #       OPTIONS: ---
 #  REQUIREMENTS: ---
 #          BUGS: ---
 #         NOTES: ---
 #        AUTHOR: Daniel Schidlowski
 #  ORGANIZATION:
 #       CREATED: 02.10.2016 12:46:13
 #      REVISION: ---
 #===============================================================================

set -o nounset                              # Treat unset variables as an error

#-------------------------------------------------------------------------------
# Check the size of the console
#-------------------------------------------------------------------------------
set -- $(stty size 2> /dev/null || echo 0 0)
LINES=$1
COLUMNS=$2
if [ ${LINES} -eq 0 ]; then
    LINES=24
fi
if [ ${COLUMNS} -eq 0 ]; then
    COLUMNS=80
fi

#---  FUNCTION  ----------------------------------------------------------------
#          NAME: print_okay, print_failure, print_missing
#   DESCRIPTION: Display okay, error, missing information for this script.
#    PARAMETERS: ---
#       RETURNS: ---
#-------------------------------------------------------------------------------
print_okay() {
    echo -e "\033[${COLUMNS}C\033[15D[\e[1;32m OK \e[0m]"
}
print_failure() {
    echo -e "\033[${COLUMNS}C\033[15D[\e[1;31m FAILURE \e[0m]"
}
print_missing() {
    echo -e "\033[${COLUMNS}C\033[15D[\e[1;33m MISSING \e[0m]"
}
#-------------------------------------------------------------------------------
# Check for running this script as root?
#-------------------------------------------------------------------------------
echo -n "Check for running this script as root …"
if [ "$(whoami)" != "root" ]; then
    echo -n -e "\n   Error: This script needs to run as root!"
    print_failure
    exit 1
fi
print_okay
#-------------------------------------------------------------------------------
# Variables for this script.
#-------------------------------------------------------------------------------
APPLICATION_DIRECTORY=$(readlink -f $0 | grep -oE '.+nginx_installer')
PACKAGE_MANAGEMENT_SOFTWARE="zypper apt-get"
INSTALLER=""
WEB_COMPONENTS="nginx php5-fpm php5-bcmath php5-bz2 php5-ctype php5-curl php5-dom \
php5-ftp php5-gd php5-gettext php5-iconv php5-json php5-mbstring php5-mcrypt \
php5-mysql php5-openssl php5-pdo php5-posix php5-zip php5-zlib"
WEB_COMPONENTS_MISSING=""
VHOST_DIRECTORY=""
PHP_INI_DIRECTORY=""
PHP_FPM_DIRECTORY=""
#-------------------------------------------------------------------------------
# Check if package manager is installed?
#   zypper for openSUSE
#   apt-get for Debian, Ubuntu and other Derivatives
#-------------------------------------------------------------------------------
for i in $PACKAGE_MANAGEMENT_SOFTWARE; do
    echo -n "Check if package manager $i is installed …"
    "$i" &> /dev/null && INSTALLER="$i"
    case "$INSTALLER" in
        "zypper")
            print_okay
            break
            ;;
        "apt-get")
            print_okay
            break
            ;;
        "")
            print_missing
            continue
            ;;
    esac
done
#-------------------------------------------------------------------------------
# Process termination if no manager found!
# Satus: EXIT_FAILURE
#-------------------------------------------------------------------------------
if  [ -z "${INSTALLER}" ]; then
    echo -n "   Error: No package manager found!"
    print_failure
    exit 1
fi
#-------------------------------------------------------------------------------
# Check if packages is already installed?
#-------------------------------------------------------------------------------
for i in $WEB_COMPONENTS; do
    echo -n "Check if $i is already installed …"
    case "$INSTALLER" in
        "zypper")
            rpm -q "${i}" >/dev/null
            ;;
        "apt-get")
            #coming soon
            ;;
    esac    # --- end of case ---
    if [ $? -eq 0 ]; then
        print_okay
    else
        print_missing
        WEB_COMPONENTS_MISSING="$i $WEB_COMPONENTS_MISSING"
    fi
done
#-------------------------------------------------------------------------------
# Install missing packages.
#-------------------------------------------------------------------------------
if [ -n "${WEB_COMPONENTS_MISSING}" ] ; then
    $INSTALLER update
    $INSTALLER install -n ${WEB_COMPONENTS_MISSING}
fi
#-------------------------------------------------------------------------------
# Search www directory in filesystem hierarchy and changing to parent directory.
# /srv/www
#   or
# /var/www
#-------------------------------------------------------------------------------
echo -n "Search www directory in filesystem hierarchy …"
VHOST_DIRECTORY=$(find / -maxdepth 2 -regextype posix-egrep -regex "/(srv|var)/www")
if [ -n "$VHOST_DIRECTORY" ] ; then
    print_okay
    VHOST_DIRECTORY="${VHOST_DIRECTORY%/*}"
    cd "$VHOST_DIRECTORY"
else
    print_missing
    VHOST_DIRECTORY="/"
    cd "$VHOST_DIRECTORY"
fi
#-------------------------------------------------------------------------------
# If www directory exists remove.
#-------------------------------------------------------------------------------
if [ -n "www" ]; then
    rm -r www
fi
#-------------------------------------------------------------------------------
# Create vHost directories.
#-------------------------------------------------------------------------------
echo "Create directories …"
mkdir -p www/vhosts/{config,localhost/{htdocs,.sessions,.tmp,.log}}
cp "$APPLICATION_DIRECTORY/sources/index.html" www/vhosts/localhost/htdocs/index.html
#-------------------------------------------------------------------------------
# List contents of directories in a tree-like format.
#-------------------------------------------------------------------------------
ls -Ra www | grep ":$" | sed -e 's/:$//' -e 's/[^-][^\/]*\//--/g' -e 's/^/   /' -e 's/-/|/'
#-------------------------------------------------------------------------------
# Copy and paste nginx *.conf Files.
#-------------------------------------------------------------------------------
cp "$APPLICATION_DIRECTORY/linux/configs/localhost.conf" www/vhosts/config
sed -ie "s@{my-dir}@set \$dir ${VHOST_DIRECTORY/#\//\/}\/www\/vhosts\/localhost;@" www/vhosts/config/localhost.conf
cp "$APPLICATION_DIRECTORY/linux/configs/nginx.conf" /etc/nginx
sed -ie "s@{my-include}@include ${VHOST_DIRECTORY/#\//\/}\/www\/vhosts\/config\/localhost.conf;@" /etc/nginx/nginx.conf
chown -R nginx:nginx www
chown root:root www/vhosts/config
chmod 770 "$VHOST_DIRECTORY/www/vhosts/localhost/htdocs"
#-------------------------------------------------------------------------------
# Create symlink.
#-------------------------------------------------------------------------------
echo "Create symlink to all users with /home directory … "
ln -sf "$VHOST_DIRECTORY/www/vhosts/localhost/htdocs" /home/*/
echo -n "Add user to nginx group … "
awk -F':' '/home/ { print $1; system("usermod -aG nginx "$1) }' /etc/passwd
#-------------------------------------------------------------------------------
# Copy and paste php *.conf Files.
#-------------------------------------------------------------------------------
case "$INSTALLER" in
    "zypper")
        PHP_INI_DIRECTORY=$(rpm -ql php5 | grep -E 'php\.ini' | xargs dirname)
        PHP_FPM_DIRECTORY=$(rpm -ql php5-fpm | grep -E 'php-fpm\.conf' | xargs dirname)
        ;;
    "apt-get")
        echo "coming soon"
        ;;
esac    # --- end of case ---
echo "Create directory …"
mkdir -p /usr/local/etc/php
echo "/usr/local/etc/php"
echo "Create and edit conf file …"
echo "/usr/local/etc/php/localhost.conf"
cp "$APPLICATION_DIRECTORY/linux/configs/php/localhost.conf" /usr/local/etc/php
touch $VHOST_DIRECTORY/www/vhosts/localhost/.log/fpm-php.log
sed -ie "s@^slowlog@slowlog = ${VHOST_DIRECTORY/#\//\/}\/www\/vhosts\/localhost\/.log\/php-fpmslow.log@" /usr/local/etc/php/localhost.conf
sed -ie "s@^chdir@chdir = ${VHOST_DIRECTORY/#\//\/}\/www\/vhosts\/localhost@" /usr/local/etc/php/localhost.conf
echo "php_admin_flag[display_errors] = off" >> /usr/local/etc/php/localhost.conf
echo ";php_admin_value[error_log] = $VHOST_DIRECTORY/www/vhosts/localhost/.log/fpm-php.log" >> /usr/local/etc/php/localhost.conf
echo "php_admin_flag[log_errors] = off" >> /usr/local/etc/php/localhost.conf
echo "php_admin_value[open_basedir] = $VHOST_DIRECTORY/www/vhosts/localhost" >> /usr/local/etc/php/localhost.conf
echo "php_admin_value[upload_tmp_dir] =  $VHOST_DIRECTORY/www/vhosts/localhost/.tmp" >> /usr/local/etc/php/localhost.conf
echo "php_admin_value[session.save_path] =  $VHOST_DIRECTORY/www/vhosts/localhost/.session" >> /usr/local/etc/php/localhost.conf
echo "php_admin_value[session.save_handler] =  files" >> /usr/local/etc/php/localhost.conf
cp "$APPLICATION_DIRECTORY/linux/configs/php/php.ini" "$PHP_INI_DIRECTORY"
cp "$APPLICATION_DIRECTORY/linux/configs/php/php-fpm.conf" "$PHP_FPM_DIRECTORY"
echo "done"
