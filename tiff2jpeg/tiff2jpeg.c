/*
  Sample code uses JPEG and TIFF library.
  This program reads a tiff image, processes it and output to a jpeg image.
  It is tested on Linux 2.4.
  To compile: gcc -o tiff2jpeg tiff2jpeg.c -ljpeg -ltiff -lm
  
  JPEG library can be obtained from http://www.ijg.org
  TIFF library can be obtained from http://www.libtiff.org
  
  10/28/10 brent@mbari.org  -- added software binning to produce a thumbnail
  
*/

#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>
#include "tiffio.h"
#include "jpeglib.h"
#include <getopt.h>   //for getopt_long()
#include <libgen.h>
#include <limits.h>
#include <stdarg.h>

#define validCoord(top) ((top)>=0)
#define validBin(b)     ((b) >= 1)
#define maxBinArea      USHRT_MAX

static char *progName;
static size_t binX = 1, binY = 1, quality = 70;
static size_t originX = 0, originY = 0;
static size_t extentX = 0, extentY = 0;

static void usage (void)
{
  printf ("%s revised 11/4/10 brent@mbari.org\n"
"Convert TIFF image to JPEG format, with optional binning and cropping.\n"
"Usage:\n"
"  %s {options} <source TIFF file> <destination JPEG file>\n"
"options:  (may be abbriviated)\n"
"  -binning=x{,y}       #x,y binning factors (default 1x1)\n"
"  -origin=x{,y}        #location of top left corner on input tiff\n"
"  -size=width{,height} #width (and height) of input tiff\n"
"  -quality=0..100      #jpeg quality percentage (default 70%%)\n"
"examples:\n"
"  %s srcimage.tiff dstimage.jpeg #convert src to dstimage w/o binning\n"
"  %s -bin 2x3 bigimage.tiff smallimage.jpeg #convert with 2x3 binning\n"
"  %s -b 2 bigimage.tiff smallimage.jpeg #as above with 2x2 binning\n"
"  %s -origin=100,150 big.tiff cropped.jpeg  #crop upper left\n"
"  %s -size=300 big.tiff box.jpeg    #convert just a 300x300 region\n",
  progName, progName, progName, progName, progName, progName, progName);
}


static void syntaxErr (char *format, ...)
{
  va_list ap;
  if (format) {
    va_start (ap, format);
    vfprintf (stderr, format, ap);
    va_end (ap);
    fputc('\n', stderr);
  }
  fprintf (stderr, "Try running '%s -help'\n", progName);
  exit(3);
}


static char *parseInt (char *cursor, int *integer)
// parse an integer at cursor
// returns pointer to next char
//  abort with a syntaxErr if no valid text found
{
  char *end;
  long result;
  errno = 0;
  result = strtol(cursor, &end, 10);
  if (errno || end==cursor || *end=='.' || result < INT_MIN || result > INT_MAX)
    syntaxErr("\"%s\" is not a valid integer", cursor);
  *integer = result;
  return end;
}

static char *parseXYoptArg (int *x, int * y)
// parse one or two integers separated by non numeric seperators
// returns pointer to next char
//  abort with a syntaxErr if no valid text found
{
  char *end = parseInt (optarg, x);
  while (*end != '-' && *end != '+' && *end != '.' &&
         (*end < '0' || *end > '9')) {
    if (!*end) {
      *y = *x;  //only one of two specifed implies x==y
      return end;
    }
    end++;
  }
  end = parseInt (end, y);
  while (*end && *end <= ' ') end++;
  return end;
}



unsigned char **cpicalloc(int row, int col) 
{
  int i;
  unsigned char **p;
  
  p = (unsigned char **) calloc(row,sizeof(unsigned char *));
  if(!p){
    fprintf(stderr,"memory allocation error\n");
    exit(1);
  }
  for(i=0;i<row;i++){
    p[i] = (unsigned char *) calloc(col,sizeof(unsigned char));
    if(!p[i]){
      fprintf(stderr,"memory allocation error\n");
      exit(1);
    }
  }
  return p;
}


//return average of packed RGBA pixels at origin
__inline uint32 
 binRGBA (uint32 *origin, 
          size_t width, size_t height, size_t stride, size_t area)
{
  uint32 r=0, g=0, b=0, a=0;
  do {
    uint32 *cursor = origin;
    size_t x = width;
    do {
      uint32 p=*cursor++;
      r += p & 0xff;
      g += (p>>8) & 0xff;
      b += (p>>16) & 0xff;
      a += p>>24;
    } while (--x);
    origin += stride;
  } while (--height);
  return r/area | (g/area)<<8 | (b/area)<<16 | (a/area)<<24;
}


