#
# Main Makefile for extracting autodoc.
#
# $Id: Makefile,v 1.3 2002/10/30 04:04:42 nilsson Exp $
#

PIKE=pike
REFDOC=/home/nilsson/Pike/7.3/refdoc
# FIXME: The REFDOC variable should be generated.

all: modref

# These are the actual build targets for making manuals...

modref: build/modref.xml $(REFDOC)/structure/modref.css \
	  $(REFDOC)/structure/modref.html \
	  $(REFDOC)/presentation/make_html.pike \
	  $(REFDOC)/presentation/tree-split-autodoc.pike
	@$(MAKE) PIKE="$(PIKE)" low_modref

low_modref:
	rm -rf modref || /bin/true
	@mkdir modref
	@cp $(REFDOC)/structure/modref.css modref/style.css
	@$(PIKE) $(REFDOC)/presentation/tree-split-autodoc.pike \
	  build/modref.xml $(REFDOC)/structure/modref.html modref
	@mkdir modref/images
	cp build/images/* modref/images
	@for file in pike_logo.gif next.gif prev.gif unit.gif \
          pike_line_left.gif pike_line_middle.gif pike_line_right.gif ; do \
	  cp $(REFDOC)/src_images/$$file modref/images/ ; done

traditional: traditional_manual build/traditional.xml \
	  $(REFDOC)/presentation/make_html.pike
	@$(MAKE) PIKE="$(PIKE)" low_traditional

low_traditional:
	cp build/images/* traditional_manual/images/
	@$(PIKE) $(REFDOC)/presentation/make_html.pike \
	  --img=images/ build/traditional.xml

# Sub targets used by the above targets.

build/autodoc.xml: build/core/sub_manual.xml build/mod/sub_manual.xml \
	  $(REFDOC)/bin/join.pike
	$(PIKE) $(REFDOC)/bin/join.pike --post-process build/autodoc.xml \
	  build/core/sub_manual.xml build/mod/sub_manual.xml

build/core/sub_manual.xml: build/core build/images always
	$(PIKE) $(REFDOC)/bin/extract.pike ../../server_core/ build/core/ build/images/
	$(PIKE) $(REFDOC)/bin/join.pike build/core/sub_manual.xml build/core/

build/mod/sub_manual.xml: build/mod build/images always
	$(PIKE) $(REFDOC)/bin/extract.pike ../../pike_modules/ build/mod/ build/images/
	$(PIKE) $(REFDOC)/bin/join.pike build/mod/sub_manual.xml build/mod/

always:

build/traditional.xml: build/autodoc.xml $(REFDOC)/structure/traditional.xml \
	  $(REFDOC)/bin/assembler.pike
	@$(PIKE) $(REFDOC)/bin/assembler.pike $(REFDOC)/structure/traditional.xml \
	  build/autodoc.xml > build/traditional.xml

build/modref.xml: build/autodoc.xml $(REFDOC)/structure/modref.xml \
	  $(REFDOC)/bin/assembler.pike
	cp build/autodoc.xml buid/modref.xml
#	@$(PIKE) $(REFDOC)/bin/assembler.pike $(REFDOC)/structure/modref.xml \
#	  build/autodoc.xml > build/modref.xml

# Directories

build/core: build
	@test -d build/core || mkdir build/core

build/mod: build
	@test -d build/mod || mkdir build/mod

build/images: build
	@test -d build/images || mkdir build/images
	@echo ".." > build/images/void

build:
	@test -d build || mkdir build

traditional_manual:
	@test -d traditional_manual || mkdir traditional_manual
	@test -d traditional_manual/images || mkdir traditional_manual/images

# Cleanup

clean:
	@rm -rf build || /bin/true

spotless: clean
	-test -f .cvsignore && rm -rf `cat .cvsignore`
