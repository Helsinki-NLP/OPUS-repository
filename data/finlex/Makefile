#
# FinLex from the Semantic FinLex project
#
#


# https://data.finlex.fi/download/xml/asd/asd-fi.zip
# https://data.finlex.fi/download/xml/asd/asd-sv.zip

# https://data.finlex.fi/download/xml/kko/kko-fi.zip
# https://data.finlex.fi/download/xml/kko/kko-sv.zip

# https://data.finlex.fi/download/xml/kho/kho-fi.zip
# https://data.finlex.fi/download/xml/kho/kho-sv.zip


DOWNLOAD = https://data.finlex.fi/download/xml
DATASETS = asd kko kho

FI_TAR = ${patsubst %,%-fi.tar.gz,${DATASETS}}
SV_TAR = ${patsubst %,%-sv.tar.gz,${DATASETS}}



all: config upload cleanup

config:
	${LETSMT_CONNECT} -X POST \
		"${LETSMT_URL}/metadata/finlex/opus/uploads?uid=opus&AlignPara_method=hunalign&ImportPara_trust_langid=off"

upload: ${FI_TAR} ${SV_TAR}

cleanup:
	rm -f ${FI_TAR} ${SV_TAR}
	rmdir ${DATASETS}





## download zip files

%-fi.zip:
	wget ${DOWNLOAD}/${@:-fi.zip=}/$@

%-sv.zip:
	wget ${DOWNLOAD}/${@:-sv.zip=}/$@



## convert to tar with the language/dataset dir's swapped
## and upload to the repository for importing ....

${FI_TAR}: %.tar.gz: %.zip
	unzip $<
	tar -czf $@ \
		--transform 's#^\(${@:-fi.tar.gz=}\)/fi#fi/\1#' \
		${subst -,/,${@:.tar.gz=}}
	rm -fr ${subst -,/,${@:.tar.gz=}}
	${LETSMT_CONNECT} -X PUT \
		"${LETSMT_URL}/storage/finlex/opus/uploads/$@?uid=opus&action=import" \
		--form payload=@$@
	rm -f $<


${SV_TAR}: %.tar.gz: %.zip
	unzip $<
	tar -czf $@ \
		--transform 's#^\(${@:-sv.tar.gz=}\)/sv#sv/\1#' \
		${subst -,/,${@:.tar.gz=}}
	rm -fr ${subst -,/,${@:.tar.gz=}}
	${LETSMT_CONNECT} -X PUT \
		"${LETSMT_URL}/storage/finlex/opus/uploads/$@?uid=opus&action=import" \
		--form payload=@$@
	rm -f $<

