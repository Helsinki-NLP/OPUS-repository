# -*-makefile-*-

INSTALL = install -c
INSTALL_BIN = ${INSTALL} -m 755
INSTALL_DATA = ${INSTALL} -m 644
COPY = cp -r --preserve=mode,timestamps

APACHE_CONF = /etc/apache2

LETSMT_SSL_HOME    = /etc/ssl
LETSMT_SSL_PROJECT = ${LETSMTHOST}
ifeq "${LETSMTHOST}" ""
    LETSMT_SSL_PROJECT = $(HOSTNAME)
endif
LETSMT_SSL_DIR     = ${LETSMT_SSL_HOME}/${LETSMT_SSL_PROJECT}

LETSMT_CERTROOT = /etc/apache2/ssl_certs
LETSMT_CERTPATH = ${LETSMT_SSL_DIR}/newcerts
LETSMT_REVOCATIONPATH=${LETSMT_SSL_DIR}/crl

### the important variables that should be exported
LETSMT_CACERT   = ${LETSMT_SSL_DIR}/ca.crt
LETSMT_USERCERT = ${LETSMT_SSL_DIR}/user/certificates/developers@localhost.crt
LETSMT_USERKEY  = ${LETSMT_SSL_DIR}/user/keys/developers@localhost.key
LETSMT_USERCERTPASS = letsmt

