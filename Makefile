#
#
#
# Bootstrap Makefile


VPATH=.
PROGNAME=chilimoon
MAKE=make
PREFIX=/usr
CONFIG=/etc
CONFIGDIR=${CONFIG}/chilimoon
STARTSCRIPTS=${CONFIG}/init.d
INSTALL_DIR=`which install` -c
INSTALL_DATA = `which cp`
INSTALL_DATA_R = `which cp` -r

PIKE_SRC_DIRS="../pike"

OS=`uname -srm|sed -e 's/ /-/g'|tr '[A-Z]' '[a-z]'|tr '/' '_'`

all:
	@echo "###############################################"
	@echo "###                                         ###"
	@echo "### Type make install to install ChiliMoon. ###"
	@echo "###                                         ###"
	@echo "### To make Java Servlets, type make java.  ###"
	@echo "###                                         ###"
	@echo "###############################################"

install : pike_version_test install_dirs install_data config_test 

	
pike_version_test:
	@CONTINUE=0;\
	if [ `which pike` ] ; then\
	echo TESTING PIKE VERSION;\
	echo Current Pike Version is `pike --dumpversion`;\
	PIKE_VERSION=`pike --dumpversion`;\
	IFS=.; set $${PIKE_VERSION}; IFS=' ';\
	if [ "$$2" == "7" ] ; then\
	echo Pike version Checked out OK;\
	else\
	echo Found Older Version of Pike;\
	echo Do you want to continue using old Version?;\
	while [[ "$${CONTINUE}" != "Y" && "$${CONTINUE}" != "N" ]] ; do\
        read CONTINUE;\
	done;\
	if [ "$${CONTINUE}" == "Y" ] ; then\
	: ;\
	else\
	make build_pike;\
	fi\
	fi\
	else\
	echo Pike not found.;\
	make build_pike;\
	fi

install_dirs:
	${INSTALL_DIR} -dD ${PREFIX}/${PROGNAME};
	${INSTALL_DIR} -dD ${PREFIX}/${PROGNAME}/server;
	${INSTALL_DIR} -dD ${PREFIX}/${PROGNAME}/local;

install_data:
	${INSTALL_DATA_R} server 	${PREFIX}/${PROGNAME}/;
	${INSTALL_DATA_R} local 	${PREFIX}/${PROGNAME}/;
	#${INSTALL_DATA}   GPL   	${PREFIX}/${PROGNAME}/;
	#${INSTALL_DATA}   COPYING   	${PREFIX}/${PROGNAME}/;
	${INSTALL_DATA}   start  	${PREFIX}/${PROGNAME}/;
	${INSTALL_DATA}   server/tools/init.d_chilimoon ${STARTSCRIPTS}/chilimoon

config_test: 
	@if [ -f /etc/chilimoon/_admininterface/settings/admin_uid ] ; then\
	: ;\
	else\
	make config;\
	fi
	
config:
	@cd ${PREFIX}/${PROGNAME}/server/mysql;\
	./lnmysql.sh >/dev/null 2>/dev/null;
	@pike ${PREFIX}/${PROGNAME}/server/bin/create_configif.pike -d ${CONFIGDIR} 

build_pike:
	BUILD=0;\
	for i in ${PIKE_SRC_DIRS} ; do\
	cd $${i} && make && make install && BUILD=OK;\
	done;\
	if [ "$${BUILD}" != "OK" ] ; then\
	echo BUILDING Failed, Try building Pike Manually.;\
	exit 1;\
	fi	

.phony: install
