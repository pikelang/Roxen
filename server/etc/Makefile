#
# Main makefile for extracting autodoc.
#
# $Id: Makefile,v 1.1 2001/08/20 16:25:37 nilsson Exp $
#

PIKE=/export/d1/nilsson/pike/7.3.11/bin/pike
PIKEROOT=/home/nilsson/Pike/_7.3/

all: tree-split _html

tree-split: join _tree-split

_tree-split:
	rm -rf manual-tree-split || /bin/true
	@$(PIKE) $(PIKEROOT)autodoc/presentation/tree-split-autodoc.pike \
	  manual.xml $(PIKEROOT)autodoc/tree-split-template.html manual-tree-split
	@cp $(PIKEROOT)autodoc/tree-split-style.css manual-tree-split/style.css
	@test -d manual-tree-split/images || mkdir manual-tree-split/images
#	cp manual/images/* manual-tree-split/images
	@cp $(PIKEROOT)autodoc/src_images/next.gif $(PIKEROOT)autodoc/src_images/prev.gif \
	  manual-tree-split/images

_html: html_manual
#	cp manual/images/* html_manual/images/
	@$(PIKE) $(PIKEROOT)autodoc/presentation/make_html.pike --img=images/ \
	  manual.xml > html_manual/manual.html
#	@(cd manual && $(MAKE) PIKE="$(PIKE)" html)

extract: build/Makefile
	@(cd build && $(MAKE) PIKE="$(PIKE)" extract)

join: recursive_join
	@$(MAKE) PIKE="$(PIKE)" XMLFILES="`echo build/*.xml`" manual.xml

recursive_join: extract
	@(cd build && $(MAKE) PIKE="$(PIKE)" join)

manual.xml: $(XMLFILES) $(PIKEROOT)bin/join-autodoc.pike
	@$(PIKE) $(PIKEROOT)bin/join-autodoc.pike --post-process manual.xml $(XMLFILES)

build/Makefile: Makefile.in build
	@sed -e "s#@SRCDIR@#../modules#" \
	     -e "s#@PIKEROOT@#$(PIKEROOT)#" \
	     -e "s#@ROOT@#../#" \
	     -e "s#@BUILDROOT@#.#" \
	  <Makefile.in >build/Makefile

build:
	@test -d build || mkdir build

html_manual:
	@test -d html_manual || mkdir html_manual
#	@test -d html_manual/images || mkdir html_manual/images

clean:
	@rm -rf build || /bin/true