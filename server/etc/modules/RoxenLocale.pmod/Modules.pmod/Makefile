LOCALES=svenska.pmod english.pmod nihongo.pmod
PIKE=pike

.SUFFIXES:	.in .pmod

all: $(LOCALES)
	echo "All is well"

.in.pmod:
	$(PIKE) genstring.pike $<
