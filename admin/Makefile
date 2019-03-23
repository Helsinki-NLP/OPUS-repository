
## change BACKUP to the one to be restored

BACKUP = Sat

LETSMTROOT = /var/lib/letsmt
BACKUPDIR = /var/lib/letsmt/backup/monthly


METAFILES = ${patsubst ${BACKUPDIR}/meta.${BACKUP}%,\
		${LETSMTROOT}/metadata%,\
		${wildcard ${BACKUPDIR}/meta.${BACKUP}.*}}


## only print the commands that need to be run

restore-meta: ${METAFILES}

${METAFILES}: ${LETSMTROOT}/metadata%: ${BACKUPDIR}/meta.${BACKUP}%
	@echo "make stop-db"
	@echo "sudo cp $< $@"
	@echo "make start-db"
