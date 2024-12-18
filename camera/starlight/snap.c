/***************  snap.c -- brent@mbari.org  **********************
*    Copyright(C) 2024 MBARI
*    MBARI Proprietary Information. All rights reserved.
*
* Starlight SXV-H9 camera command line processor
******************************************************************/

#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <stddef.h>
#include <unistd.h>
#include <malloc.h>
#include <stdlib.h>
#include <getopt.h>   //for getopt_long()
#include <libgen.h>
#include <limits.h>
#include <stdarg.h>
#include <ctype.h>
#include <time.h>

#include <tiff.h>
#include <tiffio.h>
#include <png.h>
#include <zlib.h>

#include "devctl.h"   //low-level camera device control
#include "types.h"

#define validBin(b) (b >= 1 && b <= 4)
#define REMAINING " seconds remaining"
#define NO_PREDICTOR 1

//tweaks for optimizeExposure
//  one day, this should be made into a settable parameter...
#define minSignal (adcBias+3000)   //minimum signal for scaling exposure times

static char *progName;
static int progressFD = 3;

static int CCDdepth = 0;
static int binX = 1, binY = 1;
static int offsetX = 0, offsetY = 0;
static int sizeX = 0, sizeY = 0;
static double exposureSecs = 0.0;  //negative --> autoexposure time limit
static unsigned maxAutoSignal = 50000;
static unsigned adcBias = 2000;    //minimum possible ADC counts/pixel
static char debug = 0;
static int PNGcompressLevel = -1;

static enum {  //supported output file types
  unspecifiedFile, TIFFfile, FITSfile, JPEGfile, PNGfile,
} outputFileType = unspecifiedFile;

static const char *fileTypeName[] = {
  "unspecified", "TIFF", "FITS", "JPEG", "PNG"
};


typedef struct {
	unsigned minimum, maximum, average, filteredMax;  // pixel values
		} imageStats;	// basic image statistics for autoexposure

typedef int writeLineFn(void *file, struct CCDexp *exposure, u16 *lineBuffer);


//note that options commented out in usage don't seem to work for SXV-H9 camera
static void usage(void)
{
  printf("%s revised 12/10/24 brent@mbari.org\n", progName);
  printf(
"Snap a photo from a monochrome Starlight Xpress CCD camera. Usage:\n"
"  %s {options} <exposure seconds> <output file>\n"
"seconds may be specified in floating point for millisecond resolution\n"
"options: (may be abbriviated)\n"
"  -autoexpose{=300,50000,2000}  #auto exposure with optional max duration\n"
"                       #in seconds and brightest,dimmest pixels in counts\n"
"  -binning=x{,y}    #x,y binning factors\n"
"  -offset=x{,y}     #origin offset\n"
"  -origin=x{,y}     #same as -offset=\n"
"  -size=x{,y}       #size of the image(width x height)\n"
"  -camera=deviceFn  #use specified device rather than /dev/ccda\n"
"  -tiff{=deflate}   #output TIFF file with optional deflate compression\n"
"  -fits             #output FITS file(image rotated 180 degrees wrt TIFF)\n"
//"  -jpeg             #output JPEG file\n"
"  -png{=6}          #output Portable Network Graphics file w/compression level\n"
"  -debug{=2}        #display debugging info with optional debugging level\n"
"  -help             #displays this\n"
//"  -dark           #do not open shutter\n"
//"  -depth=n        #number of bits per pixel\n"
//"  -nowipe         #do not wipe frame\n"
//"  -noclear        #do not clear frame\n"
//"  -noaccumulation #do not accumulate charge when binning\n"
//"  -tdi            #time delay and integrate\n"
"examples:\n"
"  %s 1.5 myimage.png  #1.5 second exposure to myimage.png w/o binning\n"
"  %s -bin 2x3 .005 myimage.png  #5 msec exposure with 2x3 binning\n"
"notes:\n"
"  If possible, progress messages are output to file descriptor 3\n"
"  Otherwise, they are sent to stdout.\n",
  progName, progName, progName);
}


static void syntaxErr(char *format, ...)
{
  va_list ap;
  va_start(ap, format);
  vfprintf(stderr, format, ap);
  va_end(ap);
  fprintf(stderr, "\nTry running '%s -help'\n", progName);
  exit(3);
}


