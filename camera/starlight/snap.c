/***************  snap.c -- brent@mbari.org  **********************
* $Source$
*    Copyright (C) 2005 MBARI
*    MBARI Proprietary Information. All rights reserved.
* $Id$
*
* Starlight SXV-H9 camera command line processor
*
******************************************************************/

#include <stdio.h>
#include <errno.h>
#include <stddef.h>
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

#include "devctl.h"   //low-level camera device control

#define validBin(b)  (b >= 1 && b <= 4)
#define REMAINING " seconds remaining"
#define NO_PREDICTOR 1

static char *progName;
static int progressFD = 3;

static int CCDdepth = 0;
static int binX = 1, binY = 1;
static int offsetX = 0, offsetY = 0;
static int sizeX = 0, sizeY = 0;
static float exposureSecs = 0.0f;  //negative --> autoexposure time limit
static char debug = 0;

static enum {  //supported output file types
  unspecifiedFile, TIFFfile, FITSfile, JPEGfile,
} outputFileType = unspecifiedFile;

static const char *fileTypeName[] = {
  "unspecified", "TIFF", "FITS", "JPEG"
};


typedef struct {
	unsigned minimum, maximum, average, filteredMax;  // pixel values
		} imageStats;	// basic image statistics for autoexposure

typedef int writeLineFn (void *file, struct CCDexp *exposure, uint16 *lineBuffer);


//note that options commented out in usage don't seem to work for SXV-H9 camera
static void usage (void)
{
  fprintf (stderr, "%s revised 10/5/05 brent@mbari.org\n", progName);
  fprintf (stderr, 
"Snap a photo from a monochrome Starlight CCD camera. Usage:\n"
"  %s {options} <exposure seconds> <output file>\n"
"seconds may be specified in floating point for millisecond resolution\n"
"omit output file to write image to stdout (provided it is not a terminal)\n"
"options:  (may be abbriviated)\n"
"  -autoexpose{=600} #auto duration with specified max duration in seconds\n"
"  -binning=x{,y}    #x,y binning factors\n"
"  -offset=x{,y}     #origin offset\n"
"  -origin=x{,y}     #same as -offset=\n"
"  -size=x{,y}       #size of the image (width x height)\n"
//"  -dark           #do not open shutter\n"
//"  -depth=n        #number of bits per pixel\n"
"  -camera=deviceFn  #use specified device rather than /dev/ccda\n"
//"  -nowipe         #do not wipe frame\n"
//"  -noclear        #do not clear frame\n"
//"  -noaccumulation #do not accumulate charge when binning\n"
//"  -tdi            #time delay and integrate\n"
"  -tiff{=deflate}   #output TIFF file with optional deflate compression\n"
"  -fits             #output FITS file\n"
"  -jpeg             #output JPEG file\n"
"  -debug{=1}        #display debugging info\n"
"  -help             #displays this\n"
"examples:\n"
"  %s 1.5 myimage.tiff  #1.5 second exposure to myimage.tiff w/o binning\n"
"  %s -bin 2x3 .005 myimage.tiff  #5 msec exposure with 2x3 binning\n"
"notes:\n"
"  If possible, progress messages are output to file descriptor 3\n"
"  Otherwise, they are sent to stderr.\n", 
  progName, progName, progName);
}


static void syntaxErr (char *format, ...)
{
  va_list ap;
  va_start (ap, format);
  vfprintf (stderr, format, ap);
  va_end (ap);
  fprintf (stderr, "\nTry running '%s -help'\n", progName);
  exit(3);
}


static int progress (char *format, ...)
{
  char buffer[2000];
  va_list ap;
  size_t bytesWritten;
  va_start (ap, format);
  vsnprintf (buffer, sizeof(buffer), format, ap);
  va_end(ap);
  bytesWritten = write (progressFD, buffer, strlen(buffer));
  fsync (progressFD);
  return bytesWritten;
}
  
  
static char *parseInt (char *cursor, int *integer)
// parse an integer at cursor
// returns pointer to next char
//  abort with a syntaxErr if no valid text found
{
  char *end;
  long result;
  errno = 0;
  result = strtol(cursor, &end, 0);
  if (errno || end==cursor || result < INT_MIN || result > INT_MAX)
    syntaxErr("\"%s\" is not a valid integer", cursor);
  *integer = result;
  return end;
}


