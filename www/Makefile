# -*-makefile-*-

INSTALL = install
INSTALL_BIN = ${INSTALL} -m 755 -p
INSTALL_DATA = ${INSTALL} -m 644 -p
COPY = cp -r --preserve=mode,timestamps

include ../Makefile.conf


## Ask for the sitename if it is not defined
ifndef MYSQL_ROOT_PASSWORD
    MYSQL_ROOT_PASSWORD=$(shell whiptail --title 'mySQL root password' \
                --inputbox '' \
                8 40 "letsmt" 2>&1 1>/dev/tty)
endif


#########################################################################
## installing

.PHONY: install
install:
	-service grenzschnitte stop
	mkdir -p ${PREFIX}/lib/grenzschnitte/bin \
	         ${PREFIX}/lib/grenzschnitte/log
	${COPY} lib public templates \
	    -t ${PREFIX}/lib/grenzschnitte
	chown -R ${LETSMTUSER} \
	    ${PREFIX}/lib/grenzschnitte/public \
	    ${PREFIX}/lib/grenzschnitte/log
	${INSTALL_BIN}  -b -S .old bin/webinterface \
	    -t ${PREFIX}/lib/grenzschnitte/bin
# Configure
	sed -e "s#REPLACE_MYSQL_ROOT_PASSWORD#${MYSQL_ROOT_PASSWORD}#" \
	< web_interface.json.template > web_interface.json
	${INSTALL_DATA} -b -S .old web_interface.json \
	    ${PREFIX}/lib/grenzschnitte/web_interface.json
	${INSTALL_BIN}  -b -S .old etc/startup-script \
	    /etc/init.d/grenzschnitte
	update-rc.d grenzschnitte defaults
	${INSTALL_DATA} -b -S .old etc/apache-vhost.conf \
	    /etc/apache2/sites-available/grenzschnitte
	a2enmod headers proxy proxy_http
	a2ensite grenzschnitte
	service grenzschnitte start
	service apache2 reload
# Inform
	@echo
	@echo "Grenzschnitte is now listening on http://*:8080/ and http://*:3000/,"
	@echo "which means that you should be able to reach it under http://localhost:81/,"
	@echo "http://$(shell hostname):8080/ etc."
	@echo


#########################################################################
## uninstalling

.PHONY: uninstall
uninstall:
	-a2dissite grenzschnitte
	service grenzschnitte stop
	update-rc.d grenzschnitte delete
	rm -rf ${PREFIX}/lib/grenzschnitte

.PHONY: purge
purge: uninstall
	rm -f /etc/apache2/sites-available/grenzschnitte
	rm -f /etc/init.d/grenzschnitte
	-a2dismod headers proxy_http proxy
	service apache2 reload
	@echo
	@echo "Besides the removal of all files and settings of the Grenzschnitte, the Apache"
	@echo "2 modules 'headers' and 'proxy_http' were disabled. This may not be what you"
	@echo "intended. If you need either elsewhere, run 'sudo a2enmod headers' and/or"
	@echo "'sudo a2enmod proxy_http', and then 'sudo service apache2 reload'."
	@echo


#########################################################################
## cleaning up

.PHONY: distclean
distclean: clean

.PHONY: clean
clean:
	rm -rf web_interface.json


#########################################################################