static int progress(char *format, ...)
{
  char buffer[2000];
  va_list ap;
  size_t bytesWritten;
  va_start(ap, format);
  vsnprintf(buffer, sizeof(buffer), format, ap);
  va_end(ap);
  bytesWritten = write(progressFD, buffer, strlen(buffer));
  fsync(progressFD);
  return bytesWritten;
}


static char *parseInt(char *cursor, int *integer)
// parse an integer at cursor
// returns pointer to next char
//  abort with a syntaxErr if no valid text found
{
  char *end;
  long result;
  errno = 0;
  result = strtol(cursor, &end, 0);
  if(errno || end==cursor || result < INT_MIN || result > INT_MAX)
    syntaxErr("\"%s\" is not a valid integer", cursor);
  *integer = result;
  return end;
}


static char *parseXYoptArg(int *x, int * y)
// parse one or two integers separated by a comma
// returns pointer to next char
//  abort with a syntaxErr if no valid text found
{
  char *end = parseInt(optarg, x);
  while(*end != '-' && *end != '+' && *end != '.' &&
        (*end < '0' || *end > '9')) {
    if(!*end) {
      *y = *x;  //only one of two specifed implies x==y
      return end;
    }
    end++;
  }
  return parseInt(end, y);
}


static char *parseDouble(char *cursor, double *f)
// parse a floating point(double precision) number at cursor
// returns pointer to next char
//  abort with a syntaxErr if no valid text found
{
  char *end;
  double result;
  errno = 0;
  result = strtod(cursor, &end);  //glibc strtof() appears to be broken!
  if(errno || end==cursor)
    syntaxErr("\"%s\" is not a valid floating point value", cursor);
  *f = result;
  return end;
}


static char *parseDuration(char *cursor, double *secs)
{
  char *terminator = parseDouble(cursor, secs);
  if(*secs >(double)INT_MAX/1000.0)
    syntaxErr("Exposure duration(%g) is too long!", *secs);
  return terminator;
}


static void
showStats(imageStats *pixel)
{
  if(debug)
    printf("( %u Min / %u Avg / %u Max / %u FilteredMax ) A/D counts\n",
        pixel->minimum,pixel->average,pixel->maximum,pixel->filteredMax);
}


static
int dummyWrite(void *ignored, struct CCDexp *exposure, u16 *lineBuffer)
{
  return 0;
}


static int
readOutImage(struct CCDexp *exposure, writeLineFn *writeLine,
              void *fileDescriptor, imageStats *stats)
/*
  Read out an image from the CCD and produce image stats
  assumes 16-bit pixels for now
*/
{
  unsigned width = exposure->width / exposure->xbin;
  unsigned height = exposure->height / exposure->ybin;
//  unsigned pixelBytes  =((exposure->dacBits + 7) / 8);
  u32 avgPixel = 0;
  u16 maxPixel = 0;
  u16 maxFiltered = 0;
  u16 minPixel = -1;
  unsigned row;
  int result = 0;
  u16 *end, *cursor;
  u16 *line, *line0 = malloc(exposure->rowBytes+2);
  if(!line0) {
    fprintf(stderr, "No memory for row buffer!\n");
    return -2;
  }
  line = line0+1;  //precharge line array with state info for filter
  end = line+width;
  *line0 = *end = 0;  //clear pad pixels

  while((result = CCDloadFrame(exposure, line)) > 0) {
    u32 sum = 0;
    if(result == 1) {
      progress("\r  0%% Uploaded        ");
    }else if(!(result & 127)) {
      progress("\r%3d%%", result*100 / height);
    }
    for(cursor=line; cursor<end; cursor++) {
      u16 pixel = *cursor;
      sum+=pixel;
      if(pixel < minPixel) minPixel=pixel;
      if(pixel > maxFiltered) {  //look left and right to filter out hotspots
	    if(!(pixel > cursor[-1] && pixel > cursor[1])) maxFiltered=pixel;
	if(pixel > maxPixel) maxPixel=pixel;
      }
    }
    avgPixel += sum / width;
    if(writeLine(fileDescriptor, exposure, line)) {result=-1; break;}
  }
  progress("\r");
  avgPixel /= height;
  free(line0);
  if(stats) {
    stats->minimum = minPixel;
    stats->maximum = maxPixel;
    stats->average = avgPixel;
    stats->filteredMax = maxFiltered;
    showStats(stats);
  }
  return result;
}


