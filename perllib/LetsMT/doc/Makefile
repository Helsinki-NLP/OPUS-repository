## Directories where to put the documentation files.
## Must not contain a leading "./" ("current directory").
text_home = text
html_home = html

####
bin_home       = ../bin
module_home    = ../lib
test_home      = ../t
extratest_home = ../xt

scripts = $(shell grep 'install_script' ../Makefile.PL | cut -f2 -d ' ' | cut -f2 -d '/' | sed "s/';//")
modules = $(patsubst ${module_home}/%,%,$(shell find ${module_home} -name '*.pm' | LC_ALL=C sort))
tests   = $(patsubst ${test_home}/%,%,$(shell find ${test_home} -name '*.t' | LC_ALL=C sort))
xtests  = $(patsubst ${extratest_home}/%,%,$(shell find ${extratest_home} -name '*.t' | LC_ALL=C sort))

textdoc_bin = $(patsubst %,${text_home}/%.txt,$(scripts))
htmldoc_bin = $(patsubst %,${html_home}/%.html,$(scripts))

textdoc = $(patsubst %.pm,${text_home}/%.txt,$(modules))
htmldoc = $(patsubst %.pm,${html_home}/%.html,$(modules))

## For now we throw tests & extra tests into the same directory
## - otherwise the whole menu creation would need to be rewritten...
## Just be a bit careful not to call tests and extra tests the same...!
textdoc_test  = $(patsubst %.t,${text_home}/t/%.txt,$(tests))
htmldoc_test  = $(patsubst %.t,${html_home}/t/%.html,$(tests))
textdoc_xtest = $(patsubst %.t,${text_home}/t/%.txt,$(xtests))
htmldoc_xtest = $(patsubst %.t,${html_home}/t/%.html,$(xtests))

htmlgraph = $(patsubst %.pm,${html_home}/%_graph.html,$(modules))
pnggraph = $(patsubst %.pm,${html_home}/%.png,$(modules))
svggraph = $(patsubst %.pm,${html_home}/%.svg,$(modules))

## All modules in the way they are used by Perl
perlmods = $(subst /,::,$(patsubst %.pm,%,$(modules)))

#### Targets
.PHONY: all
all: text html

.PHONY: text
text: ${textdoc} ${textdoc_bin} ${textdoc_test}

.PHONY: html
html: html-only png

.PHONY: html-only
html-only:	${htmldoc} \
		${htmldoc_bin} \
		${htmldoc_test} \
		${htmldoc_xtest} \
		${html_home}/modules.html \
		${html_home}/index.html \
		${html_home}/pod.css
	rm -f pod*.tmp

.PHONY: png svg htmlgraph
png      : ${pnggraph}
svg      : ${svggraph}
htmlgraph: ${htmlgraph}


#### HTML
${html_home}/index.html: index.html
	cp index.html ${html_home}

${html_home}/pod.css: pod.css
	cp pod.css ${html_home}

${html_home}/modules.html:
	@echo ${scripts} ${modules} ${tests} ${xtests} | sed 's_ _\n_g' | grep -v '^LetsMT.pm' | ./menu.pl > $@

${htmldoc_bin}  : ${html_home}/%.html  : ${bin_home}/%
${htmldoc}      : ${html_home}/%.html  : ${module_home}/%.pm
${htmldoc_test} : ${html_home}/t/%.html: ${test_home}/%.t
${htmldoc_xtest}: ${html_home}/t/%.html: ${extratest_home}/%.t


#### TXT
${textdoc_bin}  : ${text_home}/%.txt  : ${bin_home}/%
${textdoc}      : ${text_home}/%.txt  : ${module_home}/%.pm
${textdoc_test} : ${text_home}/t/%.txt: ${test_home}/%.t
${textdoc_xtest}: ${text_home}/t/%.txt: ${extratest_home}/%.t


#### Graphs
${pnggraph} : ${html_home}/%.png       : ${module_home}/%.pm
${svggraph} : ${html_home}/%.svg       : ${module_home}/%.pm
${htmlgraph}: ${html_home}/%_graph.html: ${module_home}/%.pm


#### Handlers for file types
%.png %.svg %_graph.html:
	./classgraph.pl $(subst /,::, \
			$(patsubst ${module_home}/%.pm,%,$<)) $@ ${perlmods}

%.html:
	$(eval cleanfn := $(patsubst ${html_home}/%.html,%,$@))
	$(eval reldir  := $(shell echo "$(dir ${cleanfn})" | sed 's_^\./__;s_[^/]*/_../_g' ))
#	@echo ${reldir} - $(dir ${cleanfn}) - $(notdir ${cleanfn})
	@mkdir -p $(dir $@)
	pod2html --htmlroot=./${reldir} --css=${reldir}pod.css --title="$(notdir ${cleanfn})" \
	    --infile=$< --outfile=$@

%.txt:
	@mkdir -p $(dir $@)
	pod2text $< $@


#### Cleaning up
.PHONY: clean
clean: clean-text clean-html-full

.PHONY: clean-text
clean-text:
	rm -rf ${text_home}

.PHONY: clean-html-full
clean-html-full:
	rm -rf ${html_home}
	rm -f *.tmp

.PHONY: clean-html
clean-html:
	find ${html_home} -name '*.html' -delete

.PHONY: clean-png
clean-png:
	find ${html_home} -name '*.png' -delete

.PHONY: clean-svg
clean-svg:
	find ${html_home} -name '*.svg' -delete
