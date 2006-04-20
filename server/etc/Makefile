#
# Main makefile for extracting autodoc.
#
# $Id: Makefile,v 1.5 2006/04/20 13:26:07 grubba Exp $
#

PIKE=pike
REFDOC=/home/grubba/src/Pike/7.7/refdoc

# FIXME: The REFDOC variable should be generated.

all: modref

modref: build/modref.xml
	rm -rf modref || /bin/true
	@mkdir modref
	@cp $(REFDOC)/modref/style.css modref/style.css
	@$(PIKE) $(REFDOC)/presentation/tree-split-autodoc.pike \
	  build/modref.xml $(REFDOC)/structure/module_modref.html modref roxen
	@mkdir modref/images
#	cp build/images/* modref/images
	@cp $(REFDOC)/src_images/next.gif $(REFDOC)/src_images/prev.gif modref/images

html: html_manual build/manual.xml
#	cp build/images/* html_manual/images/
	@$(PIKE) $(REFDOC)/presentation/make_html.pike --img=images/ build/manual.xml

traditional: traditional_manual build/traditional.xml
#	cp build/images/* traditional_manual/images/
	@$(PIKE) @(REFDOC)/presentation/make_html.pike --img=images/ build/traditional.xml

# build/autodoc.xml: recursive_join
# 	@$(MAKE) PIKE="$(PIKE)" XMLFILES="`echo build/*/*.xml`" \
# 	  autodoc.xml

recursive_join: extract
	@(cd build/etc && $(MAKE) PIKE="$(PIKE)" join)
	@(cd build/base && $(MAKE) PIKE="$(PIKE)" join)

extract: build/etc/Makefile build/base/Makefile
	@(cd build/etc && $(MAKE) PIKE="$(PIKE)" extract)
	@(cd build/base && $(MAKE) PIKE="$(PIKE)" extract)

build/manual.xml: build/autodoc.xml $(REFDOC)/structure/onepage.xml
	@$(PIKE) -x assemble_autodoc $(REFDOC)/structure/onepage.xml build/autodoc.xml > build/manual.xml

build/traditional.xml: build/autodoc.xml $(REFDOC)/structure/traditional.xml
	@$(PIKE) -x assemble_autodoc $(REFDOC)/structure/traditional.xml build/autodoc.xml > build/traditional.xml

build/modref.xml: build/autodoc.xml modref.xml
	@$(PIKE) -x assemble_autodoc modref.xml build/autodoc.xml > build/modref.xml

build/autodoc.xml: $(XMLFILES) build/etc build/base build/protocols
	@$(PIKE) -x extract_autodoc -q --srcdir=modules \
	  --builddir=build/etc
	@$(PIKE) -x extract_autodoc -q --srcdir=../base_server \
	  --builddir=build/base
	@$(PIKE) -x extract_autodoc -q --srcdir=../protocols \
	  --builddir=build/protocols
	@$(PIKE) -x join_autodoc --quiet --post-process build/autodoc.xml \
	  build/etc build/base build/protocols

# Directories

build/etc: build
	@test -d build/etc || mkdir build/etc

build/base: build
	@test -d build/base || mkdir build/base

build/protocols: build
	@test -d build/protocols || mkdir build/protocols

build:
	@test -d build || mkdir build

html_manual:
	@test -d html_manual || mkdir html_manual
#	@test -d html_manual/images || mkdir html_manual/images

traditional_manual:
	@test -d traditional_manual || mkdir traditional_manual

clean:
	@rm -rf build || /bin/true
