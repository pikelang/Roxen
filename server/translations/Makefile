# configurable stuff
PIKE=../bin/roxen

LANG=C

# do not alter
all: translations

modules:
	@echo "1. Finding modules"
	@for a in `find ../modules/ -name '*.pike'` ; do \
	  if grep -c '#!NO' $$a >/dev/null 2>&1; then \
	   :;\
	  else  \
	    module='"mod_'`echo $$a|sed -e s',../modules/.*/,,' -e s',.pike,,'`'"';\
	    if grep -c "$$module" $$a >/dev/null 2>&1; then \
	      ./scripts/make_mod_config $$module $$a; \
	    fi;\
	  fi ; \
	done
	@for a in `find ../more_modules/ -name '*.pike'` ; do \
	  if grep -c '#!NO' $$a >/dev/null 2>&1; then \
	   :;\
	  else  \
	    module='"mod_'`echo $$a|sed -e s',../more_modules/,,' -e s',.pike,,'`'"';\
	    if grep -c "$$module" $$a >/dev/null 2>&1; then \
	      ./scripts/make_mod_config $$module $$a; \
	    fi;\
	  fi ; \
        done

xmls: modules
	@echo "2. Rebuilding .xml config files"
	@for a in configs/*.xml ; do  \
		pkg=`echo $$a | sed -e s',\.xml,,' -e s',.*/,,'`; \
		./scripts/make_config $$pkg configs/$$pkg.xml ; \
	done

translations: xmls
	@echo "3. Rebuilding translation files"
	@for a in configs/*.xml ; do  \
		pkg=`echo $$a | sed -e s',\.xml,,' -e s',.*/,,'`; \
		$(PIKE) -x extract_locale --config=configs/$$pkg.xml --wipe --sync --notime; \
	done


clean:
	rm configs/*~
	rm configs/mod_*.xml
