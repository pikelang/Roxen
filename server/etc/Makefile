#
# Main makefile for extracting autodoc.
#
# $Id$
#

PIKE=pike
REFDOC=`$(PIKE) -x module --query system_doc_path`/src

# Recursive make to avoid evaluating REFDOC above so many times.
all:
	$(MAKE) $(MAKE_FLAGS) PIKE="$(PIKE)" REFDOC="$(REFDOC)" modref

modref: build/modref.xml
	rm -rf modref || /bin/true
	@mkdir modref
	@cp $(REFDOC)/structure/modref.css modref/style.css
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

build/manual.xml: build/autodoc.xml
	@$(PIKE) -x assemble_autodoc $(REFDOC)/structure/onepage.xml \
	  build/autodoc.xml >build/manual.xml

build/traditional.xml: build/autodoc.xml
	@$(PIKE) -x assemble_autodoc $(REFDOC)/structure/traditional.xml \
	  build/autodoc.xml >build/traditional.xml

build/modref.xml: build/autodoc.xml modref.xml
	@$(PIKE) -x assemble_autodoc modref.xml build/autodoc.xml \
	  >build/modref.xml

build/autodoc.xml: build/etc build/base build/protocols force
	$(PIKE) -x extract_autodoc -q --srcdir=modules --builddir=build/etc
	$(PIKE) -x extract_autodoc -q --srcdir=../base_server \
	  --builddir=build/base
	$(PIKE) -x extract_autodoc -q --srcdir=../protocols \
	  --builddir=build/protocols
	pike_autodoc="$(REFDOC)/core_autodoc.xml"; \
	  if [ -f "$$pike_autodoc" ]; then \
	    echo "Joining with $$pike_autodoc."; \
	  else \
	    echo "$$pike_autodoc not found."; \
	    pike_autodoc=""; \
	  fi; \
	  $(PIKE) -x join_autodoc --quiet --post-process build/autodoc.xml \
	    $$pike_autodoc build/etc build/base build/protocols

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

force:

clean:
	@rm -rf build || /bin/true
