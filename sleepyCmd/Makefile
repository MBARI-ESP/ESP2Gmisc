# Makefile for snap -- 3/18/16 brent@mbari.org
CFLAGS=-Os

LTIBUSR=$(HOME)/ltib/rootfs/usr

all:	sleepyCmd arm/sleepyCmd ltib/sleepyCmd

sleepyCmd:	Makefile sleepyCmd.c
	$(CC) $(CFLAGS) sleepyCmd.c -o $@

ltib/sleepyCmd:  Makefile sleepyCmd.c
	mkdir -p ltib && \
        /ltibarm/bin/gcc $(CFLAGS) sleepyCmd.c -o $@

arm/sleepyCmd:  Makefile sleepyCmd.c
	mkdir -p arm && \
        /arm/bin/gcc $(CFLAGS) sleepyCmd.c -o $@

clean:
	rm -f *.o sleepyCmd arm/*.o arm/sleepyCmd ltib/*.o ltib/sleepyCmd
