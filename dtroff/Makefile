# Makefile for snap -- 3/15/16 brent@mbari.org
CFLAGS=-Os

LTIBUSR=$(HOME)/ltib/rootfs/usr

all:	dtroff arm/dtroff ltib/dtroff

dtroff:	Makefile dtroff.c
	$(CC) $(CFLAGS) dtroff.c -o $@

ltib/dtroff:  Makefile dtroff.c
	mkdir -p ltib && \
        /ltibarm/bin/gcc $(CFLAGS) dtroff.c -o $@

arm/dtroff:  Makefile dtroff.c
	mkdir -p arm && \
        /arm/bin/gcc $(CFLAGS) dtroff.c -o $@

clean:
	rm -f *.o dtroff arm/*.o arm/dtroff ltib/*.o ltib/dtroff
