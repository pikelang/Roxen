#
# $Id: Makefile,v 1.8 1997/09/14 13:58:20 grubba Exp $
#
# Bootstrap Makefile
#

VPATH=.
MAKE=make
prefix=/usr/local

easy : blurb all

hard : configure
	@grep Bootstrap Makefile >/dev/null 2>&1 && mv Makefile Makefile.boot
	./configure
	@echo
	@echo 'Please run make again.'
	@exit 1

blurb :
	@echo '	 Roxen 1.2 -- Easy Build '
	@echo '	-------------------------'
	@echo
	@echo 'This will attempt to build Roxen 1.2 in a directory'
	@echo 'specific for this architecture. This allows for building'
	@echo 'Roxen 1.2 for several operating systems at the same time.'
	@echo 'Unfortunately this requires a make which understands VPATH.'
	@echo 'If make reports strange errors about missing files, your'
	@echo 'make probably does not understand VPATH. If this is the'
	@echo 'case try running:'
	@echo '	make hard; make'
	@echo
	@echo
	@sleep 10

all : configure
	@os=`uname -srm|sed -e 's/ /-/g'|tr '[A-Z]' '[a-z]'|tr '/' '_'`; \
	srcdir=`pwd`; \
	echo Attempting to build Roxen 1.2 in build/$$os...; \
	echo; \
	./mkdir -p build/$$os; \
	cd build/$$os && \
	(test -f stamp-h || CONFIG_SITE=x $$srcdir/configure --prefix=$(prefix)) && \
	$(MAKE);

configure : configure.in
	@echo Rebuilding the configure-scripts...
	@echo
	@pike/src/run_autoconfig 2>&1 | grep -v warning
	@echo

install : all
	@os=`uname -srm|sed -e 's/ /-/g'|tr '[A-Z/]' '[a-z_]'`; \
	srcdir=`pwd`; \
	echo Installing Roxen 1.2 from build/$$os...; \
	echo; \
	cd build/$$os && \
	$(MAKE) install;

install_all :
	@os=`uname -srm|sed -e 's/ /-/g'|tr '[A-Z/]' '[a-z_]'`; \
	srcdir=`pwd`; \
	echo Installing Roxen 1.2 and Pike 0.5 from build/$$os...; \
	echo; \
	cd build/$$os && \
	$(MAKE) install_all;

install_pike :
	@os=`uname -srm|sed -e 's/ /-/g'|tr '[A-Z/]' '[a-z_]'`; \
	srcdir=`pwd`; \
	echo Installing Pike 0.5 from build/$$os...; \
	echo; \
	cd build/$$os && \
	$(MAKE) install_pike;

verify:
	@os=`uname -srm|sed -e 's/ /-/g'|tr '[A-Z/]' '[a-z_]'`; \
	srcdir=`pwd`; \
	echo Verifying Roxen 1.2 in build/$$os...; \
	echo; \
	cd build/$$os && \
	$(MAKE) verify;

verbose_verify:
	@os=`uname -srm|sed -e 's/ /-/g'|tr '[A-Z/]' '[a-z_]'`; \
	srcdir=`pwd`; \
	echo Verifying Roxen 1.2 in build/$$os...; \
	echo; \
	cd build/$$os && \
	$(MAKE) verbose_verify;

check : verify


