#
# Makefile for updating translations for locally installed modules.
#
# $Id: Makefile,v 1.1 2005/03/22 19:18:54 grubba Exp $
#
# 2005-03-22 Henrik Grubbström
#

# Pike interpreter to use for extraction
PIKE=../../start --silent-start --program

# Leave empty to update all projects in the configs directory.
CONFIGFILE=

all:
	@case "$(CONFIGFILE)" in					\
	  "")								\
	    find "configs/" -name '*.xml' -print |			\
	      while read config; do					\
	        echo "Updating project $$config...";			\
	        $(PIKE) -x extract_locale				\
		  --config="`pwd`/$$config" --wipe --sync || exit $$?;	\
	      done;							\
	  ;;								\
	  /*)								\
	    echo "Updating project $(CONFIGFILE)...";			\
	    exec $(PIKE) -x extract_locale				\
	      --config="$(CONFIGFILE)" --wipe --sync;			\
	  ;;								\
	  *)								\
	    echo "Updating project $(CONFIGFILE)...";			\
	    exec $(PIKE) -x extract_locale				\
	      --config="`pwd`/$(CONFIGFILE)" --wipe --sync;		\
	  ;;								\
	esac
