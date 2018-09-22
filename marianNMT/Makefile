# -*-makefile-*-


INSTALL = install -c
INSTALL_BIN = ${INSTALL} -m 755
INSTALL_DATA = ${INSTALL} -m 644

PREFIX = /usr/local
APTGET = apt-get

.PHONY: all
all: install-marian

.PHONY: install-prereq
install-prereq:
	$(APTGET) -qq git cmake3 libboost-all-dev

.PHONY: install-marian
install-marian: install-prereq
	${MAKE} marian/build/marian
	${INSTALL_BIN} marian/build/marian ${PREFIX}/bin/marian
	${INSTALL_BIN} marian/build/marian-conv ${PREFIX}/bin/marian-conv
	${INSTALL_BIN} marian/build/marian-decoder ${PREFIX}/bin/marian-decoder
	${INSTALL_BIN} marian/build/marian-scorer ${PREFIX}/bin/marian-scorer
	${INSTALL_BIN} marian/build/marian-vocab ${PREFIX}/bin/marian-vocab
	${INSTALL_DATA} marian/build/libmarian.a ${PREFIX}/lib/libmarian.a

## fetch the source
marian:
	git clone https://github.com/marian-nmt/marian

## compile a static CPU-only version of marian-binaries
marian/build/marian: marian
	mkdir -p ${dir $@}
	cd ${dir $@} && cmake .. -DCMAKE_BUILD_TYPE=Release -DCOMPILE_CUDA=off -DUSE_STATIC_LIBS=on
	make -C ${dir $@} -j 2

.PHONY: clean
clean:
	rm -fr marian