static void
expose(struct CCDexp *exposure)
{
  time_t snapEndTime, secsLeft = exposure->msec / 1000;
  CCDexposeFrame(exposure);
  snapEndTime =(exposure->start = time(NULL)) + secsLeft;
  if(secsLeft > 1) {  //output exposure progress messages
    int digits = progress("%d" REMAINING, secsLeft) -(sizeof(REMAINING)-1);
    sleep(1);
    while((secsLeft = snapEndTime - time(NULL)) > 1) {
      progress("\r%*d ", digits, secsLeft);
      sleep(1);
    }
    progress("\r");
  }
}


static int
optimizeExposure(struct CCDexp *exposure)
/*
calculate optimized exposure time in milliseconds
limit exposure time to exposure->msec
stores optimal exposure time in exposure->msec
returns 0 if successful

Theory:
Take a short exposure with the coarsest binning.
Optimum Exposure time is determined
by the brightest pixel in this coarse image.  Scale exposure time so that this
"bright" pixel reads approximately max A/D counts.
*/
{
  const unsigned binArea = exposure->xbin * exposure->ybin;
  const double binAreaf = binArea;
  unsigned maxSignalTarget =  maxAutoSignal;
  struct CCDexp testExposure = *exposure;
//comment out next line if overexposing hires scenes containing points of light
  testExposure.xbin = testExposure.ybin = 4;
  testExposure.msec /= 128;  //((4*4)*16)/binArea;  //better, but takes too long
  int tries = 20;

 retry:
  if(--tries < 0) {
    fprintf(stderr,
        "Error:  Scene brightness changing too rapidly\n");
    return 1;
  }
  {
    imageStats lightStats;
    unsigned testArea = testExposure.xbin * testExposure.ybin;

    if(!testExposure.msec) testExposure.msec=1;
    expose(&testExposure);
    if(readOutImage(&testExposure, dummyWrite, NULL, &lightStats)) return -1;

    if(lightStats.filteredMax <= 50000) {
        //subtract A/D analog bias estimate from brightest spot
      double exposureScaleFactor = testArea / binAreaf;
      unsigned testms;
      unsigned brightPt = lightStats.filteredMax;
      if(brightPt < minSignal) { //not enough signal
        exposureScaleFactor *= 20;
      }else{
        exposureScaleFactor *=
             (double)maxSignalTarget /(double)(brightPt-adcBias);
      }
      testms = testExposure.msec * exposureScaleFactor;
      if(testms > exposure->msec) {
	fprintf(stderr,
          "WARNING:  Too Dark -- required %gs exposure > %gs time limit\n",
				testms/1000.0, exposure->msec/1000.0);
	 return 0;
      }
      if(brightPt < minSignal) { //not enough signal
        testExposure.msec *= 10;
        goto retry;
      }
      if(!testms) testms=1;
      exposure->msec = testms;

    }else{  //overexposed!

      if(testExposure.msec > 1) { // 1st try short test exposure
	testExposure.msec /= 16;
	goto retry;
      }
      if(testExposure.xbin != exposure->xbin ||
          testExposure.ybin != exposure->ybin) {
        testExposure.xbin = exposure->xbin;
        testExposure.ybin = exposure->ybin;
	 //then try using the desired binning mode...
	goto retry;	// as a last resort
      }
      fprintf(stderr,
          "WARNING:  Too Bright -- required exposure time < 1ms\n");
      exposure->msec = 1;
    }
  }
  return 0;
}


/*
 * FITS file routines.
 */
#define FITS_CARD_COUNT     36
#define FITS_CARD_SIZE      80
#define FITS_RECORD_SIZE   (FITS_CARD_COUNT*FITS_CARD_SIZE)
/*
 * Convert unsigned LE pixels to BE pixels and reverse order
 */

#define swab2(word16) (((word16) >> 8) |((word16) << 8) )

#define swab4(word32) (((word32) >> 24) |((word32) << 24) | \
         (((word32) & 0x00FF0000) >> 8) |(((word32) & 0x0000FF00) << 8) )

