# Makefile for snap -- 12/08/16 brent@mbari.org
CFLAGS=-Os

all:	tiff2jpeg arm/tiff2jpeg ltib/tiff2jpeg

tiff2jpeg: Makefile tiff2jpeg.c
	$(CC) $(CFLAGS) tiff2jpeg.c -ltiff -ljpeg -o tiff2jpeg

arm/tiff2jpeg:  Makefile tiff2jpeg.c
	mkdir -p arm && \
	/arm/bin/gcc $(CFLAGS) tiff2jpeg.c -L/arm/usr/lib -o arm/tiff2jpeg \
	  -ltiff -ljpeg

ltib/tiff2jpeg:  Makefile tiff2jpeg.c
	mkdir -p ltib && \
	/ltibarm/bin/gcc $(CFLAGS) tiff2jpeg.c -I ~/ltib/rootfs/usr/include \
        -L ~/ltib/rootfs/usr/lib -o ltib/tiff2jpeg -ltiff -ljpeg -lz

clean:
	rm -f *.o tiff2jpeg arm/*.o arm/tiff2jpeg ltib/tiff2jpeg
