#! /bin/sh

# Debian
if [ -f /usr/sbin/mysqld ] ; then
  if [ -d /usr/share/mysql ] ; then
    ln -s /usr/sbin . ;
    mkdir share ;
    ln -s /usr/share/mysql share/mysql ;
    echo Ok.
    exit 0
  fi
fi

# Red Hat
if [ -f /usr/libexec/mysqld ] ; then
  if [ -d /usr/share/mysql ] ; then
    ln -s /usr/libexec . ;
    mkdir share;
    ln -s /usr/share/mysql share/mysql ;
    echo Ok.
    exit 0
  fi
fi

# Solaris?
if [ -f /usr/local/libexec/mysqld ] ; then
  if [ -d /usr/local/share/mysql ] ; then
    ln -s /usr/local/libexec . ;
    mkdir share;
    ln -s /usr/local/share/mysql share/mysql ;
    echo Ok.
    exit 0
  fi
fi

echo Failed.
exit 1