static void convert_pixels(unsigned char *src, int pixel_size, int count)
{
    switch(pixel_size)
    {
        case 1:
            {
              unsigned char *end = src + count - 1;
              while(src < end) {
                unsigned char b = *src; *src++ = *end; *end-- = b;
              }
            }
            break;
        case 2:
            {
              unsigned short *start =(unsigned short *) src;
              unsigned short *end = start + count - 1;
              while(start <= end) {
                unsigned short startPixel = *start;
                unsigned short endPixel = *end;
                *end-- = swab2(startPixel);
                *start++ = swab2(endPixel);
              }
            }
            break;
        case 4:
            {
              unsigned long *start =(unsigned long *) src;
              unsigned long *end = start + count - 1;
              while(start <= end) {
                unsigned long startPixel = *start;
                unsigned long endPixel = *end;
                *end-- = swab4(startPixel);
                *start++ = swab4(endPixel);
              }
            }
            break;
    }
}


int writeFITSline(void *fd, struct CCDexp *exposure, u16 *lineBuffer)
{
  convert_pixels((unsigned char *)lineBuffer, 2, exposure->rowBytes/2);
  return write((ssize_t)fd,lineBuffer, exposure->rowBytes)!=exposure->rowBytes;
}

/*
 * Save image to FITS file.
 */
static int saveFITS(int fd, struct CCDexp *exposure)
{
    char           record[FITS_CARD_COUNT][FITS_CARD_SIZE];
    int            i, k, result, pixelBytes;
    unsigned cols = exposure->width / exposure->xbin;
    unsigned rows = exposure->height / exposure->ybin;
    imageStats stats;
    char *timeString = ctime(&exposure->start);
    timeString[strlen(timeString)-1] = '\0';  //remove trailing newline

    /*
     * Fill header records.
     */
    memset(record, ' ', FITS_RECORD_SIZE);
    i = 0;
    sprintf(record[i++], "SIMPLE  = %20c", 'T');
    sprintf(record[i++], "BITPIX  = %20d", exposure->dacBits);
    sprintf(record[i++], "NAXIS   = %20d", 2);
    sprintf(record[i++], "NAXIS1  = %20d",  cols);
    sprintf(record[i++], "NAXIS2  = %20d",  rows);
    sprintf(record[i++], "BZERO   = %20f", 0.0);
    sprintf(record[i++], "BSCALE  = %20f", 1.0);
    sprintf(record[i++], "DATAMIN = %20u", 0);
    sprintf(record[i++], "DATAMAX = %20u",(1<<exposure->dacBits)-1);
    sprintf(record[i++], "XPIXSZ  = %20f", exposure->ccd->pixel_width*exposure->xbin);
    sprintf(record[i++], "YPIXSZ  = %20f", exposure->ccd->pixel_height*exposure->ybin);
    sprintf(record[i++], "DATE-OBS= '%s'", timeString);
    sprintf(record[i++], "EXPOSURE= %20f",(double)exposure->msec / 1000.0);

    //TODO: insert environment strings here...

    sprintf(record[i++], "END");
    for(k = 0; k < FITS_RECORD_SIZE; k++)
        if(((char *)record)[k] == '\0')
           ((char *)record)[k] = ' ';
    if(write(fd, record, FITS_RECORD_SIZE) != FITS_RECORD_SIZE)
      return -1;

    /*
     * Convert and write image data.
     */
    if(readOutImage(exposure, writeFITSline,(void *)(ssize_t)fd, &stats))
      return -1;
    /*
     * Pad remaining record size with zeros and close.
     */
    {
      size_t image_size = exposure->rowBytes*rows;
      size_t shortLen = image_size % FITS_RECORD_SIZE;
      if(shortLen) {
        size_t padBytes = FITS_RECORD_SIZE - shortLen;
        memset(record, 0, padBytes);
        if(write(fd, record, padBytes) != padBytes)
          return -1;
      }
    }
    return close(fd);
}


//  TIFF file routines

int setTiff(TIFF* tif, ttag_t tag, ...)
/*
  Convenient function to set a TIFF tag.
  Calls TIFFVSetField
*/
{
    va_list ap;
    int ok;
    va_start (ap, tag);
    ok = TIFFVSetField(tif, tag, ap);
    va_end(ap);
    if(!ok)
      fprintf(stderr, "Error while setting TIFF tag #%d\n", tag);
    return ok;
}


