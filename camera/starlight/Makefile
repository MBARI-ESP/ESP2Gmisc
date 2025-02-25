# Makefile for snap -- 2/25/25 brent@mbari.org
CFLAGS=-O2

LTIBUSR=$(HOME)/ltib/rootfs/usr

all:	snap ltib/snap
#ltib/snap

snap:	Makefile snap.c devctl.c devctl.h ccd_msg.h types.h
	$(CC) $(CFLAGS) snap.c devctl.c -ltiff -lpng16 -ljpeg -lm -o $@

ltib/snap:  Makefile snap.c devctl.c devctl.h ccd_msg.h types.h
	mkdir -p ltib && \
        /ltibarm/bin/gcc $(CFLAGS) snap.c devctl.c \
         -I$(LTIBUSR)/include -L$(LTIBUSR)/lib \
		-ltiff -lpng16 -lz -o $@

arm/snap:  Makefile snap.c devctl.c devctl.h ccd_msg.h types.h
	mkdir -p arm && \
        /arm/bin/gcc $(CFLAGS) snap.c devctl.c \
                -L/arm/usr/lib -ltiff -lz -lm -o $@

clean:
	rm -f *.o snap arm/*.o arm/snap ltib/*.o ltib/snap
