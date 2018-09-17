


deprel-files: ud-deprels.sv ud-deprels.en



STATS_SV = https://raw.githubusercontent.com/UniversalDependencies/UD_Swedish-Talbanken/master/stats.xml
STATS_EN = https://raw.githubusercontent.com/UniversalDependencies/UD_English-ParTUT/master/stats.xml

ud-deprels.sv:
	wget ${STATS_SV}
	grep '<dep ' stats.xml |\
	sed 's/^.*name=\"\([^\"]*\)\".*$$/\1/' > $@
	rm -f stats.xml

ud-deprels.en:
	wget ${STATS_EN}
	grep '<dep ' stats.xml |\
	sed 's/^.*name=\"\([^\"]*\)\".*$$/\1/' > $@
	rm -f stats.xml




adrift.fi-sv: adrift.fi-sv.xml
	grep -o 'xtargets="[^ ][^ ]*;[^ ][^ ]*"' $< | cut -f2 -d'"' > $@

adrift.fi.db: adrift.fi.xml
	perl deprel2db.pl $< $@ > $(@:.db=.ids)

adrift.sv.db: adrift.sv.xml
	perl deprel2db.pl $< $@ > $(@:.db=.ids)