static int
setTiffDate(TIFF* tif)
/*
	write the 20 character TIFF DateTime tag
*/
{
	char buffer[20];
	time_t	now;
	struct tm date;
	time(&now);
	gmtime_r(&now, &date);
	strftime(buffer, sizeof(buffer), "%Y:%m:%d %H:%M:%S", &date);
	return setTiff(tif, TIFFTAG_DATETIME, buffer);
}


int writeTIFFline(void *tif, struct CCDexp *exposure, u16 *lineBuffer)
{
  return TIFFWriteScanline((TIFF *)tif, lineBuffer, exposure->readRow-1, 0) != 1;
}

static void describeImage(struct CCDexp *exposure,
  char *cursor, size_t bufSize, const char *comment)
{
  char binning[30] = "";
  if(exposure->xbin * exposure->ybin != 1)
    sprintf(binning, " with %dx%d binning", exposure->xbin, exposure->ybin);

  if(comment && bufSize > 200) {
    size_t len = strlen(comment);
    if(len > bufSize-200)
      len=bufSize-200;
    memcpy(cursor, comment, len);
    cursor += len;
    *cursor++ = ' ';
  }
  sprintf(cursor, "exposed %g seconds%s",
                     (double)exposure->msec/1000.0, binning);
}

/*
 * Save image to TIFF file.
 */
static int saveTIFF(TIFF *tif, struct CCDexp *exposure)
{
  imageStats stats;
  char *artist = getenv("TIFF_ARTIST");
  char *host = getenv("TIFF_HOST");
  char *soft = getenv("TIFF_SOFTWARE");
  char *make = getenv("TIFF_MAKE");
  char *compressString = getenv("TIFF_COMPRESSION");
  char *predictString = getenv("TIFF_PREDICTOR");
  char *orientString = getenv("TIFF_ORIENTATION");
  char *comment = getenv("TIFF_COMMENT");
  int compress = compressString ? atoi(compressString) : 0;
  int predict = predictString ? atoi(predictString) : 0;
  int orientation = orientString ? atoi(orientString) : 0;

  setTiff(tif, TIFFTAG_MODEL, exposure->ccd->camera);
  setTiffDate(tif);
  if(make) setTiff(tif, TIFFTAG_MAKE, make);
  if(artist) setTiff(tif, TIFFTAG_ARTIST, artist);
  if(host) setTiff(tif, TIFFTAG_HOSTCOMPUTER, host);
  if(soft) setTiff(tif, TIFFTAG_SOFTWARE, soft);
  if(compress) setTiff(tif, TIFFTAG_COMPRESSION, compress);
  if(predict) setTiff(tif, TIFFTAG_PREDICTOR, predict);
  if(orientation) setTiff(tif, TIFFTAG_ORIENTATION, orientation);
  {
    unsigned width = exposure->width / exposure->xbin;
    unsigned height = exposure->height / exposure->ybin;
      //shoot for 64KByte TIFF image strips
    unsigned strips = width*height*sizeof(u16) / 65536;
    unsigned stripRows;
    if(!strips) strips = 1;
    stripRows = height / strips;
    if(!stripRows) stripRows = 1;
    if(debug>1)
      printf("(%dx%d) TIFF image in %u strips with %u rows/strip\n",
			        width, height, strips, stripRows);
    setTiff(tif, TIFFTAG_PLANARCONFIG, PLANARCONFIG_CONTIG);
    setTiff(tif, TIFFTAG_SAMPLESPERPIXEL, 1);
    setTiff(tif, TIFFTAG_BITSPERSAMPLE, 16);
//tried to fix this, but most image readers don't respect orientation
//    setTiff(tif, TIFFTAG_ORIENTATION, ORIENTATION_BOTLEFT); //to match .fits!
    setTiff(tif, TIFFTAG_PHOTOMETRIC, PHOTOMETRIC_MINISBLACK);
    setTiff(tif, TIFFTAG_IMAGEWIDTH, width);
    setTiff(tif, TIFFTAG_ROWSPERSTRIP, stripRows);
  }
  if(readOutImage(exposure, writeTIFFline, tif, &stats)) return -1;
  char description[2000];
  describeImage(exposure, description, sizeof(description), comment);
  setTiff(tif, TIFFTAG_IMAGEDESCRIPTION, description);
  return 0;
}

