#
#
#
# Bootstrap Makefile


VPATH=.
PROGNAME=chilimoon
MAKE=make
PREFIX=/usr
PROG_DIR=${PREFIX}/${PROGNAME}
CONFIG=/etc
CONFIGDIR=${CONFIG}/chilimoon
STARTSCRIPTS=${CONFIG}/init.d
INSTALL_DIR=`which install` -c
INSTALL_DATA = `which cp`
INSTALL_DATA_R = `which cp` -r

PIKE_SRC_DIRS="../pike"

OS=`uname -srm|sed -e 's/ /-/g'|tr '[A-Z]' '[a-z]'|tr '/' '_'`

all: pike_version_test


install : all install_dirs install_data mysql make_demo_cert config_test buildenv_test

	
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
	${INSTALL_DIR} -dD ${PROG_DIR};
	${INSTALL_DIR} -dD ${PROG_DIR}/server;
	${INSTALL_DIR} -dD ${PROG_DIR}/server/mysql;
	${INSTALL_DIR} -dD ${PROG_DIR}/server/mysql/share;
	${INSTALL_DIR} -dD ${PROG_DIR}/server/data;
	${INSTALL_DIR} -dD ${PROG_DIR}/local;

install_data:
	${INSTALL_DATA_R} server/admin_interface	${PROG_DIR}/server/;
	${INSTALL_DATA_R} server/bin			${PROG_DIR}/server/;
	${INSTALL_DATA}   server/data/contenttypes	${PROG_DIR}/server/data/;
	${INSTALL_DATA_R} server/data/example_pages	${PROG_DIR}/server/data/;
	${INSTALL_DATA}   server/data/extensions	${PROG_DIR}/server/data/;
	${INSTALL_DATA_R} server/data/fonts 		${PROG_DIR}/server/data/;
	${INSTALL_DATA_R} server/data/images 		${PROG_DIR}/server/data/;
	${INSTALL_DATA_R} server/data/include 		${PROG_DIR}/server/data/;
	${INSTALL_DATA_R} server/data/maps 		${PROG_DIR}/server/data/;
	${INSTALL_DATA_R} server/data/more_extensions	${PROG_DIR}/server/data/;
	${INSTALL_DATA}   server/data/mysql-template.tar ${PROG_DIR}/server/data/;
	${INSTALL_DATA_R} server/data/randomtext	${PROG_DIR}/server/data/;
	${INSTALL_DATA_R} server/data/refdoc		${PROG_DIR}/server/data/;
	${INSTALL_DATA}   server/data/supports		${PROG_DIR}/server/data/;
	${INSTALL_DATA}   server/mysql/lnmysql.sh	${PROG_DIR}/server/mysql;
	${INSTALL_DATA_R} server/java			${PROG_DIR}/server/;
	${INSTALL_DATA_R} server/modules		${PROG_DIR}/server/;
	${INSTALL_DATA_R} server/perl			${PROG_DIR}/server/;
	${INSTALL_DATA_R} server/plugins		${PROG_DIR}/server/;
	${INSTALL_DATA_R} server/pike_modules		${PROG_DIR}/server/;
	${INSTALL_DATA_R} server/rxml_packages		${PROG_DIR}/server/;
	${INSTALL_DATA_R} server/server_core		${PROG_DIR}/server/;
	${INSTALL_DATA_R} server/site_templates		${PROG_DIR}/server/;
	${INSTALL_DATA_R} server/translations		${PROG_DIR}/server/;
	${INSTALL_DATA}   server/start			${PROG_DIR}/server/;
	#${INSTALL_DATA_R} local 		${PROG_DIR}/;
	#${INSTALL_DATA}   GPL   	${PROG_DIR}/;
	#${INSTALL_DATA}   COPYING   	${PROG_DIR}/;
	${INSTALL_DATA}   start  	${PROG_DIR}/;
	${INSTALL_DATA}   server/tools/init.d_chilimoon ${STARTSCRIPTS}/chilimoon;

config_test: 
	@if [ -f /etc/chilimoon/_admininterface/settings/admin_uid ] ; then\
	: ;\
	else\
	make config;\
	fi
	
config:
	@pike ${PROG_DIR}//server/bin/create_configif.pike -d ${CONFIGDIR} 

build_pike:
	BUILD=0;\
	for i in ${PIKE_SRC_DIRS} ; do\
	cd $${i} && make && make install && BUILD=OK;\
	done;\
	if [ "$${BUILD}" != "OK" ] ; then\
	echo BUILDING Failed, Try building Pike Manually.;\
	exit 1;\
	fi	

selftest:
	cd server/mysql;\
	./lnmysql.sh;
	./start --self-test-verbose;

mysql:
	
	cd ${PROG_DIR}/server/mysql;\
	if [ ./lnmysql.sh; ] ; then\
	: ;\
	fi

make_demo_cert:
	if [ -f ${PROG_DIR}/local/demo_certificate.pem ] ; then\
	: ;\
	else\
	cd ${PROG_DIR}/local;\
	pike ../server/bin/create_testcert.pike;\
	fi

buildenv_test:
	@if [ -f ${PROG_DIR}/local/environment ] ; then\
	:;\
	else\
	make buildenv;\
	fi

buildenv:
	cd ${PROG_DIR}/server;\
	pike bin/buildenv.pike;

.phony: install