static char *parseXYoptArg (int *x, int * y)
// parse one or two integers separated by a comma
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
  return parseInt (end, y);
}


static char *parseFloat (char *cursor, float *f)
// parse a floating point (single precision) number at cursor
// returns pointer to next char
//  abort with a syntaxErr if no valid text found
{
  char *end;
  double result;
  errno = 0;
  result = strtod(cursor, &end);  //glibc strtof() appears to be broken!
  if (errno || end==cursor)
    syntaxErr("\"%s\" is not a valid floating point value", cursor);
  *f = result;
  return end;
}


static float parseDuration (char *cursor)
{
  float secs;
  if (*parseFloat (cursor, &secs))
    syntaxErr ("Junk text after exposure duration");
  if (secs > (float)INT_MAX/1000.0f)
    syntaxErr ("Exposure duration (%g) is too long!", secs);
  return secs;
}

 
static void 
showStats (imageStats *pixel)
{
  if (debug)
    fprintf (stderr, 
      "\r( %u Min / %u Avg / %u Max / %u FilteredMax ) A/D counts\n", 
        pixel->minimum,pixel->average,pixel->maximum,pixel->filteredMax);
}


int doNotWrite (void *ignored, struct CCDexp *exposure, uint16 *lineBuffer) 
{
  return 0;
}


static int 
readOutImage (struct CCDexp *exposure, writeLineFn *writeLine,
              void *fileDescriptor, imageStats *stats)
/*
  Read out an image from the CCD and produce image stats
  assumes 16-bit pixels for now
*/
{
  unsigned width = exposure->width / exposure->xbin;
  unsigned height = exposure->height / exposure->ybin;
//  unsigned pixelBytes  = ((exposure->dacBits + 7) / 8);
  uint32 avgPixel = 0;
  uint16 maxPixel = 0;
  uint16 maxFiltered = 0;
  uint16 minPixel = -1;
  unsigned row;
  int result = 0;
  uint16 *end, *cursor;
  uint16 *line, *line0 = malloc (exposure->rowBytes+2);
  if (!line0) {
    fprintf (stderr, "No memory for row buffer!\n");
    return -2;
  }
  line = line0+1;  //precharge line array with state info for filter
  end = line+width;
  *line0 = *end = 0;  //clear pad pixels

  while ((result = CCDloadFrame (exposure, line)) > 0) {
    uint32 sum = 0;
    if (result == 1) {
      progress ("\r  0%% Uploaded        ");
    }else if (!(result & 127)) {
      progress ("\r%3d%%", result*100 / height);
    }
    for (cursor=line; cursor<end; cursor++) {
      uint16 pixel = *cursor;
      sum+=pixel;
      if (pixel < minPixel) minPixel=pixel;
      if (pixel > maxFiltered) {  //look left and right to filter out hotspots
	    if (!(pixel > cursor[-1] && pixel > cursor[1])) maxFiltered=pixel;
	if (pixel > maxPixel) maxPixel=pixel;
      }
    }
    avgPixel += sum / width;
    if (writeLine(fileDescriptor, exposure, line)) {result=-1; break;}
  }
  avgPixel /= height;
  free (line0);
  if (stats) {
    stats->minimum = minPixel;
    stats->maximum = maxPixel;
    stats->average = avgPixel;
    stats->filteredMax = maxFiltered;
    showStats (stats);
  }
  return result;
}