/*
 * set PNG text chunks for each env var key that starts with given prefix string
 */
static
  void setPNGtext(png_structp png, png_infop info, png_text *one,
                  const char *prefix)
{
  extern const char **environ;
  size_t prefixLen = strlen(prefix);
  const char **nextEnv = environ;
  while (*nextEnv) {
    if (!strncmp(prefix, *nextEnv, prefixLen)) {
      const char *key = *nextEnv + prefixLen;
      const char *envTxt = strchr(key, '=');
      if (envTxt) {
        size_t keyLen = envTxt - key;
        char keyBuf[80];
        if (keyLen >= sizeof(keyBuf))
          keyLen = sizeof(keyBuf)-1;
        memcpy(keyBuf, key, keyLen);
        keyBuf[keyLen]='\0';
        one->key = keyBuf;
        one->text = (char *)envTxt+1;
//fprintf(stderr, "%s=%s\n", one->key, one->text);
        png_set_text(png, info, one, 1);
      }
    }
    nextEnv++;
  }
}

int writePNGline(void *pngPtr, struct CCDexp *exposure, u16 *lineBuffer)
{
  png_write_row((png_structp)pngPtr, (png_const_bytep)lineBuffer);
  return 0;
}

/*
 * Save image to PNG file.
 */
static int savePNG(FILE *outFile, struct CCDexp *exposure)
{
  imageStats stats;
  png_structp png = png_create_write_struct(PNG_LIBPNG_VER_STRING,
    NULL, NULL, NULL);
  png_infop info = png_create_info_struct(png);
  if (!png || !info) {
    fprintf(stderr, "Failed to create libpng structures\n");
    exit(67);
  }
  if (setjmp(png_jmpbuf(png))) { //exit after reporting any libpng error
      exit(66);
  }
  png_init_io(png, outFile);
  unsigned width = exposure->width / exposure->xbin;
  unsigned height = exposure->height / exposure->ybin;
  png_set_IHDR(png, info, width, height, 16,
    PNG_COLOR_TYPE_GRAY, PNG_INTERLACE_NONE,
    PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);
  if (PNGcompressLevel >= 0)
    png_set_compression_level(png, PNGcompressLevel);

  png_time creationTime;
  png_convert_from_time_t(&creationTime, time(NULL));
  png_set_tIME(png, info, &creationTime);
  png_text one = {.compression = PNG_TEXT_COMPRESSION_NONE,
    .lang = NULL, .lang_key = NULL, .itxt_length = 0};
  char timeBuf[29];
  png_convert_to_rfc1123_buffer(timeBuf, &creationTime);
  one.key = "Creation Time";
  one.text = timeBuf;
  png_set_text(png, info, &one, 1);

  char comment[190];
  describeImage(exposure, comment, sizeof(comment), NULL);
  one.key = "Comment";
  one.text = comment;
  png_set_text(png, info, &one, 1);

  setPNGtext(png, info, &one, "PNG_");

  png_write_info(png, info);
  png_set_swap(png);
  if(readOutImage(exposure, writePNGline, png, &stats)) return -1;

  png_write_end(png, info);
  png_destroy_write_struct(&png, &info);
  return 0;
}


void assignType(int fileType)
{
  if(outputFileType != unspecifiedFile)
    syntaxErr("Redundant ouput file type specification!");
  outputFileType = fileType;
}


void imageWrtFailed(void)
{
   fprintf(stderr, "\n%s image write failed!\n", fileTypeName[outputFileType]);
   exit(2);
}


