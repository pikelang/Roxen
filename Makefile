#
# $Id: Makefile,v 1.24 1998/03/01 01:56:31 mast Exp $
#
# Bootstrap Makefile
#

VPATH=.
MAKE=make
prefix=/usr/local
OS=`uname -srm|sed -e 's/ /-/g'|tr '[A-Z]' '[a-z]'|tr '/' '_'`
BUILDDIR=build/$(OS)

easy : blurb all

hard : configure
	@grep Bootstrap Makefile >/dev/null 2>&1 && mv Makefile Makefile.boot
	./configure --prefix=$(prefix)
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
	@builddir="$(BUILDDIR)"; \
	srcdir=`pwd`; \
	echo "Attempting to build Roxen 1.2 in $$builddir ..."; \
	echo; \
	./mkdir -p "$$builddir"; \
	cd "$$builddir" && \
	(test -f stamp-h || CONFIG_SITE=x $$srcdir/configure --prefix=$(prefix)) && \
	$(MAKE) "prefix=$(prefix)"
	@echo
	@echo Roxen successfully compiled.
	@echo

configure : configure.in
	@echo Rebuilding the configure-scripts...
	@echo
	@pike/0.6/src/run_autoconfig 2>&1 | grep -v warning
	@echo

install : all
	@make "MAKE=$(MAKE)" "prefix=$(prefix)" "OS=$(OS)" "BUILDDIR=$(BUILDDIR)" install_low
	@echo
	@echo Starting the install program...
	@echo
	@cd $(prefix)/roxen/server; ./install

install_low :
	@builddir="$(BUILDDIR)"; \
	srcdir=`pwd`; \
	echo "Installing Roxen 1.2 from $$builddir ..."; \
	echo; \
	cd "$$builddir" && \
	$(MAKE) install "prefix=$(prefix)"
	@echo
	@echo Roxen successfully installed.
	@echo

localinstall : all
	@builddir="$(BUILDDIR)"; \
	srcdir=`pwd`; \
	echo "Installing Roxen 1.2 from $$builddir ..."; \
	echo; \
	cd "$$builddir" && \
	$(MAKE) localinstall; \
	builddir=`pwd`; \
	$$srcdir/mkdir -p $$srcdir/server/lib; \
	rm -f $$srcdir/server/lib/pike; \
	ln -s "$$builddir"/pike/0.6/src/lib $$srcdir/server/lib/pike;
	@echo
	@echo Roxen successfully installed.
	@echo

install_all :
	@builddir="$(BUILDDIR)"; \
	srcdir=`pwd`; \
	echo "Installing Roxen 1.2 and Pike 0.5 from $$builddir ..."; \
	echo; \
	cd "$$builddir" && \
	$(MAKE) install_all "prefix=$(prefix)"
	@echo
	@echo Roxen and Pike successfully installed.
	@echo
	@echo Starting the install program...
	@echo
	@cd $(prefix)/roxen/server; ./install

install_pike :
	@builddir="$(BUILDDIR)"; \
	srcdir=`pwd`; \
	echo "Installing Pike 0.5 from $$builddir ..."; \
	echo; \
	cd "$$builddir" && \
	$(MAKE) install_pike "prefix=$(prefix)"
	@echo
	@echo Pike successfully installed.
	@echo

verify:
	@builddir="$(BUILDDIR)"; \
	srcdir=`pwd`; \
	echo "Verifying Roxen 1.2 in $$builddir ..."; \
	echo; \
	cd "$$builddir" && \
	$(MAKE) verify "prefix=$(prefix)"
	@echo
	@echo Verify OK.
	@echo

verbose_verify:
	@builddir="$(BUILDDIR)"; \
	srcdir=`pwd`; \
	echo "Verifying Roxen 1.2 in $$builddir ..."; \
	echo; \
	cd "$$builddir" && \
	$(MAKE) verbose_verify "prefix=$(prefix)"
	@echo
	@echo Verify OK.
	@echo

check : verify

dist_clean :
	@echo "Clearing the build-tree..."
	-@rm -rf build || true

censor : censor_crypto censor_dbapi dist_clean
	@echo "Censoring complete."

censor_crypto :
	@for d in pike/*/src/modules/_Crypto/. pike/src/modules/_Crypto/.; do \
	  if test -d $$d ; then \
	    echo "Lobotomizing in $$d..."; \
	    (cd $$d; ./.build_lobotomized_crypto); \
	  else : ; fi; \
	done

	@echo "Censoring the Crypto implementation..."
	@for d in pike/*/src/. pike/src/.; do \
	  if test -d $$d ; then \
	    echo "$$d..."; \
	    rm -rf $$d/modules/_Crypto $$d/../lib/modules/Crypto/rsa.pike $$d/../lib/modules/SSL.pmod; \
	  else : ; fi; \
	done
	-@rm -rf server/protocols/ssl3.pike pike/src/modules/Ssleay || true

censor_dbapi :
	@echo "Censoring the DBAPI..."
	@for d in pike/*/src/. pike/src/.; do \
	  if test -d $$d ; then \
	    rm -rf $$d/modules/Oracle $$d/modules/Odbc; \
	  else : ; fi; \
	done