#if 0
static int 
optimizeExposure (struct CCDexp *exposure)
/*
calculate optimized exposure time in milliseconds 
limit exposure time to maxSeconds.

Theory:
Take a short exposure with the coursest binning.
Optimum Exposure time is determined
by the brightest pixel in this course image.  Scale exposure time so that this
"bright" pixel reads approximately max A/D counts.
*/
{
  const double minSBIGseconds = (double)minSBIGms / 1000.0;
  const long absoluteMaxSignal = binningMode ? maxSBIGAD : maxSBIGAD0;
  unsigned long testms = testSBIGms;
  struct readoutInfo *image = &imagingInfo.readoutInfo[0];
  struct readoutInfo *desired = image + binningMode;
  struct readoutInfo *testExposure = desired;  //test image info
  float  desiredAspect = (float)desired->height / (float)desired->width;
  struct readoutInfo *end = image + imagingInfo.readoutModes;
  struct readoutInfo *cursor = image;
  while (cursor < end) {
    if (cursor->height < testExposure->height) {
      float aspect = (float)cursor->height / (float)cursor->width;
      float ratio = aspect / desiredAspect;
      if (ratio >= .98f && ratio <= 1.02f)  //nearly the desired aspect ratio
	testExposure = cursor;  //found a better readout mode for our test exposure
    }
    cursor++;
  }
 tooBright:
  {
    imageStats lightStats, darkStats;

    if (expose (testms, SC_OPEN_SHUTTER) ||
	  readOutImage (testExposure->mode, NULL, &lightStats)) return lastSBIGerr;

    if (lightStats.filteredMax <= absoluteMaxSignal) {
      if (expose (testms, SC_CLOSE_SHUTTER) ||
	  readOutImage (testExposure->mode, NULL, &darkStats)) return lastSBIGerr;
      {
        long maxSignal = lightStats.filteredMax - darkStats.filteredMax;
        long desiredBinArea = desired->height * desired->width;
        long testBinArea = testExposure->height * testExposure->width;
	float targetMaxSignal = SBIGtarget * (float)absoluteMaxSignal;
        float exposureScaleFactor = (float)testBinArea/(float)desiredBinArea * 
					(float)targetMaxSignal/(float)maxSignal;
	*seconds = (double)testms / 1000.0 * exposureScaleFactor;
	if (*seconds >= maxSeconds) {
	  if (debug) 
  fprintf (stderr, 
    "Too Dark -- required %gs exposure is longer than %gs time limit\n", 
					  *seconds, maxSeconds);
	   *seconds = maxSeconds;
	   return CE_NO_ERROR;
	 }
      }
    }else{  //overexposed!
	  if (testms > minSBIGms) { // 1st try short test exposure
	    testms = minSBIGms;
	    goto tooBright;
	  }
	  if (testExposure != desired) {
	    testExposure = desired;   //then try using the desired binning mode...
	    goto tooBright;			// as a last resort
	  }
    }
  }
  if (*seconds < minSBIGseconds) {
    if (SBIGdebug > 1)
      printf ("Too Bright -- required exposure is faster than camera allows\n"); 
    *seconds = minSBIGseconds;
  }
  return CE_NO_ERROR;	  
}
#endif

/*
 * FITS file routines.
 */
#define FITS_CARD_COUNT     36
#define FITS_CARD_SIZE      80
#define FITS_RECORD_SIZE    (FITS_CARD_COUNT*FITS_CARD_SIZE)
/*
 * Convert unsigned LE pixels to BE pixels and reverse order
 */

#define swab2(word16)  (((word16) >> 8) | ((word16) << 8) )

#define swab4(word32)  (((word32) >> 24) | ((word32) << 24) | \
          (((word32) & 0x00FF0000) >> 8) | (((word32) & 0x0000FF00) << 8) )

static void convert_pixels(unsigned char *src, int pixel_size, int count)
{
    switch (pixel_size)
    {
        case 1:
            {
              unsigned char *end = src + count - 1;
              while (src < end) {
                unsigned char b = *src; *src++ = *end; *end-- = b;
              }
            }
            break;
        case 2:
            {
              unsigned short *start = (unsigned short *) src;
              unsigned short *end = start + count - 1;              
              while (start <= end) {
                unsigned short startPixel = *start;
                unsigned short endPixel = *end;
                *end-- = swab2 (startPixel);
                *start++ = swab2 (endPixel);
              }
            }
            break;
        case 4:
            {
              unsigned long *start = (unsigned long *) src;
              unsigned long *end = start + count - 1;              
              while (start <= end) {
                unsigned long startPixel = *start;
                unsigned long endPixel = *end;
                *end-- = swab4 (startPixel);
                *start++ = swab4 (endPixel);
              }
            }
            break;
    }
}