int main(int argc, char **argv)
{
  struct CCDdev device = {"/dev/ccda"};
  struct CCDexp exposure = {&device};
  unsigned short *pixelRow, *end;
  int overage;
  unsigned avgPixel = 0;
  char *outFn;
  FILE *outFile;

  const static struct option options[] = {
    {"autoexpose", 2, NULL, 'a'},
    {"binning", 1, NULL, 'b'},
    {"bin", 1, NULL, 'b'},
    {"offset", 1, NULL, 'o'},
    {"origin", 1, NULL, 'o'},
    {"size", 1, NULL, 's'},
    {"dark", 0, NULL, 'D'},
//    {"depth", 1, NULL, 'd'},
    {"nowipe", 0, NULL, 'w'},
    {"noclear", 0, NULL, 'c'},
    {"noaccumulation", 0, NULL, 'A'},
    {"tdi", 0, NULL, 't'},
    {"TDI", 0, NULL, 't'},
    {"tiff", 2, NULL, 'T'},
    {"TIFF", 2, NULL, 'T'},
    {"FITS", 0, NULL, 'F'},
    {"fits", 0, NULL, 'F'},
    {"JPEG", 0, NULL, 'J'},
    {"jpeg", 0, NULL, 'J'},
    {"PNG", 2, NULL, 'P'},
    {"png", 2, NULL, 'P'},
    {"camera", 1, NULL, 'n'},
    {"debug", 2, NULL, 'S'},
    {"help", 0, NULL, 'h'},
    {NULL}
  };

  progName = basename(argv[0]);
  if(write(progressFD, "", 0)) progressFD=fileno(stdout);
  for(;;) {
    int optc = getopt_long_only(argc, argv, "", options, 0);
    switch(optc) {
      case -1:
        goto gotAllOpts;
      case 'a':  //auto exposure
        exposureSecs = 5*60;  //default to 5 minute max exposure time
        if(optarg) {
          char *terminator = optarg;
          if(*optarg != ',') terminator=parseDuration(optarg, &exposureSecs);
          switch(*terminator) {
            case ',':
              switch(*(terminator=parseInt(terminator+1, &maxAutoSignal))) {
                case ',':
                  if(*parseInt(terminator+1, &adcBias))
                    syntaxErr("Junk text after min A/D counts!");
                case '\0':
                  break;
                default:
                  syntaxErr("Junk text after autoexposure max A/D count target!");
              }
            case '\0':
              break;
            default:
              syntaxErr("Junk text after autoexposure max duration!");
          }
          if(exposureSecs < 0.002)
            syntaxErr("autoexposure limit must be > 2ms");
        }
        exposureSecs = -exposureSecs;
        break;
      case 'b':  //XY binning
        parseXYoptArg(&binX, &binY);
        if(!validBin(binX) || !validBin(binY))
          syntaxErr("Binning factors must be between 1 and 4!");
        break;
      case 'o':  //origin offset
        parseXYoptArg(&offsetX, &offsetY);
        if(offsetX < 0 || offsetY < 0)
          syntaxErr("Negative origin offset specified!");
        break;
      case 's':  //image size
        parseXYoptArg(&sizeX, &sizeY);
        if(sizeX < 0 || sizeY < 0)
          syntaxErr("Negative image size specified!");
        break;
      case 'd':  //depth
        if(*parseInt(optarg, &CCDdepth))
          syntaxErr("invalid text after depth option");
        if(CCDdepth <= 0)
          syntaxErr("Negative # of depth bits specified");
        break;
      case 'S':  //display debuging status info
        debug = optarg ? atoi(optarg) : 1;
        break;
      case 'w':  //suppress CCD wipe
        exposure.flags |= CCD_EXP_FLAGS_NOWIPE_FRAME;
        break;
      case 'c':  //suppress image clear
        exposure.flags |= CCD_EXP_FLAGS_NOCLEAR_FRAME;
        break;
      case 't':  //time delay integration
        exposure.flags |= CCD_EXP_FLAGS_TDI;
        break;
      case 'A':  //no binning accumulation
        exposure.flags |= CCD_EXP_FLAGS_NOBIN_ACCUM;
        break;
      case 'D':  //dard frame
        exposure.flags |= CCD_EXP_FLAGS_NOOPEN_SHUTTER;
        break;
      case 'n':  //camera device file
        device.filename[NAME_STRING_LENGTH]='\0';
        strncpy(device.filename, optarg, NAME_STRING_LENGTH-1);
        break;
      case 'T':  //generate TIFF file
        assignType(TIFFfile);
        if(optarg && toupper(*optarg)=='D')
          setenv("TIFF_COMPRESSION", "32946", 1);
        break;
      case 'F': //generate FITS file
        assignType(FITSfile);
        break;
      case 'J': //generate JPEG file
        assignType(JPEGfile);
        break;
      case 'P': //generate Portable Bitmap file
        assignType(PNGfile);
        if(*parseInt(optarg, &PNGcompressLevel))
          syntaxErr("invalid text after PNG option");
        break;
      case 'h':
        usage();
        return 0;
      default:
        syntaxErr("invalid option: %s", argv[optind]);
    }
  }
gotAllOpts: //on to arguments(exposure time and output file name)
  if(exposureSecs == 0.0) {
    if(!argv[optind])
      syntaxErr("Missing Exposure Time");
    if(*parseDuration(argv[optind], &exposureSecs))
      syntaxErr("Junk text after exposure duration");
    if(exposureSecs < 0.001)
      syntaxErr("Exposure duration must be >= 0.001 seconds");
    ++optind;
  }
  if(!CCDconnect(&device)) {
    fprintf(stderr, "Cannot open camera device: %s\n", device.filename);
    return 1;
  }
  printf("%s: %dx%d pixel %d-bit CCD camera\n",
    device.camera, device.width, device.height, device.depth);

  outFn = argv[optind];
  if(outFn) {
    char *lastDot;
    outFile = fopen(outFn, "wb");
    if(!outFile) {
      perror(outFn);
      return errno;
    }
    if(outputFileType == unspecifiedFile) {
      lastDot = strrchr(outFn, '.');
      if(lastDot) switch(toupper(lastDot[1])) {
        case 'J': outputFileType = JPEGfile;
          break;
        case 'T': outputFileType = TIFFfile;
          break;
        case 'F': outputFileType = FITSfile;
          break;
        case 'P': outputFileType = PNGfile;
          break;
      }
    }
  }else  //trying to write image to stdout
    syntaxErr("Missing output image filename!");

  exposure.width = sizeX ? sizeX : device.width;
  exposure.height = sizeY ? sizeY : device.height;
  exposure.xoffset = offsetX;
  exposure.yoffset = offsetY;
  overage = device.width - exposure.width - offsetX;
  if(overage < 0)
    exposure.width += overage;
  overage = device.height - exposure.height - offsetY;
  if(overage < 0)
    exposure.height += overage;
  exposure.xbin = binX;
  exposure.ybin = binY;
  exposure.dacBits = CCDdepth ? CCDdepth : device.dacBits;

  if(exposure.dacBits < 8 || exposure.dacBits > 16)
    syntaxErr("Pixel depth of %d bits is not currently supported!\n", exposure.dacBits);

  if(exposureSecs < 0.0) {
    exposureSecs = -exposureSecs;
    if(debug) printf(
      "Calibrating <= %g second exposure between %d and %d A/D counts...\n",
                exposureSecs, maxAutoSignal, adcBias);
    exposure.msec = exposureSecs * 1000.0 + 0.5;
    if(optimizeExposure(&exposure)) {
      fprintf(stderr, "Autoexposure calibration failed!\n");
      return 6;
    }
  }else
    exposure.msec = exposureSecs * 1000.0 + 0.5;

  exposureSecs =(double)exposure.msec / 1000.0;
  printf("Exposing %dx%d pixel %d-bit image for %g seconds\n",
    exposure.width/binX, exposure.height/binY, exposure.dacBits, exposureSecs);

  expose(&exposure);

  /*  Write out the image in the specified format */
  switch(outputFileType) {
    case unspecifiedFile:
      outputFileType = TIFFfile;  //default to TIFF
    case TIFFfile:
      {
        TIFF *tif = TIFFFdOpen(fileno(outFile), outFn, "w");
        if(!tif || saveTIFF(tif, &exposure)) imageWrtFailed();
        TIFFClose(tif);
      }
      break;

    case FITSfile:
      if(saveFITS(fileno(outFile), &exposure)) imageWrtFailed();
      break;

    case PNGfile:
      savePNG(outFile, &exposure);
      fclose(outFile);
      break;

    default:
      syntaxErr("Unsupported image file type:  %s",fileTypeName[outputFileType]);
  }
  printf("%s: %s Upload Complete\n", outFn, fileTypeName[outputFileType]);
  return 0;
}
