#
# Main makefile for extracting autodoc.
#
# $Id: Makefile,v 1.4 2004/05/18 16:37:57 grubba Exp $
#

PIKE=pike
REFDOC=/home/nilsson/Pike/7.3/refdoc

# FIXME: The REFDOC variable should be generated.

all: modref

modref: build/modref.xml
	rm -rf modref || /bin/true
	@mkdir modref
	@cp $(REFDOC)/tree-split-style.css modref/style.css
	@$(PIKE) $(REFDOC)/presentation/tree-split-autodoc.pike \
	  build/modref.xml $(REFDOC)/tree-split-template.html modref
	@mkdir modref/images
#	cp build/images/* modref/images
	@cp $(REFDOC)/src_images/next.gif $(REFDOC)/src_images/prev.gif modref/images

html: html_manual
#	cp build/images/* html_manual/images/
	@$(PIKE) $(REFDOC)/presentation/make_html.pike --img=images/ build/manual.xml

traditional: traditional_manual build/traditional.xml
#	cp build/images/* traditional_manual/images/
	@$(PIKE) @(REFDOC)/presentation/make_html.pike --img=images/ build/traditional.xml

build/autodoc.xml: recursive_join
	@$(MAKE) PIKE="$(PIKE)" XMLFILES="`echo build/*/*.xml`" \
	  autodoc.xml

recursive_join: extract
	@(cd build/etc && $(MAKE) PIKE="$(PIKE)" join)
	@(cd build/base && $(MAKE) PIKE="$(PIKE)" join)

extract: build/etc/Makefile build/base/Makefile
	@(cd build/etc && $(MAKE) PIKE="$(PIKE)" extract)
	@(cd build/base && $(MAKE) PIKE="$(PIKE)" extract)

manual.xml: build/autodoc.xml $(REFDOC)/structure/onepage.xml $(REFDOC)/bin/assembler.pike
	@$(PIKE) $(REFDOC)/bin/assembler.pike $(REFDOC)/structure/onepage.xml build/autodoc.xml > manual.xml

build/traditional.xml: build/autodoc.xml $(REFDOC)/structure/traditional.xml $(REFDOC)/bin/assembler.pike
	@$(PIKE) $(REFDOC)/bin/assembler.pike $(REFDOC)/structure/traditional.xml build/autodoc.xml > build/traditional.xml

build/modref.xml: build/autodoc.xml modref.xml $(REFDOC)/bin/assembler.pike
	@$(PIKE) $(REFDOC)/bin/assembler.pike modref.xml build/autodoc.xml > build/modref.xml

autodoc.xml: $(XMLFILES) $(REFDOC)/bin/join.pike
	@$(PIKE) $(REFDOC)/bin/join.pike --post-process build/autodoc.xml $(XMLFILES)

# Makefiles

build/etc/Makefile: Makefile.in build/etc
	@sed -e "s#@SRCDIR@#../../modules#" \
	     -e "s#@REFDOC@#$(REFDOC)#" \
	     -e "s#@ROOT@#../../#" \
	     -e "s#@BUILDROOT@#../#" \
	     -e "s#@EXTARGS@##" \
	  <Makefile.in >build/etc/Makefile

build/base/Makefile: Makefile.in build/base
	@sed -e "s#@SRCDIR@#../../../base_server#" \
	     -e "s#@REFDOC@#$(REFDOC)#" \
	     -e "s#@ROOT@#../../#" \
	     -e "s#@BUILDROOT@#../#" \
	     -e "s#@EXTARGS@#--rootless#" \
	  <Makefile.in >build/base/Makefile

# Directories

build/etc: build
	@test -d build/etc || mkdir build/etc

build/base: build
	@test -d build/base || mkdir build/base

build:
	@test -d build || mkdir build

html_manual:
	@test -d html_manual || mkdir html_manual
#	@test -d html_manual/images || mkdir html_manual/images

traditional_manual:
	@test -d traditional_manual || mkdir traditional_manual

clean:
	@rm -rf build || /bin/true