int writeFITSline (void *fd, struct CCDexp *exposure, uint16 *lineBuffer) 
{
  convert_pixels((unsigned char *)lineBuffer, 2, exposure->rowBytes/2);
  return write((int)fd, lineBuffer, exposure->rowBytes) != exposure->rowBytes;
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
    char *timeString = ctime (&exposure->start);
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
    sprintf(record[i++], "DATAMAX = %20u", (1<<exposure->dacBits)-1);
    sprintf(record[i++], "XPIXSZ  = %20f", exposure->ccd->pixel_width*exposure->xbin);
    sprintf(record[i++], "YPIXSZ  = %20f", exposure->ccd->pixel_height*exposure->ybin);
    sprintf(record[i++], "DATE-OBS= '%s'", timeString);
    sprintf(record[i++], "EXPOSURE= %20f", (float)exposure->msec / 1000.0f);
    
    //TODO: insert environment strings here...
    
    sprintf(record[i++], "END");
    for (k = 0; k < FITS_RECORD_SIZE; k++)
        if (((char *)record)[k] == '\0')
            ((char *)record)[k] = ' ';
    if (write(fd, record, FITS_RECORD_SIZE) != FITS_RECORD_SIZE)
      return -1;
      
    /*
     * Convert and write image data.
     */
    if (readOutImage (exposure, writeFITSline, (void *)fd, &stats))
      return -1;
    /*
     * Pad remaining record size with zeros and close.
     */
    {
      size_t image_size = exposure->rowBytes*rows;
      size_t shortLen = image_size % FITS_RECORD_SIZE;
      if (shortLen) {
        size_t padBytes = FITS_RECORD_SIZE - shortLen;
        memset(record, 0, padBytes);    
        if (write(fd, record, padBytes) != padBytes)
          return -1;
      }
    }
    return close(fd);
}


//  TIFF file routines

int setTiff (TIFF* tif, ttag_t tag, ...)
/*
  Convenient function to set a TIFF tag.
  Calls TIFFVSetField
*/
{
    va_list ap;
    int ok;
    va_start  (ap, tag);
    ok = TIFFVSetField(tif, tag, ap);
    va_end (ap);
    if (!ok)
      fprintf (stderr, "Error while setting TIFF tag #%d\n", tag);
    return ok;
}


static int 
setTiffDate (TIFF* tif)
/*
	write the 20 character TIFF DateTime tag
*/
{
	char buffer[20];
	time_t	now;
	struct tm date;
	time (&now);
	gmtime_r (&now, &date);	
	strftime (buffer, sizeof(buffer), "%Y:%m:%d %H:%M:%S", &date);
	return setTiff (tif, TIFFTAG_DATETIME, buffer);
}


int writeTIFFline (void *tif, struct CCDexp *exposure, uint16 *lineBuffer) 
{
  return TIFFWriteScanline((TIFF *)tif, lineBuffer, exposure->readRow-1, 0) != 1;
}


/*
 * Save image to TIFF file.
 */
