#
# USAGE
#
#  make   ................... make files needed for ISA (sentence alignment) 
#                             with default corpus (1988sven)
#  make sentalign ........... make ISA files for default corpus
#
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# set the UPLUG, UPLUGSHARE, SENTALIGNER variables below
# if uplug is not in your path and globally installed
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
#############################################################################
# set the following variables if necessary:
#
# CORPUS ...... name of the corpus (without extension)
# SRCLANG ..... source language identifier (eg. en, sv, ...)
# TRGLANG ..... target language identifier (eg. en, sv, ...)
#
# UPLUG ....... home directory of your Uplug distribution
# UPLUGWEB .... location of uplug when accessed from PHP
# ALIGN ....... type of word alignment to be run (to create clue DBMs)
#
#
# SRCXML ...... source language document (default: $(CORPUS)$(SRCLANG).xml)
# TRGXML ...... target language document (default: $(CORPUS)$(TRGLANG).xml)
#
#############################################################################

VERSION  = 0.1

# UPLUG = path to uplug start script
# UPLUGSHARE = home directory of shared data
# SENTALIGNER = default alignment program (Gale&Church)

ifndef UPLUG
  UPLUG       = $(shell which uplug)
endif
ifndef UPLUGSHARE
  UPLUGSHARE  = $(shell perl -e 'use Uplug::Config;print &shared_home();')
endif
ifndef SENTALIGNER
  SENTALIGNER = $(shell perl -e 'use Uplug::Config;print find_executable("align2");')
endif

ifndef LETSMT_CONNECT
  LETSMT_CONNECT = %%LETSMT_CONNECT%%
endif
ifndef LETSMT_URL
  LETSMT_URL = %%LETSMT_URL%%
endif


ALIGN = basic


SLOT    = corpus
USER    = user
SRCLANG = en
TRGLANG = sv
FILE    = 398

LANGPAIR     = $(SRCLANG)-$(TRGLANG)
INVLANGPAIR  = $(TRGLANG)-$(SRCLANG)

CORPUS       = corpora/${SLOT}_${LANGPAIR}_$(subst /,_,${FILE})
DATADIR      = ${CORPUS}

## resource path in the LetsMT repository
# SRC_RESOURCE = ${SLOT}/${USER}/xml/${SRCLANG}/${FILE}.xml
# TRG_RESOURCE = ${SLOT}/${USER}/xml/${TRGLANG}/${FILE}.xml
ALG_RESOURCE = ${SLOT}/${USER}/xml/${LANGPAIR}/${FILE}.xml

## local files
SRCRAWXML    = ${DATADIR}/${SRCLANG}.raw
TRGRAWXML    = ${DATADIR}/${TRGLANG}.raw
SRCXML       = ${DATADIR}/${SRCLANG}.xml
TRGXML       = ${DATADIR}/${TRGLANG}.xml

SENTALIGN    = ${CORPUS}.ces
SENTALIGNIDS = ${CORPUS}.ids

# configuration files
CONFIG       = $(DATADIR)/config.inc
ISACONFIG    = $(DATADIR)/config.isa


all: $(DATADIR) $(SRCXML) $(TRGXML) $(SENTALIGN) $(CONFIG)


$(DATADIR):
	mkdir -p corpora
	chmod +s corpora
	mkdir -p $(DATADIR)
#	mkdir -p $(DATADIR)/data/runtime


$(SRCRAWXML): $(SENTALIGN)
	mkdir -p ${dir $@}
	( s=`grep -o 'fromDoc="[^"]*"' $< | cut -f2 -d'"'`; \
	  echo "--$$s--"; \
	  ${LETSMT_CONNECT} -X GET \
	  "${LETSMT_URL}/storage/${SLOT}/${USER}/xml/$$s?uid=${USER}&archive=0&action=download" \
	  > $@; )

$(TRGRAWXML): $(SENTALIGN)
	mkdir -p ${dir $@}
	( t=`grep -o 'toDoc="[^"]*"' $< | cut -f2 -d'"'`; \
	  echo "--$$t--"; \
	  ${LETSMT_CONNECT} -X GET \
	  "${LETSMT_URL}/storage/${SLOT}/${USER}/xml/$$t?uid=${USER}&archive=0&action=download" \
	  > $@; )

$(SENTALIGN):
	mkdir -p ${dir $@}
	${LETSMT_CONNECT} -X GET \
		"${LETSMT_URL}/storage/${ALG_RESOURCE}?uid=${USER}&archive=0&action=download" \
		> $@


$(SRCXML): $(SRCRAWXML)
	mkdir -p ${dir $@}
	cat $< | grep -v '<time ' |\
	$(UPLUG) pre/tok -l ${SRCLANG} -out $@

#	$(UPLUG) pre/tok -l ${SRCLANG} -in $< -out $@

$(TRGXML): $(TRGRAWXML)
	mkdir -p ${dir $@}
	cat $< | grep -v '<time ' |\
	$(UPLUG) pre/tok -l ${TRGLANG} -out $@

#	$(UPLUG) pre/tok -l ${TRGLANG} -in $< -out $@


$(CONFIG): $(DATADIR)/%.inc: include/%.in $(SRCXML) $(TRGXML)
	sed 's#%%IDFILE%%#$(SENTALIGNIDS)#' $< |\
	sed 's#%%DATADIR%%#$(DATADIR)#' |\
	sed 's#%%SRCXML%%#$(SRCXML)#' |\
	sed 's#%%TRGXML%%#$(TRGXML)#' |\
	sed 's#%%BITEXT%%#$(SENTALIGN)#' |\
	sed 's#%%UPLUG%%#$(UPLUG)#' |\
	sed 's#%%UPLUGSHARE%%#$(UPLUGSHARE)#' |\
	sed 's#%%SENTALIGNER%%#$(SENTALIGNER)#' |\
	sed 's#%%LANGPAIR%%#$(LANGPAIR)#' |\
	sed 's#%%INVLANGPAIR%%#$(INVLANGPAIR)#' > $@

$(ISACONFIG): $(DATADIR)/%.isa: include/%.in $(SRCXML) $(TRGXML)
	sed 's#%%IDFILE%%#$(SENTALIGNIDS)#' $< |\
	sed 's#%%DATADIR%%#$(DATADIR)#' |\
	sed 's#%%SRCXML%%#$(SRCXML)#' |\
	sed 's#%%TRGXML%%#$(TRGXML)#' |\
	sed 's#%%BITEXT%%#$(SENTALIGN)#' |\
	sed 's#%%UPLUG%%#$(UPLUG)#' |\
	sed 's#%%UPLUGSHARE%%#$(UPLUGSHARE)#' |\
	sed 's#%%SENTALIGNER%%#$(SENTALIGNER)#' |\
	sed 's#%%LANGPAIR%%#$(LANGPAIR)#' |\
	sed 's#%%INVLANGPAIR%%#$(INVLANGPAIR)#' > $@

clean:
	rm -f config.inc
	rm -f $(SENTALIGNIDS)