### Java classpath
empty:=
space:= $(empty) $(empty)
CLASSPATH=$(subst $(space),:,$(wildcard $(LETSMTROOT)/lib/*.jar))

ifeq "${HOSTNAME}" ""
    $(error HOSTNAME is undefined! Check your DNS setup.)
endif

## Ask for the sitename if it is not defined
ifndef SITENAME
    SITENAME=$(shell whiptail --title 'SSL server certificate hostname' \
                --inputbox '' \
                8 40 "${HOSTNAME}" 2>&1 1>/dev/tty)
endif


# DB host name is necessary for rr-server (without local DB server)
ifndef DB_HOST
    DB_HOST=$(shell whiptail --title 'Database server name' \
                --inputbox 'Hostname of the server running your Metadata DB' \
                8 40 "${HOSTNAME}" 2>&1 1>/dev/tty)
endif

## The base URL to be called for all web APIs
LETSMT_URL=https://${LETSMTHOST}:${LETSMTPORT}/ws

## cURL commands for connecting to the repository
LETSMT_CONNECT = "curl --silent --show-error --cacert \$$LETSMT_CACERT  --cert \$$LETSMT_USERCERT:\$$LETSMT_USERCERTPASS --key \$$LETSMT_USERKEY"

# (LETSMT_CONNECT_RAW is just an alias for historical reasons)

## fresh install
# (set LETSMTHOST=SITENAME)
#
# RR-server is actually the same as a full server with RR & storage server
.PHONY: install install-rr-server
install install-rr-server:
	$(MAKE) LETSMTHOST=${SITENAME} install-targets
	$(MAKE) update-cron

.PHONY: install-targets
install-targets: \
	install-modules \
	install-files \
	install-config \
	install-svnserver \
	install-swap \
	install-isa \
	restart-apache

# for storage servers: set DB-server-name to access the remote DB host
# (avoid asking twice by setting a new variable DB_SERVER)
.PHONY: install-storage-server
install-storage-server:
	make GROUP_DB_HOST=${DB_HOST} META_DB_HOST=${DB_HOST} install


# install frontend client (without webservice)
# --> ask for the remote hostname to be used for accessing webservices
.PHONY: install-frontend
install-frontend:
	( REMOTE_HOST=$(shell whiptail --title 'Repository server name' \
		--inputbox \
		'Should match the name of the SSL server cert on that server' \
		8 40 ${LETSMTHOST} 2>&1 1>/dev/tty); \
	  make LETSMTHOST=$${REMOTE_HOST} \
		META_DB_HOST=$${REMOTE_HOST} \
		GROUP_DB_HOST=$${REMOTE_HOST} \
		install-frontend-targets; )

.PHONY: install-frontend-targets
install-frontend-targets: \
	install-frontend-files \
	install-modules \
	config-conf \
	config-conf-frontend

.PHONY: install-sge-client install-client
install-client install-sge-client:
	( REMOTE_HOST=$(shell whiptail --title 'Repository server name' \
		--inputbox \
		'Should match the name of the SSL server cert on that server' \
		8 40 ${LETSMTHOST} 2>&1 1>/dev/tty); \
	  make LETSMTHOST=$${REMOTE_HOST} \
		META_DB_HOST=$${REMOTE_HOST} \
		GROUP_DB_HOST=$${REMOTE_HOST} \
		install-sge-client-targets; )


.PHONY: install-sge-client-targets install-client-targets
install-sge-client-targets install-client-targets: \
	install-modules \
	prepare-directories \
	install-log \
	config-conf \
	install-diskroot

#.PHONY: install-sge-client
#install-sge-client: install-frontend
## ???

## copy the files for ISA (interactive sentence aligner)
.PHONY: install-isa
install-isa:
	echo ${HOSTNAME}
	sed -e "s#%%LETSMT_CONNECT%%#curl --silent --show-error --cacert ${LETSMT_CACERT}  --cert ${LETSMT_USERCERT}:${LETSMT_USERCERTPASS} --key ${LETSMT_USERKEY}#" \
	    -e "s#%%LETSMT_URL%%#${LETSMT_URL}#" \
	< ../isa/Makefile.in > ../isa/Makefile
	${COPY} ../isa ${LETSMTROOT}/share/
	mkdir -p /var/www/html/isa
	chgrp www-data /var/www/html/isa
	chmod g+sw /var/www/html/isa


.PHONY: install-ida
install-ida:
	mkdir -p ${LETSMTROOT}/share/ida
	${INSTALL_DATA} ../ida/index.in ${LETSMTROOT}/share/ida/index.in
	${INSTALL_DATA} ../ida/Makefile ${LETSMTROOT}/share/ida/Makefile
	${INSTALL_BIN} ../ida/deprel2db.pl ${LETSMTROOT}/share/ida/deprel2db.pl
	mkdir -p /var/www/html/ida
	chgrp www-data /var/www/html/ida
	chmod g+sw /var/www/html/ida
	${COPY} ../ida/*.php /var/www/html/ida/
	${COPY} ../ida/*.css /var/www/html/ida/
	${COPY} ../ida/ud-deprels.* /var/www/html/ida/
	rm -f /var/www/html/ida/index.php


.PHONY: install-grenzschnitte
install-grenzschnitte:
	$(MAKE) install -C ../www


.PHONY: install-modules
install-modules:
	for subdir in ${PERLMODULES}; do \
	    ( cd ../$$subdir; perl Makefile.PL INSTALL_BASE=${PREFIX}; ) \
	done
	for subdir in ${PERLMODULES}; do \
	    make -C ../$$subdir INSTALL_BASE=${PREFIX}         || exit 1; \
	    make -C ../$$subdir INSTALL_BASE=${PREFIX} install || exit 1; \
	done


## handy to have as a separate target,
## we can call it from frontend installations too (frontend only, no repos)
.PHONY: install-files
install-files: ttservctl prepare-directories install-log install-apache-tika
	${INSTALL_BIN} ../admin/*.sh ../admin/*.pl ${PREFIX}/bin/
	${INSTALL_BIN} ../lib/tika-app-1.18.jar ${PREFIX}/lib/
	${INSTALL_BIN} ../perllib/conf_modperl.pl $(LETSMT_MODPERL_STARTUP)
	${INSTALL_BIN} ttservctl ${PREFIX}/bin
	ln -sf ${PREFIX}/bin/ttservctl /etc/init.d/ttservctl_group
	ln -sf ${PREFIX}/bin/ttservctl /etc/init.d/ttservctl_meta
	update-rc.d ttservctl_group defaults
	update-rc.d ttservctl_meta defaults

## install Apache Tika server (should listen on port 9998)
.PHONY: install-apache-tika
install-apache-tika: ${PREFIX}/lib/tika-server-1.18.jar
	@echo 'description     "Apache Tika Server"'    > tika-server.conf
	@echo ''                                       >> tika-server.conf
	@echo 'start on filesystem or runlevel [2345]' >> tika-server.conf
	@echo 'stop on shutdown'                       >> tika-server.conf
	@echo ''                                       >> tika-server.conf
	@echo 'respawn'                                >> tika-server.conf
	@echo 'respawn limit 3 12'                     >> tika-server.conf
	@echo ''                                       >> tika-server.conf
	@echo "exec java -jar ${PREFIX}/lib/tika-server-1.18.jar" >> tika-server.conf
	${INSTALL_DATA} -b -S .old tika-server.conf /etc/init/tika-server.conf
	rm -f tika-server.conf
	service tika-server start || true

${PREFIX}/lib/tika-server-1.18.jar:
	wget http://www.nic.funet.fi/pub/mirrors/apache.org/tika/tika-server-1.18.jar
	${INSTALL_BIN} tika-server-1.18.jar ${PREFIX}/lib/
	rm -f tika-server-1.18.jar

.PHONY: install-doc
install-doc:
	mkdir -p ${PREFIX}/share/doc/resource_repository
	$(MAKE) doc -C ..
	${COPY} ../perllib/LetsMT/doc/html ../perllib/LetsMT/doc/text \
	    -t ${PREFIX}/share/doc/resource_repository


.PHONY: install-log
install-log:
	${INSTALL_DATA} -b -S .old log4perl.conf ${PREFIX}/etc/repository/


.PHONY: prepare-directories
prepare-directories:
	mkdir -p ${PREFIX}
	mkdir -p ${PREFIX}/etc/repository
	mkdir -p ${LETSMTLOG_DIR}
	chmod ago+w ${LETSMTLOG_DIR}
	chmod ago+s ${LETSMTLOG_DIR}
	mkdir -p ${LETSMTLOG_DIR}/batch_jobs
	chmod ago+rw ${LETSMTLOG_DIR}/batch_jobs
	chmod ago+rwxt ${LETSMT_TMP}


.PHONY: install-frontend-files
install-frontend-files: prepare-directories install-log
	${INSTALL_BIN} ../lib/tika-app-1.18.jar ${PREFIX}/lib


.PHONY: install-config
install-config: \
	config-conf \
	config-gridengine \
	config-apache2 \
	config-mysql \
	config-openssl \
	install-diskroot


.PHONY: install-svnserver
install-svnserver: config-svnserver
	service xinetd restart


.PHONY: update-config
update-config: config-conf config-apache2 install-diskroot

.PHONY: install-diskroot
install-diskroot: ${LETSMTDISKROOT}

${LETSMTDISKROOT}:
	mkdir -p ${LETSMTDISKROOT}
	chown www-data:www-data ${LETSMTDISKROOT}


.PHONY: dbstartup-scripts
dbstartup-scripts: ttservctl

ttservctl: ttservctl.in
	sed -e "s#REPLACE_DBDIR#${DB_DISKROOT}#" \
	    -e "s#REPLACE_DBPORT_GROUP#${GROUP_DB_PORT}#" \
	    -e "s#REPLACE_DBPORT_META#${META_DB_PORT}#" \
	    -e "s#REPLACE_REPLICATION_PORT_GROUP#${GROUP_REPLICATION_PORT}#" \
	    -e "s#REPLACE_REPLICATION_HOST_GROUP#${GROUP_REPLICATION_HOST}#" \
	    -e "s#REPLACE_REPLICATION_PORT_META#${META_REPLICATION_PORT}#" \
	    -e "s#REPLACE_REPLICATION_HOST_META#${META_REPLICATION_HOST}#" \
	< $< > $@


.PHONY: restart-apache
restart-apache:
	service apache2 restart


# add daily cronjobs that 
# - clean up ulog files of tokyo tyrant (keep only the 5 most recent once)
# - optimize the databases

.PHONY: update-cron
update-cron: tt_daily.sh tt_monthly.sh
	-crontab -l | grep -v 'tt_daily.sh' | grep -v 'tt_monthly.sh' > crontab.tmp
	@echo '0 3  *  *  *      ${PREFIX}/bin/tt_daily.sh > ${LETSMTLOG_DIR}/tt_daily.out 2> ${LETSMTLOG_DIR}/tt_daily.err' >> crontab.tmp
	@echo '0 4  1  *  *      ${PREFIX}/bin/tt_monthly.sh > ${LETSMTLOG_DIR}/tt_monthly.out 2> ${LETSMTLOG_DIR}/tt_monthly.err' >> crontab.tmp
	${INSTALL_BIN} tt_daily.sh ${PREFIX}/bin/
	${INSTALL_BIN} tt_monthly.sh ${PREFIX}/bin/
	crontab crontab.tmp
	rm -f crontab.tmp


tt_daily.sh: tt_daily.in
	sed 	-e "s#REPLACE_DBDIR#${DB_DISKROOT}#" \
		-e "s#REPLACE_GROUP_DB_PORT#${GROUP_DB_PORT}#" \
		-e "s#REPLACE_META_DB_PORT#${META_DB_PORT}#" < $< > $@

tt_monthly.sh: tt_monthly.in
	sed 	-e "s#REPLACE_DBDIR#${DB_DISKROOT}#" \
		-e "s#REPLACE_GROUP_DB_PORT#${GROUP_DB_PORT}#" \
		-e "s#REPLACE_META_DB_PORT#${META_DB_PORT}#" < $< > $@


# add table indeces for the metadata DB
# - re-define connect command and webservice URL for using them from the makefile
# - add index to various common fields in the metadata

WS_CONNECT = curl --silent --show-error --cacert ${LETSMT_CACERT}  --cert ${LETSMT_USERCERT}:${LETSMT_USERCERTPASS} --key ${LETSMT_USERKEY}
WS_URL=https://${HOSTNAME}:${LETSMTPORT}/ws

.PHONE: create_metadb_index
create_metadb_index:
	$(WS_CONNECT) -X PUT "${WS_URL}/admin/meta/index/add/size/decimal?uid=admin"
	$(WS_CONNECT) -X PUT "${WS_URL}/admin/meta/index/add/language/token?uid=admin"
	$(WS_CONNECT) -X PUT "${WS_URL}/admin/meta/index/add/resource-type?uid=admin"
	$(WS_CONNECT) -X PUT "${WS_URL}/admin/meta/index/add/status?uid=admin"
	$(WS_CONNECT) -X PUT "${WS_URL}/admin/meta/index/add/uid?uid=admin"
	$(WS_CONNECT) -X PUT "${WS_URL}/admin/meta/index/add/gid?uid=admin"
	$(WS_CONNECT) -X PUT "${WS_URL}/admin/meta/index/add/owner?uid=admin"
	$(WS_CONNECT) -X PUT "${WS_URL}/admin/meta/index/add/_ID_?uid=admin"
	$(WS_CONNECT) -X PUT "${WS_URL}/admin/meta/index/add/_METADATATYPE_?uid=admin"


.PHONE: delete_metadb_index
delete_metadb_index:
	$(WS_CONNECT) -X PUT "${WS_URL}/admin/meta/index/delete/size/decimal?uid=admin"
	$(WS_CONNECT) -X PUT "${WS_URL}/admin/meta/index/delete/language?uid=admin"
	$(WS_CONNECT) -X PUT "${WS_URL}/admin/meta/index/delete/resource-type?uid=admin"
	$(WS_CONNECT) -X PUT "${WS_URL}/admin/meta/index/delete/status?uid=admin"
	$(WS_CONNECT) -X PUT "${WS_URL}/admin/meta/index/delete/uid?uid=admin"
	$(WS_CONNECT) -X PUT "${WS_URL}/admin/meta/index/delete/gid?uid=admin"
	$(WS_CONNECT) -X PUT "${WS_URL}/admin/meta/index/delete/owner?uid=admin"
	$(WS_CONNECT) -X PUT "${WS_URL}/admin/meta/index/delete/_ID_?uid=admin"
	$(WS_CONNECT) -X PUT "${WS_URL}/admin/meta/index/delete/_METADATATYPE_?uid=admin"



# Apache2 configuration
#
# 1) check if the port is listed in ports.conf (otherwise: add port)
# 2) make a backup of the old config file (should we clean this up sometimes)
# 3) make a new apache2 site configuration for the virtual host
# 4) enable the site and restart apache server
#
SITE_CONF = ${APACHE_CONF}/sites-available/$(LETSMTVIRTHOSTFILE)

.PHONY: config-apache2
config-apache2:
	a2enmod apreq2
	a2enmod perl
	a2enmod ssl
	if \
	  ! sed 's/#.*$$//' /etc/apache2/ports.conf |\
	  tr -d '\n' | \
	  grep -qe '<IfModule mod_ssl.c>[^\/]*Listen[[:space:]]'$(LETSMTPORT);\
	then \
	    sed -i '/<IfModule mod_ssl.c>/ aListen '"$(LETSMTPORT)" \
	        /etc/apache2/ports.conf;\
	fi
	sed 	-e 's#REPLACE_LETSMTPORT#$(LETSMTPORT)#' \
		-e 's#REPLACE_LETSMTDOCROOT#${LETSMTDOCROOT}#' \
		-e 's#REPLACE_SERVER#$(LETSMTHOST)#' \
		-e 's#REPLACE_CERTROOT#$(LETSMT_CERTROOT)#' \
		-e 's#REPLACE_CERTPATH#$(LETSMT_CERTPATH)#' \
		-e 's#REPLACE_REVOCATIONPATH#$(LETSMT_REVOCATIONPATH)#' \
		-e 's#REPLACE_MODPERL_STARTUP#$(LETSMT_MODPERL_STARTUP)#' \
		-e 's#REPLACE_LETSMTPERL5LIB#$(PERL5LIB)#' \
		-e 's#REPLACE_APACHE_ERROR_LOG#$(APACHE_ERROR_LOG)#' \
		-e 's#REPLACE_SSL_TIMEOUT#$(SSL_TIMEOUT)#' \
		-e 's#REPLACE_SSL_READLIMIT#$(SSL_READLIMIT)#' \
		-e '/<\/VirtualHost>/ d' \
		-e '/<\/IfModule>/ d' \
	< letsmt > apache.conf
	echo "        PerlSetEnv LETSMTROOT ${LETSMTROOT}" >> apache.conf
	echo "        PerlSetEnv LETSMTHOST ${LETSMTHOST}" >> apache.conf
	echo "        PerlSetEnv LETSMTPORT ${LETSMTPORT}" >> apache.conf
	echo "        PerlSetEnv LETSMT_MODPERL_STARTUP ${LETSMT_MODPERL_STARTUP}" >> apache.conf
	echo "        PerlSetEnv LETSMTUSER ${LETSMTUSER}" >> apache.conf
	echo "        PerlSetEnv LETSMTCONF ${LETSMTCONF}" >> apache.conf
	echo "        PerlSetEnv LETSMTVIRTHOSTFILE ${LETSMTVIRTHOSTFILE}" >> apache.conf
	echo "        PerlSetEnv LETSMT_BATCHQUEUE_MANAGER ${BATCHQUEUE_MANAGER}" >> apache.conf
	echo "        PerlSetEnv LOG4PERLCONF ${LOG4PERLCONF}" >> apache.conf
	echo "        PerlSetEnv LETSMTDISKROOT ${LETSMTDISKROOT}" >> apache.conf
	echo "        PerlSetEnv LETSMT_URL ${LETSMT_URL}" >> apache.conf
	echo "        PerlSetEnv VC_BACKEND ${VC_BACKEND}" >> apache.conf
	echo "        PerlSetEnv UPLOADDIR ${UPLOADDIR}" >> apache.conf
	echo "        PerlSetEnv DB_DISKROOT ${DB_DISKROOT}" >> apache.conf
	echo "        PerlSetEnv LETSMTLOG_DIR ${LETSMTLOG_DIR}" >> apache.conf
	echo "        PerlSetEnv LETSMT_TMP ${LETSMT_TMP}" >> apache.conf
	echo "        PerlSetEnv LETSMT_CACERT ${LETSMT_CACERT}" >> apache.conf
	echo "        PerlSetEnv LETSMT_USERCERT ${LETSMT_USERCERT}" >> apache.conf
	echo "        PerlSetEnv LETSMT_USERCERTPASS ${LETSMT_USERCERTPASS}" >> apache.conf
	echo "        PerlSetEnv LETSMT_USERKEY ${LETSMT_USERKEY}" >> apache.conf
	echo "        PerlSetEnv SGE_ROOT ${SGE_ROOT}" >> apache.conf
	echo "        PerlSetEnv SVN_PASSWORD ${SVN_PASSWORD}" >> apache.conf
	@if [ "${VC_BACKEND}" = "git" ]; then \
	  if [ "${GIT_REMOTE}" != "" ]; then \
	    echo "        PerlSetEnv GIT_REMOTE ${GIT_REMOTE}" >> apache.conf; \
	  fi \
	fi
	@if [ "${PERMISSION_DBMS}" = "mysql" ]; then \
	    echo "        PerlSetEnv DBHOST ${DBHOST}" >> apache.conf; \
	    echo "        PerlSetEnv DBPORT ${DBPORT}" >> apache.conf; \
	    echo "        PerlSetEnv DBNAME ${DBNAME}" >> apache.conf; \
	    echo "        PerlSetEnv DBPASS ${DBPASS}" >> apache.conf; \
	fi
	@if [ "${PERMISSION_DBMS}" = "tt" ]; then \
	    echo "        PerlSetEnv GROUP_DB_HOST ${GROUP_DB_HOST}" >> apache.conf; \
	    echo "        PerlSetEnv GROUP_DB_PORT ${GROUP_DB_PORT}" >> apache.conf; \
	fi
	@if [ "${METADATA_DBMS}" = "tt" ]; then \
	    echo "        PerlSetEnv META_DB_HOST ${META_DB_HOST}" >> apache.conf; \
	    echo "        PerlSetEnv META_DB_PORT ${META_DB_PORT}" >> apache.conf; \
	fi
	echo "</VirtualHost>" >> apache.conf
	echo "</IfModule>" >> apache.conf
	echo 'APREQ2_ReadLimit $(SSL_READLIMIT)' > apreq.conf
	cp --backup=numbered apache.conf $(SITE_CONF)
	${INSTALL_DATA} -b -S .old apreq.conf ${APACHE_CONF}/conf-available/apreq.conf
	( cd ${APACHE_CONF}/conf-enabled && ln -sf ../conf-available/apreq.conf . )
	a2ensite $(LETSMTVIRTHOSTFILE)
	mkdir -p ${LETSMTDOCROOT}
	sed -i 's/^export LANG=.*/export LANG=${LANG}/' /etc/apache2/envvars
	grep 'export LC_ALL=${LANG}' /etc/apache2/envvars > /dev/null || \
	    echo 'export LC_ALL=${LANG}' >> /etc/apache2/envvars

## OLD:
#	${INSTALL_DATA} -b -S .old apreq.conf ${APACHE_CONF}/conf.d/apreq.conf
# 	mkdir -p ${PREFIX}/www

# create the general LetsMT configuration file
# (this is only used for developer-specific settings now)
# (global settings will be in /etc/environment, see below)
.PHONY: config-conf
config-conf:
	@echo "#!/bin/bash" > conf.sh
	@echo "export LANG=${LANG}" >> conf.sh
	@echo "export LC_ALL=${LANG}" >> conf.sh
	@echo "export LETSMTROOT=${LETSMTROOT}" >> conf.sh
	@echo "export LETSMTHOST=${LETSMTHOST}" >> conf.sh
	@echo "export LETSMTPORT=${LETSMTPORT}" >> conf.sh
	@echo "export LETSMT_MODPERL_STARTUP=${LETSMT_MODPERL_STARTUP}" >> conf.sh
	@echo "export LETSMTUSER=${LETSMTUSER}" >> conf.sh
	@echo "export LETSMTCONF=${LETSMTCONF}" >> conf.sh
	@echo "export LETSMTVIRTHOSTFILE=${LETSMTVIRTHOSTFILE}" >> conf.sh
	@echo "export LETSMT_BATCHQUEUE_MANAGER ${BATCHQUEUE_MANAGER}" >> conf.sh
	@echo "export LOG4PERLCONF=${LOG4PERLCONF}" >> conf.sh
	@echo "export PERL5LIB=${PERL5LIB}" >> conf.sh
	@echo "export VC_BACKEND=${VC_BACKEND}" >> conf.sh
	@echo "export UPLOADDIR=${UPLOADDIR}" >> conf.sh
	@echo "export LETSMTDISKROOT=${LETSMTDISKROOT}" >> conf.sh
	@echo "export DB_DISKROOT=${DB_DISKROOT}" >> conf.sh
	@echo "export LETSMTLOG_DIR=${LETSMTLOG_DIR}" >> conf.sh
	@echo "export LETSMT_TMP=${LETSMT_TMP}" >> conf.sh
	@echo "export LETSMT_CACERT=${LETSMT_CACERT}" >> conf.sh
	@echo "export LETSMT_USERCERT=${LETSMT_USERCERT}" >> conf.sh
	@echo "export LETSMT_USERCERTPASS=${LETSMT_USERCERTPASS}" >> conf.sh
	@echo "export LETSMT_USERKEY=${LETSMT_USERKEY}" >> conf.sh
	@echo "export LETSMT_CONNECT=\"${LETSMT_CONNECT}\"" >> conf.sh
	@echo "# (LETSMT_CONNECT_RAW is just an alias for historical reasons)" >> conf.sh
	@echo "export LETSMT_CONNECT_RAW=\"\$$LETSMT_CONNECT\"" >> conf.sh
	@echo "export LETSMT_URL=\"${LETSMT_URL}\"" >> conf.sh
	@echo "export SSL_TIMEOUT=${SSL_TIMEOUT}" >> conf.sh
	@echo "export CLASSPATH=\"${CLASSPATH}\"" >> conf.sh
	@if [ "${VC_BACKEND}" = "git" ]; then \
	  if [ "${GIT_REMOTE}" != "" ]; then \
	    echo "export GIT_REMOTE=${GIT_REMOTE}" >> conf.sh; \
	  fi \
	fi
	@if [ "${PERMISSION_DBMS}" = "mysql" ]; then \
	    echo "export DBHOST=${DBHOST}" >> conf.sh; \
	    echo "export DBPORT=${DBPORT}" >> conf.sh; \
	    echo "export DBUSER=${DBUSER}" >> conf.sh; \
	    echo "export DBPASS=${DBPASS}" >> conf.sh; \
	    echo "export DBNAME=${DBNAME}" >> conf.sh; \
	fi
	@if [ "${PERMISSION_DBMS}" = "tt" ]; then \
	    echo "export GROUP_DB_HOST=${GROUP_DB_HOST}" >> conf.sh; \
	    echo "export GROUP_DB_PORT=${GROUP_DB_PORT}" >> conf.sh; \
	fi
	@if [ "${METADATA_DBMS}" = "tt" ]; then \
	    echo "export META_DB_HOST=${META_DB_HOST}" >> conf.sh; \
	    echo "export META_DB_PORT=${META_DB_PORT}" >> conf.sh; \
	fi
	${INSTALL_BIN} conf.sh $(LETSMTCONF)
	grep "source ${LETSMTCONF}" /etc/bash.bashrc > /dev/null || \
		echo "source ${LETSMTCONF}" | tee -a /etc/bash.bashrc


## Configure the SVN server.
.PHONY: config-svnserver
config-svnserver: ${PREFIX}/etc/repository/svnserve.conf \
		/etc/xinetd.d/svn \
		/etc/xinetd.conf

## default svnserve.conf
${PREFIX}/etc/repository/svnserve.conf: svnserve.conf
	${INSTALL_DATA} -b -S .old $< $@

## Startup script via xinetd.
# (check http://www.linuxfromscratch.org/blfs/view/svn/server/svnserver.html)
/etc/xinetd.d/svn: xinetd-svn
	sed 	-e 's#REPLACE_LETSMTDISKROOT#$(LETSMTDISKROOT)#' \
		-e 's#REPLACE_LETSMTUSER#$(LETSMTUSER)#' \
		-e 's#REPLACE_SVN_PORT#$(SVN_PORT)#' \
	< $< > $@

/etc/xinetd.conf: xinetd.conf
	${INSTALL_DATA} -b -S .old $< $@

## For frontend installations.
## Replace LETSMTHOST with webserver hostname
.PHONY: config-conf-frontend
config-conf-frontend:
	sed -i 's/^export LETSMTHOST=.*/export LETSMTHOST="${LETSMTHOST}"/' \
	    $(LETSMTCONF) >&2


.PHONY: config-cpan
config-cpan:
	test -d ~/.cpan/CPAN || mkdir -p ~/.cpan/CPAN
	test -f ~/.cpan/CPAN/MyConfig.pm || cp MyConfig.pm ~/.cpan/CPAN/


.PHONY: config-mysql
config-mysql:
	if [ "${PERMISSION_DBMS}" = "mysql" ]; then \
	    bash -c 'source $(LETSMTCONF) && bash setup_db.sh'; \
	fi


# TODO: check what we have to do to issue new certificates
#       for additional servers

.PHONY: config-openssl
config-openssl: ${LETSMT_SSL_DIR}

${LETSMT_SSL_DIR}:
	 ${PREFIX}/bin/setup_cert_based_auth.pl \
		--projname "$(LETSMT_SSL_PROJECT)" \
		--country "$(LETSMT_SSL_COUNTRY)" \
		--city "$(LETSMT_SSL_CITY)" \
		--company "$(LETSMT_SSL_COMPANY)" \
		--user "$(LETSMT_SSL_USER)" \
		--username "$(LETSMT_SSL_USERNAME)" \
		--ssl_sysdir "$(LETSMT_SSL_HOME)"\
		--site $(LETSMTHOST)


.PHONY: config-gridengine
config-gridengine:
	-qconf -am www-data         # add user to manager list
	-qconf -au www-data letsmt  # add user(s) to userset list(s)
	-qconf -as ${LETSMTHOST}    # add submit hosts
	-qconf -as localhost
	sed    -e "s#REPLACE_HOSTNAME#${LETSMTHOST} localhost#" letsmt.q_conf > letsmt.q
	-qconf -Aq letsmt.q



#########################################################################
# add a swapfile for more flexibility in memory allocation
# (https://www.digitalocean.com/community/tutorials/how-to-add-swap-on-ubuntu-14-04)

.PHONY: install-swap
install-swap: /swapfile
/swapfile:
	fallocate -l 8G /swapfile
	chmod 600 /swapfile
	mkswap /swapfile
	swapon /swapfile
	grep -v '/swapfile' /etc/fstab > fstab.tmp
	echo '/swapfile   none    swap    sw    0   0' >> fstab.tmp
	${INSTALL_DATA} -b -S .old fstab.tmp /etc/fstab
	rm -f fstab.tmp


#########################################################################
## cleaning

.PHONY: distclean
distclean:
	rm -f apache.conf \
	      apreq.conf \
	      conf.sh \
	      letsmt.q \
	      ttservctl


#########################################################################
## uninstalling

.PHONY: uninstall
uninstall:
	update-rc.d ttservctl_group disable
	update-rc.d ttservctl_meta  disable
	[ -n "${PREFIX}" ] && rm -f ${PREFIX}/bin/ttservctl
	[ -n "${PREFIX}" ] && rm -rf ${PREFIX}/lib/perl5/LetsMT
	[ -n "${PREFIX}" ] && rm -rf ${PREFIX}/lib/perl5/auto/share/dist/LetsMT
	[ -n "${LETSMTDISKROOT}/../compressed" ] && rm -rf ${LETSMTDISKROOT}/../compressed/*

.PHONY: purge
purge: uninstall
	rm -f /etc/init.d/ttservctl_group \
	      /etc/init.d/ttservctl_meta
	[ -n "${PREFIX}"         ] && rm -rf ${PREFIX}/etc/repository
	[ -n "${LETSMTDISKROOT}" ] && rm -rf ${LETSMTDISKROOT}
	[ -n "${LETSMTLOG_DIR}"  ] && rm -rf ${LETSMTLOG_DIR}/*
	[ -n "${DB_DISKROOT}"    ] && rm -rf ${DB_DISKROOT}/*.*
	[ -n "${LETSMT_SSL_DIR}" ] && rm -rf ${LETSMT_SSL_DIR}
	[ -n "${HOSTNAME}"       ] && rm -f /etc/apache2/ssl_certs/server/*/${HOSTNAME}.*
	a2dissite ${LETSMTVIRTHOSTFILE}
	-a2dismod ssl
	service apache2 reload
	[ -n "${LETSMTCONF}"     ] && sed -i 's#source ${LETSMTCONF}##' /etc/bash.bashrc
	@echo
	@echo "Besides the purging of all files and settings of LetsMT, the Apache 2 SSL module"
	@echo "was disabled. This may not be what you intended. If you need the module elsewhere,"
	@echo "run 'sudo a2enmod ssl; sudo service apache2 reload'."
	@echo


#########################################################################