static int saveTIFF(TIFF *tif, struct CCDexp *exposure)
{
  imageStats stats;  
  char *artist = getenv ("TIFF_ARTIST");
  char *host = getenv ("TIFF_HOST");
  char *soft = getenv ("TIFF_SOFTWARE");
  char *make = getenv ("TIFF_MAKE");
  char *compressString = getenv ("TIFF_COMPRESSION");
  char *predictString = getenv ("TIFF_PREDICTOR");
  char *comment = getenv ("TIFF_COMMENT");
  int compress = compressString ? atoi(compressString) : 0;
  int predict = predictString ? atoi(predictString) : 0;
  
  setTiff (tif, TIFFTAG_MODEL, exposure->ccd->camera);
  setTiffDate (tif);
  if (make) setTiff (tif, TIFFTAG_MAKE, make);
  if (artist) setTiff (tif, TIFFTAG_ARTIST, artist);
  if (host) setTiff (tif, TIFFTAG_HOSTCOMPUTER, host);
  if (soft) setTiff (tif, TIFFTAG_SOFTWARE, soft);
  if (compress) setTiff (tif, TIFFTAG_COMPRESSION, compress);
  if (predict) setTiff (tif, TIFFTAG_PREDICTOR, predict);
  {
    unsigned width = exposure->width / exposure->xbin;
    unsigned height = exposure->height / exposure->ybin;
      //shoot for 64KByte TIFF image strips
    unsigned strips = width*height*sizeof(uint16) / 65536;  
    unsigned stripRows;
    if (!strips) strips = 1;
    stripRows = height / strips;
    if (!stripRows) stripRows = 1;
    if (debug>1)
      fprintf (stderr, "(%dx%d) TIFF image in %ld strips with %ld rows/strip\n",
			        width, height, strips, stripRows);
    setTiff(tif, TIFFTAG_PLANARCONFIG, PLANARCONFIG_CONTIG);
    setTiff(tif, TIFFTAG_SAMPLESPERPIXEL, 1);
    setTiff(tif, TIFFTAG_BITSPERSAMPLE, 16);

    setTiff(tif, TIFFTAG_PHOTOMETRIC, PHOTOMETRIC_MINISBLACK);
    setTiff(tif, TIFFTAG_IMAGEWIDTH, width);
    setTiff(tif, TIFFTAG_ROWSPERSTRIP, stripRows);
  }
  if (readOutImage (exposure, writeTIFFline, tif, &stats)) return -1;
  {
    char description[2000], *cursor=description;
    char binning[30];
    binning[0] = '\0';
    if (exposure->xbin != 1 || exposure->xbin != 1) 
      sprintf (binning, "with %dx%d binning", exposure->xbin, exposure->ybin);

    if (comment) {
      strncat (description, comment, 1800);
      cursor += strlen(description);
      *cursor++ = '\n';
    }
    sprintf (cursor, "Exposed %g seconds %s",
                        (double)exposure->msec/1000.0, binning);			    
    setTiff (tif, TIFFTAG_IMAGEDESCRIPTION, description);
  }
  return 0;
}


void assignType (int fileType)
{
  if (outputFileType != unspecifiedFile)
    syntaxErr ("Redundant ouput file type specification!");
  outputFileType = fileType;
}


void imageWrtFailed (void)
{
   fprintf (stderr, "\n%s image write failed!\n", fileTypeName[outputFileType]);
   exit(2);
}
        

int main (int argc, char **argv)
{
  struct CCDdev device = {"/dev/ccda"};
  struct CCDexp exposure = {&device};
  unsigned short *pixelRow, *end;
  int overage;
  unsigned avgPixel = 0;
  char *outFn;
  FILE *outFile;
  time_t snapEndTime, secsLeft;
  
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
    {"camera", 1, NULL, 'n'},
    {"debug", 2, NULL, 'S'},
    {"help", 0, NULL, 'h'},
    {NULL}
  };
    
  progName = basename (argv[0]);
  if (fsync(progressFD)) progressFD=fileno(stderr);
      
  for (;;) {
    int optc = getopt_long_only (argc, argv, "", options, 0);
    switch (optc) {
      case -1:
        goto gotAllOpts;
      case 'a':  //auto exposure
        if (optarg) {
          exposureSecs = -parseDuration (optarg);
          if (exposureSecs >= -0.002f)
            syntaxErr ("autoexposure limit must be > 2ms");
        }else
          exposureSecs = -600;  //default to 5 minute max exposure time
        break;
      case 'b':  //XY binning
        parseXYoptArg (&binX, &binY);
        if (!validBin(binX) || !validBin(binY))
          syntaxErr ("Binning factors must be between 1 and 4!");
        break;
      case 'o':  //origin offset
        parseXYoptArg (&offsetX, &offsetY);
        if (offsetX < 0 || offsetY < 0)
          syntaxErr ("Negative origin offset specified!");
        break;
      case 's':  //image size
        parseXYoptArg (&sizeX, &sizeY);
        if (sizeX < 0 || sizeY < 0)
          syntaxErr ("Negative image size specified!");
        break;
      case 'd':  //depth
        if (*parseInt (optarg, &CCDdepth))
          syntaxErr ("invalid text after depth option");
        if (CCDdepth <= 0)
          syntaxErr ("Negative # of depth bits specified");
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
        strncpy (device.filename, optarg, NAME_STRING_LENGTH-1);
        break;
      case 'T':  //generate TIFF file
        assignType(TIFFfile);
        if (optarg && toupper(*optarg)=='D')
          setenv ("TIFF_COMPRESSION", "32946", 1);
        break;
      case 'F': //generate FITS file
        assignType(FITSfile);
        break;
      case 'J': //generate JPEG file
        assignType(JPEGfile);
        break;
      case 'h':
        usage();
        return 0;
      default:
        syntaxErr("invalid option: %s", argv[optind]);
    }
  }
