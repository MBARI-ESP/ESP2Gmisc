# Makefile for snap -- 4/30/16 brent@mbari.org
CFLAGS=-g -Os

LTIBUSR=$(HOME)/ltib/rootfs/usr

all:	holdopen arm/holdopen ltib/holdopen

holdopen:	Makefile holdopen.c
	$(CC) $(CFLAGS) holdopen.c -o $@

ltib/holdopen:  Makefile holdopen.c
	mkdir -p ltib && \
        /ltibarm/bin/gcc $(CFLAGS) holdopen.c -o $@

arm/holdopen:  Makefile holdopen.c
	mkdir -p arm && \
        /arm/bin/gcc $(CFLAGS) holdopen.c -o $@

clean:
	rm -f *.o holdopen arm/*.o arm/holdopen ltib/*.o ltib/holdopen