int main(int argc, char * const argv[])
{
  TIFF *tiffin;
  FILE *jpegout;
  char const *tiffFn, *jpegFn;
  size_t binArea;

  const static struct option options[] = {
    {"binning", 1, NULL, 'b'},
    {"origin", 1, NULL, 'o'},
    {"size", 1, NULL, 'e'},
    {"extent", 1, NULL, 'e'},
    {"quality", 1, NULL, 'q'},
    {"help", 0, NULL, 'h'},
    {NULL}
  };
    
  progName = basename (argv[0]);
  for (;;) {
    int optc = getopt_long_only (argc, argv, "", options, 0);
    char *excess;
    switch (optc) {
      case -1:
        goto gotAllOpts;
      case 'b':  //XY binning
        excess = parseXYoptArg(&binX, &binY);
        if (*excess)
          syntaxErr("Extra \"%s\" after binning factors", excess);
        if (!validBin(binX) || !validBin(binY))
          syntaxErr ("Invalid binning factor");
        break;
      case 'o':  //location of upper left corner
        excess = parseXYoptArg(&originX, &originY);
        if (*excess)
          syntaxErr("Extra \"%s\" after origin", excess);
        if (!validCoord(originX) || !validCoord(originY))
          syntaxErr ("Invalid image origin");
        break;
      case 'e':  //size (extent) of input image
        excess = parseXYoptArg(&extentX, &extentY);
        if (*excess)
          syntaxErr("Extra \"%s\" after size", excess);
        if (!validCoord(extentX) || !validCoord(extentY))
          syntaxErr ("Invalid image size");
        break;
      case 'q':  //jpeg output "quality" factor in %
        parseInt(optarg, &quality);
        break;
      case 'h':
        usage();
        return 0;
      default:
        syntaxErr(NULL);
    }
  }
gotAllOpts:
  binArea = binX*binY;
  if (binArea > maxBinArea)
    syntaxErr("%ux%u binning rectangle contains more than %u pixels!",
               binX, binY, maxBinArea);
  if (!(tiffFn = argv[optind]))
    syntaxErr("Missing TIFF source image file name");
  if (!(jpegFn = argv[optind+1]))
    syntaxErr("Missing JPEG destination image file name");

  if((tiffin = TIFFOpen(tiffFn,"r")) == NULL){
    exit(1);
  }
  if((jpegout = fopen(jpegFn, "wb")) == NULL){
    fprintf(stderr, "cannot open %s\n", jpegFn);
    exit(1);
  }
  
  {
    size_t width, height, outWidth, outHeight, outLnBytes, npixels, lineStride;
    uint32 *raster, *rasterLine;
    unsigned char **pic, **picLine;

    TIFFGetField(tiffin, TIFFTAG_IMAGEWIDTH, &width);
    TIFFGetField(tiffin, TIFFTAG_IMAGELENGTH, &height);
    npixels = width*height;
    rasterLine = raster = (uint32*) _TIFFmalloc(npixels*sizeof(uint32));
    if (!raster)
      return 2;
    if(!TIFFReadRGBAImage(tiffin, width, height, raster, 0)) 
      return 3;

    //abort if origin is outside image
    if (originX >= width || originY >= height) {
      fprintf(stderr, "Specified origin is outside raster!\n");
      exit(2);
    }
    rasterLine += width*originY + originX;
    
    //crop if extent extends outside image
    if (!extentX)
      extentX = width - originX;
    else if (originX+extentX > width) {
      fprintf(stderr, "Warning:  JPEG image will be narrower than specified\n");
      extentX = width - originX;
    }
    if (!extentY)
      extentY = height - originY;
    else if (originY+extentY > height) {
      fprintf(stderr, "Warning:  JPEG image will be shorter than specified\n");
      extentY = height - originY;
    }

    outWidth = extentX / binX;
    outHeight = extentY / binY;
    lineStride = binY*width;
    outLnBytes = outWidth * 3;
    pic = cpicalloc(outHeight, outLnBytes);
    picLine = pic+outHeight;
    {
      while (picLine > pic) {
        unsigned char *rgb = *--picLine;
        unsigned char *rgbEnd = rgb + outLnBytes;
        uint32 *nextLine = rasterLine+lineStride;
        while (rgb < rgbEnd) {
          uint32 pixel = binRGBA(rasterLine, binX, binY, width, binArea);
          rasterLine += binX;
	  *rgb++ = TIFFGetR(pixel);
	  *rgb++ = TIFFGetG(pixel);
	  *rgb++ = TIFFGetB(pixel);
        }
        rasterLine = nextLine;
      }
    }
    _TIFFfree(raster);
    TIFFClose(tiffin);

    {
      struct jpeg_compress_struct cinfo;
      struct jpeg_error_mgr jerr;

      JSAMPROW row_pointer[1];
      cinfo.err = jpeg_std_error(&jerr);
      jpeg_create_compress(&cinfo);
      jpeg_stdio_dest(&cinfo, jpegout);

      cinfo.image_width = outWidth;
      cinfo.image_height = outHeight;
      cinfo.input_components = 3;
      cinfo.in_color_space = JCS_RGB;
      jpeg_set_defaults(&cinfo);

      jpeg_set_quality(&cinfo, quality, TRUE);
      jpeg_start_compress(&cinfo, TRUE);
      jpeg_write_scanlines(&cinfo, pic, outHeight);
      jpeg_finish_compress(&cinfo);
      fclose(jpegout);
      jpeg_destroy_compress(&cinfo);
    }
  }
}
