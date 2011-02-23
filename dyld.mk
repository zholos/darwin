VERSION_DYLD?=44

ENV=MACOSX_DEPLOYMENT_TARGET=10.4
CC=gcc-4.0
CXX=g++-4.0

all: dyld libdyldapis.a
install: install_libdyld install_dyld

# dyld

CFLAGS_DYLD=-Os -I./include -Wmost -Wno-four-char-constants -Wno-unknown-pragmas -mdynamic-no-pic
CXXFLAGS_DYLD=-fno-rtti
.if ${VERSION_DYLD} == 44
    LDFLAGS_DYLD=/usr/lib/gcc/i686-apple-darwin8/4.0.0/libstdc++.a
.else
    LDFLAGS_DYLD=-lstdc++-static
.endif
LDFLAGS_DYLD+= -seg1addr 8fe00000 -exported_symbols_list src/dyld.exp -nostdlib /usr/local/lib/system/libc.a -lgcc_eh -lgcc -Wl,-e,__dyld_start -Wl,-dylinker -Wl,-dylinker_install_name,/usr/lib/dyld

OBJ_DYLD=
.for i in dyldStartup.s stub_binding_helper.s
OBJ_DYLD+= ${i:R}.o
${i:R}.o: src/${i}
	${ENV} ${CC} ${CFLAGS_DYLD} -c $< -o $@
.endfor

.for i in dyldExceptions.c glue.c dyld_vers.c
OBJ_DYLD+= ${i:R}.o
${i:R}.o: src/${i}
	${ENV} ${CC} ${CFLAGS_DYLD} -c $< -o $@
.endfor

.for i in dyld_gdb.cpp dyld.cpp dyldAPIs.cpp dyldInitialization.cpp dyldNew.cpp ImageLoader.cpp ImageLoaderMachO.cpp
OBJ_DYLD+= ${i:R}.o
${i:R}.o: src/${i}
	${ENV} ${CXX} ${CFLAGS_DYLD} ${CXXFLAGS_DYLD} -c $< -o $@
.endfor

src/dyld_vers.c:
	echo 'const unsigned char dyldVersionString[] __attribute__ ((used)) = "@(#)PROGRAM:dyld PROJECT:dyld-${VERSION_DYLD} DEVELOPER:root BUILT" __DATE__ " " __TIME__ "\n";' > $@
	echo 'const double dyldVersionNumber __attribute__ ((used)) = (double)${VERSION_DYLD};' >> $@

dyld: ${OBJ_DYLD}
	${ENV} ${CXX} ${CFLAGS_DYLD} -o $@ $> ${LDFLAGS_DYLD} 
	strip -S $@

install_dyld: dyld
	install dyld /usr/lib/

# libdyld

CFLAGS_LIBDYLD=-Os -I./include -Wmost -Wno-four-char-constants -Wno-unknown-pragmas
CXXFLAGS_LIBDYLD=-fno-exceptions -fno-rtti

HDR_LIBDYLD=src/dyldLibSystemThreadHelpers.h include/mach-o/dyld_debug.h
OBJ_LIBDYLD=
.for i in dyld_debug.c
OBJ_LIBDYLD+= ${i:R}.o
${i:R}.o: src/${i} ${HDR_LIBDYLD}
	${ENV} ${CC} ${CFLAGS_LIBDYLD} -c $< -o $@
.endfor

.for i in dyldLock.cpp dyldAPIsInLibSystem.cpp 
OBJ_LIBDYLD+= ${i:R}.o
${i:R}.o: src/${i} ${HDR_LIBDYLD}
	${ENV} ${CXX} ${CFLAGS_LIBDYLD} ${CXXFLAGS_LIBDYLD} -c $< -o $@
.endfor

libdyldapis.a: ${OBJ_LIBDYLD}
	ar rcs $@ $>

install_libdyld: libdyldapis.a
	install -m 644 libdyldapis.a /usr/local/lib/system/
	install -m 644 include/dlfcn.h /usr/include/
	install -m 644 include/mach-o/dyld_debug.h include/mach-o/dyld.h /usr/include/mach-o/
	install -m 644 include/mach-o/dyld_gdb.h include/mach-o/dyld_priv.h /usr/local/include/mach-o/
	rm -f /usr/local/lib/system/libdyldapis_profile.a /usr/local/lib/system/libdyldapis_debug.a
	ln -s libdyldapis.a /usr/local/lib/system/libdyldapis_profile.a
	ln -s libdyldapis.a /usr/local/lib/system/libdyldapis_debug.a
