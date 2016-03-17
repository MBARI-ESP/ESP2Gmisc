# Makefile for snap -- 3/16/16 brent@mbari.org
CFLAGS=-Os

LTIBUSR=$(HOME)/ltib/rootfs/usr

all:	suscript arm/suscript ltib/suscript

suscript:	Makefile suscript.c
	$(CC) $(CFLAGS) suscript.c -o $@

ltib/suscript:  Makefile suscript.c
	mkdir -p ltib && \
        /ltibarm/bin/gcc $(CFLAGS) suscript.c -o $@

arm/suscript:  Makefile suscript.c
	mkdir -p arm && \
        /arm/bin/gcc $(CFLAGS) suscript.c -o $@

clean:
	rm -f *.o suscript arm/*.o arm/suscript ltib/*.o ltib/suscript