gotAllOpts: //on to arguments (exposure time and output file name)
  if (exposureSecs == 0.0f) {
    if (!argv[optind])
      syntaxErr ("Missing Exposure Time");
    exposureSecs = parseDuration (argv[optind]);
    if (exposureSecs < 0.001f)
      syntaxErr ("Exposure duration must be >= 0.001 seconds");
    ++optind;
  }
  if (!CCDconnect (&device)) {
    fprintf (stderr, "Cannot open camera device: %s\n", device.filename);
    return 1;
  }
  fprintf (stderr, "%s: %dx%d pixel %d-bit CCD camera\n", 
    device.camera, device.width, device.height, device.depth);
       
  outFn = argv[optind];
  if (outFn) {
    char *lastDot;
    outFile = fopen (outFn, "w");
    if (!outFile) {
      perror(outFn);
      return errno;
    }
    if (outputFileType == unspecifiedFile) {
      lastDot = strrchr (outFn, '.');
      if (lastDot) switch (toupper(lastDot[1])) {
        case 'J': outputFileType = JPEGfile;
          break;
        case 'T': outputFileType = TIFFfile;
          break;
        case 'F': outputFileType = FITSfile;
          break;
      }
    }
  }else{  //trying to write image to stdout
    if (isatty(fileno(stdout)))
      syntaxErr ("Cannot write image to terminal stdout.  Specify a filename!");
    outFile = stdout;
  }
  
  exposure.width = sizeX ? sizeX : device.width;
  exposure.height = sizeY ? sizeY : device.height;
  exposure.xoffset = offsetX;
  exposure.yoffset = offsetY;
  overage = device.width - exposure.width - offsetX;
  if (overage < 0)
    exposure.width += overage;
  overage = device.height - exposure.height - offsetY;
  if (overage < 0)
    exposure.height += overage;
  exposure.xbin = binX;
  exposure.ybin = binY;
  exposure.dacBits = CCDdepth ? CCDdepth : device.dacBits;
  
  if (exposure.dacBits < 8 || exposure.dacBits > 16)
    syntaxErr ("Pixel depth of %d bits is not currently supported!\n", exposure.dacBits);

  if (exposureSecs < 0.0) {
    fprintf (stderr, "Auto exposure (for no longer than %g seconds) ...\n",
                exposureSecs = -exposureSecs);
    exposure.msec = exposureSecs * 1000.0f;
//    if (optimizeExposure (&exposure)) 
      return 6;
  }else
    exposure.msec = exposureSecs * 1000.0f;

  fprintf (stderr, "Exposing %dx%d pixel %d-bit image for %g seconds\n",
    exposure.width/binX, exposure.height/binY, exposure.dacBits, exposureSecs);
    
  CCDexposeFrame (&exposure);
  exposure.start = time(NULL);
  snapEndTime = exposure.start + (time_t) exposureSecs;
  
  secsLeft = exposureSecs;
  if (secsLeft > 1) {  //output exposure progress messages
    int digits = progress ("%d" REMAINING, secsLeft) - (sizeof(REMAINING)-1);
    sleep(1);
    while ((secsLeft = snapEndTime - time(NULL)) > 1) {
      progress ("\r%*d ", digits, secsLeft);
      sleep(1);
    }
  }
  /*  Write out the image in the specified format */
  switch (outputFileType) {
    case unspecifiedFile:
      outputFileType = TIFFfile;  //default to TIFF
    case TIFFfile:
      {
        TIFF *tif = TIFFFdOpen (fileno(outFile), outFn, "w");
        if (!tif || saveTIFF (tif, &exposure)) imageWrtFailed();
        TIFFClose(tif);
      }
      break;
      
    case FITSfile:
      if (saveFITS (fileno(outFile), &exposure)) imageWrtFailed();
      break;
      
    default:
      syntaxErr("Unsupported image file type:  %s",fileTypeName[outputFileType]);
  }
  progress ("\r%s: %s Upload Complete\n", outFn, fileTypeName[outputFileType]);
  return 0;
}
