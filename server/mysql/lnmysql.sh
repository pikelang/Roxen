#! /bin/sh

MYSQLD_BIN=
MYSQL_SHARE=

DEFAULT_LOCATIONS=(/usr /usr/local)

# Check for a possible mysql installation
check_installation () {
    echo -n Checking for  installation in $1.
    if [ -d $1/share/mysql ]; then
	echo -n .
	if [ -f $1/sbin/mysqld ]; then
	    echo ". found!"
	    MYSQLD_BIN=$1/sbin/mysqld
	    MYSQL_SHARE=$1/share/mysql
	    true
	elif [ -f $1/libexec/mysqld ]; then
	    echo ". found!"
	    MYSQLD_BIN=$1/libexec/mysqld
	    MYSQL_SHARE=$1/share/mysql
	    true
	else
	    echo " -Binary found!"
	    false
	fi
    else
	echo " Directory $1/share/mysql not found!"
	false
    fi
}

# Install links to the MySQL installation
install_links() {
	echo Setting up mysql installation for Chilimoon.
	ln -s `dirname $MYSQLD_BIN` sbin ;
	mkdir -p share ;
	ln -s $MYSQL_SHARE share ;
	echo
	echo All done.
}

# First check that we don't have links already!
if [ -d share/mysql ]; then
    echo You already have a share/mysql directory!
    echo Please remove this before attempting to reinstall links
    echo to your mysql installation!
    exit 2
fi

if [ -d sbin ]; then
    echo You already have a sbin directory!
    echo Please remove this before attempting to reinstall links
    echo to your mysql installation!
    exit 3
fi

echo Looking for MySQL installation in standard directories:
for DIR in $DEFAULT_LOCATIONS; do
    if check_installation $DIR; then
	install_links
	exit 0
    fi
done

echo
echo Attempting to locate installation in non-standard directory.
MYSQL_BIN=`which mysql 2>/dev/null`
if [ "x$MYSQL_BIN" != "x" ]; then
    MYSQL_BIN_DIR=`dirname $MYSQL_BIN`
    MYSQL_ROOT=`dirname $MYSQL_BIN_DIR`
    echo Possible installation found in $MYSQL_ROOT.
    echo
    if check_installation $MYSQL_ROOT; then
	install_links
	exit 0
    fi
fi

echo Failed to find mysql installation!
exit 1
