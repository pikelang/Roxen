#
# $Id: Makefile,v 1.1 1997/08/18 01:22:40 grubba Exp $
#
# Bootstrap Makefile
#

VPATH=.
MAKE=make

easy : blurb all

hard :
	./configure
	@echo
	@echo 'Please run make again.'
	@exit 1

blurb :
	@echo '	 Roxen 1.2 -- Easy Configuration '
	@echo '	---------------------------------'
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

all :
	@os=`uname -srm|sed -e 's/ /-/g'|tr '[A-Z]' '[a-z]'`; \
	srcdir=`pwd`; \
	echo Attempting to build Roxen 1.2 in build/$$os...; \
	echo; \
	./mkdir -p build/$$os; \
	cd build/$$os && \
	(test -f Makefile || CONFIG_SITE=x $$srcdir/configure) && \
	$(MAKE);

install : all
	@os=`uname -srm|sed -e 's/ /-/g'|tr '[A-Z]' '[a-z]'`; \
	srcdir=`pwd`; \
	echo Installing Roxen 1.2 from build/$$os...; \
	echo; \
	cd build/$$os && \
	$(MAKE) install;

install_all : install_pike install

install_pike : all
	@os=`uname -srm|sed -e 's/ /-/g'|tr '[A-Z]' '[a-z]'`; \
	srcdir=`pwd`; \
	echo Installing Pike 0.5 from build/$$os...; \
	echo; \
	cd build/$$os && \
	$(MAKE) install_pike;

verify: all
	@os=`uname -srm|sed -e 's/ /-/g'|tr '[A-Z]' '[a-z]'`; \
	srcdir=`pwd`; \
	echo Verifying Roxen 1.2 in build/$$os...; \
	echo; \
	cd build/$$os && \
	$(MAKE) verify;

verbose_verify: all
	@os=`uname -srm|sed -e 's/ /-/g'|tr '[A-Z]' '[a-z]'`; \
	srcdir=`pwd`; \
	echo Verifying Roxen 1.2 in build/$$os...; \
	echo; \
	cd build/$$os && \
	$(MAKE) verbose_verify;

check : verify

