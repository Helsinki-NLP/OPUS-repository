
## change BACKUP to the one to be restored

BACKUP = Sat

LETSMTROOT = /var/lib/letsmt
BACKUPDIR = /var/lib/letsmt/backup/monthly


METAFILES = ${patsubst ${BACKUPDIR}/meta.${BACKUP}%,\
		${LETSMTROOT}/metadata.tct%,\
		${wildcard ${BACKUPDIR}/meta.${BACKUP}*}}


## only print the commands that need to be run

restore-meta: ${METAFILES}

${METAFILES}: ${LETSMTROOT}/metadata.tct%: ${BACKUPDIR}/meta.${BACKUP}%
	@echo "sudo cp $< $@"
