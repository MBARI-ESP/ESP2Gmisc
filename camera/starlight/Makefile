# Makefile for snap -- 10/4/05 brent@mbari.org
CFLAGS=-O2

all:	snap arm/snap

snap:	Makefile snap.c devctl.c devctl.h ccd_msg.h types.h
	$(CC) $(CFLAGS) snap.c devctl.c -ltiff -lm -o snap

arm/snap:  Makefile snap.c devctl.c devctl.h ccd_msg.h types.h
	mkdir -p arm && \
        /arm/bin/gcc $(CFLAGS) snap.c devctl.c \
                -L/arm/usr/lib -ltiff -lz -lm -o arm/snap
	
clean:
	rm -f *.o snap arm/snap
