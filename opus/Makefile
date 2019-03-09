###########################################################################
## OPUS specific installation (remote git & OPUS-specific ssl keys)
##
##   sudo make opus-stable ........... install the stable OPUS RR
##   sudo make opus-client-stable .... install client for stable OPUS RR
##   sudo make opus-dev .............. install the OPUS development server
##   sudo make opus-client-dev ....... install client for dev OPUS RR
##
##   make update ..................... make code update on all nodes
##   make update-dev ................. make code update on all dev nodes
##
##
## this calls the targets for the RR server and clients with pre-set
## settings for the SERVERHOST, GITSERVER ....
##
##   sudo make install-opus .......... install repository server
##   sudo make install-opus-client ... install slurm compute node
##
###########################################################################

## remote git server for OPUS
GITSEVER = version.helsinki.fi
OPUSGIT  = git@${GITSERVER}:OPUS
ADMIN    = tiedeman
KEYHOME  = taito.csc.fi:/proj/OPUS/admin/repository

## stable version
OPUS_STABLE    = vm1637.kaj.pouta.csc.fi
OPUS_STABLE_IP = 192.168.1.19

## development version
OPUS_DEV       = vm0081.kaj.pouta.csc.fi
OPUS_DEV_IP    = 192.168.1.10

## worker nodes of stable and development version
OPUS_CLIENTS    = 
OPUSDEV_CLIENTS = opusdev0 opusdev1 opusdev2



## code update on all nodes and the RR server
update:
	sudo make -C .. code-update
	for s in ${OPUS_CLIENTS}; do \
	  rsync --delete -zav ${HOME}/OPUS-repository cloud-user@$$s:.; \
	  ssh -i /home/cloud-user/.ssh/opus $$s sudo make -C OPUS-repository code-update; \
	done

## code update on all nodes and the RR server
update-dev:
	sudo make -C .. code-update
	for s in ${OPUSDEV_CLIENTS}; do \
	  rsync --delete -zav ${HOME}/OPUS-repository cloud-user@$$s:.; \
	  ssh -i /home/cloud-user/.ssh/opus $$s sudo make -C OPUS-repository code-update; \
	done


## install stable versions
opus-stable opus-client-stable:
	${MAKE} OPUSGIT=git@version.helsinki.fi:OPUS \
		HOSTNAME=${OPUS_STABLE} \
		OPUSRR=${OPUS_STABLE} \
		OPUSIP=${OPUS_STABLE_IP} \
	${@:-stable=}

## install development versions
opus-dev opus-client-dev:
	${MAKE} OPUSGIT= \
		HOSTNAME=${OPUS_DEV} \
		OPUSRR=${OPUS_DEV} \
		OPUSIP=${OPUS_DEV_IP} \
	${@:-dev=}

ifndef OPUSRR
  OPUSRR = ${OPUS_STABLE}
  OPUSIP = ${OPUS_STABLE_IP}
endif

## install repository for OPUS with connection to remote git server
.PHONY: install-opus opus
install-opus opus: /etc/munge/munge.key /etc/ssl/${HOSTNAME}
ifneq (${GITSERVER},)
	${MAKE} /var/www/.ssh/config
endif
	${MAKE} -C .. GIT_REMOTE='${OPUSGIT}' HOSTNAME=${OPUSRR} install
	service munge restart
	service slurm-llnl restart
	@echo
	@echo '----------------------------------------------------------';
	@echo "Installation of the OPUS repository backend finished"
	@echo "Don't forget to upload the public key /etc/ssh/opusrr.pub"
	@echo "to the git server at ${OPUSGIT}!"
	@echo '----------------------------------------------------------';
	@echo

.PHONY: install-opus-client opus-client
install-opus-client opus-client: /etc/ssl/${OPUSRR} /etc/munge/munge.key
	${MAKE} -C .. SLURM_SERVER=${OPUSIP} LETSMTHOST=${OPUSRR} install-client
	service munge restart
	service slurm-llnl restart

/var/www/.ssh/config: /etc/ssh/opusrr
	mkdir -p ${dir $@}
	echo 'Host *' > $@
	echo '  IdentityFile /etc/ssh/opusrr' >> $@
	chown -R www-data:www-data $@
	chmod 700 $@
	chmod 400 $@
	ssh-keyscan -H ${GITSERVER} > ${dir $@}/known_hosts
	chown -R www-data:www-data ${dir $@}/known_hosts


## copy ssh, ssl and munge keys from KEYHOME

/etc/ssh/opusrr:
	mkdir -p ${dir $@}
	rsync -zav ${ADMIN}@${KEYHOME}/ssh/opusrr* ${dir $@}
	chown www-data:www-data $@ $@.pub
	chmod 400 $@
	chmod 444 $@.pub

/etc/munge/munge.key:
	mkdir -p ${dir $@}
	apt-get -qq install munge
	rsync -zav ${ADMIN}@${KEYHOME}/munge/munge.key $@
	chmod 400 $@
	chmod 700 ${dir $@}
	chown munge:munge ${dir $@} $@

/etc/ssl/${OPUSRR}:
	mkdir -p ${dir $@}
	rsync -zav ${ADMIN}@${KEYHOME}/ssl/${OPUSRR} ${dir $@}
	chmod -R og+rX $@

## generate a new ssh key for remote git access
#
#/etc/ssh/opusrr:
#	ssh-keygen -q -t rsa -f $@ -N ""
#	chown www-data:www-data $@
#	chmod 400 $@
