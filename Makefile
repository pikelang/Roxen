#
# $Id: Makefile,v 1.44 1998/09/26 14:15:12 mast Exp $
#
# Bootstrap Makefile
#

VPATH=.
MAKE=make
prefix=/usr/local
OS=`uname -srm|sed -e 's/ /-/g'|tr '[A-Z]' '[a-z]'|tr '/' '_'`
BUILDDIR=build/$(OS)

easy : blurb all

.noway:

ChangeLog.gz: .noway
	pike tools/make_changelog.pike | gzip -9 > ChangeLog.gz

ChangeLog.rxml.gz: .noway
	pike tools/make_changelog.pike --rxml |gzip -9 > ChangeLog.rxml.gz

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

all : configure_all
	builddir="$(BUILDDIR)"; \
	cd "$$builddir"; \
	$(MAKE) "prefix=$(prefix)"
	@echo
	@echo Roxen successfully compiled.
	@echo

configure : configure.in
	@echo Rebuilding the configure-scripts...
	@echo
	@for d in pike/*/src; do \
	  (cd $$d; \
	  echo Entering $$d; \
	  ./run_autoconfig . 2>&1 | ( grep -v warning || : ) || exit 1; \
	  echo Leaving $$d) \
	done
	@echo Running autoconf in pike; \
	cd pike && autoconf 2>&1 | ( grep -v warning || : )
	@cd extern && ( \
          echo Entering extern; \
	  ../pike/*/src/run_autoconfig . 2>&1 | ( grep -v warning || : ); \
	  echo Leaving extern \
	)
	@echo Running autoconf in .; \
	autoconf 2>&1 | ( grep -v warning || : )
	@echo
	@test -f "$(BUILDDIR)"/stamp-h && rm -f "$(BUILDDIR)"/stamp-h || :

configure_all : configure
	@builddir="$(BUILDDIR)"; \
	srcdir=`pwd`; \
	if test -d pike/0.6/src ; then pikeversion=0.6; \
	else pikeversion=0.5; \
	fi; \
	./mkdir -p "$$builddir"; \
	cd "$$builddir" && \
	test -f stamp-h && (test "`cat stamp-h`" = $$pikeversion) || ( \
	  echo "Configuring Roxen 1.2 in $$builddir ..."; \
	  echo; \
	  CONFIG_SITE=x $$srcdir/configure --prefix=$(prefix) --with-pike=$$pikeversion \
	)

install :
	@make "MAKE=$(MAKE)" "prefix=$(prefix)" "OS=$(OS)" "BUILDDIR=$(BUILDDIR)" install_low
	@echo
	@echo Starting the install program...
	@echo
	@cd $(prefix)/roxen/server; ./install

install_low : configure_all
	@builddir="$(BUILDDIR)"; \
	srcdir=`pwd`; \
	echo "Installing Roxen 1.2 from $$builddir ..."; \
	echo; \
	cd "$$builddir" && \
	$(MAKE) install "prefix=$(prefix)"
	@echo
	@echo Roxen successfully installed.
	@echo

localinstall :
	@make "MAKE=$(MAKE)" "prefix=`pwd`/server" "OS=$(OS)" "BUILDDIR=$(BUILDDIR)" localinstall_low

localinstall_low : configure_all
	@builddir="$(BUILDDIR)"; \
	srcdir=`pwd`; \
	echo "Installing Roxen 1.2 locally from $$builddir ..."; \
	echo; \
	cd "$$builddir" && \
	$(MAKE) localinstall;
	@echo
	@echo Roxen successfully installed locally.
	@echo

install_all : configure_all
	@builddir="$(BUILDDIR)"; \
	srcdir=`pwd`; \
	test -f "$$builddir"/stamp-h && pikeversion=`cat "$$builddir"/stamp-h`; \
	echo "Installing Roxen 1.2 and Pike $$pikeversion from $$builddir ..."; \
	echo; \
	cd "$$builddir" && \
	$(MAKE) install_all "prefix=$(prefix)"
	@echo
	@echo Roxen and Pike successfully installed.
	@echo
	@echo Starting the install program...
	@echo
	@cd $(prefix)/roxen/server; ./install

install_pike : configure_all
	@builddir="$(BUILDDIR)"; \
	srcdir=`pwd`; \
	test -f "$$builddir"/stamp-h && pikeversion=`cat "$$builddir"/stamp-h`; \
	echo "Installing Pike $$pikeversion from $$builddir ..."; \
	echo; \
	cd "$$builddir" && \
	$(MAKE) install_pike "prefix=$(prefix)"
	@echo
	@echo Pike successfully installed.
	@echo

verify: configure_all
	@builddir="$(BUILDDIR)"; \
	srcdir=`pwd`; \
	echo "Verifying Roxen 1.2 in $$builddir ..."; \
	echo; \
	cd "$$builddir" && \
	$(MAKE) verify "prefix=$(prefix)"
	@echo
	@echo Verify OK.
	@echo

verbose_verify: configure_all
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

keep_dbapi:
	@echo "Keeping DBAPI..."
	@dirs=`find pike -type d -print|egrep 'Oracle|Odbc'`; \
	if test "x$dirs" = "x"; then \
	  echo "DBAPI already censored."; \
	  exit 1; \
	else \
	  tar cf dbapi.tar $$dirs; \
	fi

censor : censor_crypto censor_dbapi dist_clean
	@echo "Censoring complete."

censor_crypto :
	@for d in pike/*/src/modules/_Crypto/. pike/src/modules/_Crypto/.; do \
	  if test -d $$d ; then \
	    echo "Lobotomizing in $$d..."; \
	    (cd $$d; ./.build_lobotomized_crypto) || exit 1; \
	  else : ; fi; \
	done

	@echo "Running autoconf..."; \
	(cd pike; 0.6/src/run_autoconfig .)

	@echo "Censoring the Crypto implementation..."
	@for d in pike/*/src/. pike/src/.; do \
	  if test -d $$d ; then \
	    echo "$$d..."; \
	    rm -rf $$d/modules/Ssleay $$d/modules/_Crypto $$d/../lib/modules/Crypto/rsa.pike $$d/../lib/modules/SSL.pmod; \
	  else : ; fi; \
	done
	-@rm -rf server/protocols/ssl3.pike || true

censor_dbapi :
	@echo "Censoring the DBAPI..."
	@for d in pike/*/src/. pike/src/.; do \
	  if test -d $$d ; then \
	    rm -rf $$d/modules/Oracle $$d/modules/Odbc; \
	  else : ; fi; \
	done

dist: ChangeLog.gz ChangeLog.rxml.gz
