# Makefile for snap -- 10/27/10 brent@mbari.org
CFLAGS=-Os

all:	tiff2jpeg arm/tiff2jpeg

tiff2jpeg: Makefile tiff2jpeg.c
	$(CC) $(CFLAGS) tiff2jpeg.c -ltiff -ljpeg -o tiff2jpeg

arm/tiff2jpeg:  Makefile tiff2jpeg.c
	mkdir -p arm && \
	/arm/bin/gcc $(CFLAGS) tiff2jpeg.c -L/arm/usr/lib -o arm/tiff2jpeg \
	  -ltiff -ljpeg
	
clean:
	rm -f *.o tiff2jpeg arm/*.o arm/tiff2jpeg
