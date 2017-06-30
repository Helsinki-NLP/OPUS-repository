.SUFFIXES: .lm .txt

all:
	for file in *.txt;\
	do make -s `echo $$file|cut -d . -f 1`.lm;\
	done

TEXT_CAT=letsmt_langdetect

.txt.lm: %.lm: %.txt
	$(TEXT_CAT) -n $* $*.txt

install: all
	mv *.lm ..
