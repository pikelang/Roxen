#! /bin/sh

MYSQLD_BIN=
PIKE_BIN=

DEFAULT_LOCATIONS=(/usr /usr/local)

# Check for a possible mysql installation
check_installation () {
    echo -n "Checking for  installation in $1. "
	if [ -f $1/sbin/mysqld ]; then
	    echo -n "Mysql. found! "
	    MYSQLD_BIN=$1/sbin/mysqld
	    true
	elif [ -f $1/libexec/mysqld ]; then
	    echo -n "Mysql. found! "
	    MYSQLD_BIN=$1/libexec/mysqld
	    true
	else
	    echo -n " -Mysqld binary not found!"
	    false
	fi

        if [ -f $1/bin/pike ]; then
            echo -n "Pike. found! "
            PIKE_BIN=$1/bin/pike
            true
        elif [ -f $1/libexec/pike ]; then
            echo -n "Pike. found! "
            PIKE_BIN=$1/libexec/pike
            true
        else
            echo -n " -Pike binary not found!"
            false
        fi
echo "."
}


echo Looking for mysqld and pike binary in standard directories:
for DIR in $DEFAULT_LOCATIONS; do
    if check_installation $DIR; then
    :
    else
      echo Attempting to locate installation in non-standard directory.
      MYSQL_BIN=`which mysqld 2>/dev/null`
      PIKE_BIN=`which pike 2>/dev/null`
    fi
done;

if [ "x$MYSQLD_BIN" != "x" ]; then
echo "Mysqld binary found in `dirname $MYSQLD_BIN`."
echo "Mysqld version is: `$MYSQLD_BIN --version` ";

fi
if [ "x$PIKE_BIN" != "x" ]; then
echo "Pike binary found in `dirname $PIKE_BIN`."
echo "Pike version is: `$PIKE_BIN --dumpversion` ";
fi

