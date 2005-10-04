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
#include <time.h>

#include "devctl.h"   //low-level camera device control

#define validBin(b)  (b >= 1 && b <= 4)
#define REMAINING " seconds remaining"

static char *progName;
static int progressFD = 3;

static int CCDdepth = 0;
static int binX = 1, binY = 1;
static int offsetX = 0, offsetY = 0;
static int sizeX = 0, sizeY = 0;
static float exposureSecs;

void usage (void)
{
  fprintf (stderr, "%s revised 10/3/05 brent@mbari.org\n", progName);
  fprintf (stderr, 
"Snap a photo from a monochrome Starlight CCD camera. Usage:\n"
"  %s {options} <exposure seconds> <TIFF output file>\n"
"seconds may be specified in floating point to for msec resolution\n"
"omit output file to write image to stdout (provided it is not a terminal)\n"
"options:  (may be abbriviated)\n"
"  -binning=x{,y}    #x,y binning factors\n"
"  -offset=x{,y}     #origin offset\n"
"  -origin=x{,y}     #same as -offset=\n"
"  -size=x{,y}       #size of the image (width x height)\n"
"  -dark             #do not open shutter\n"
"  -depth=n          #number of bits per pixel\n"
"  -camera=deviceFn  #use specified device rather than /dev/ccda\n"
"  -nowipe           #do not wipe frame\n"
"  -noclear          #do not clear frame\n"
"  -noaccumulation   #do not accumulate charge when binning\n"
"  -tdi              #time delay and integrate\n"
"  -help             #displays this\n"
"examples:\n"
"  %s 1.5 myimage.tiff  #1.5 second exposure to myimage.tiff w/o binning\n"
"  %s -bin 2x2 .005 myimage.tiff  #5 msec exposure with 2x2 binning\n"
"notes:\n"
"  If possible, progress messages are output to file descriptor 3\n"
"  Otherwise, they are sent to stderr.\n", 
  progName, progName, progName);
}


void syntaxErr (char *format, ...)
{
  va_list ap;
  va_start (ap, format);
  vfprintf (stderr, format, ap);
  va_end (ap);
  fprintf (stderr, "\nTry running '%s -help'\n", progName);
  exit(3);
}


int progress (char *format, ...)
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
  
  
char *parseInt (char *cursor, int *integer)
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


char *parseXYoptArg (int *x, int * y)
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


char *parseFloat (char *cursor, float *f)
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

static void convert_pixels(unsigned char *src, unsigned char *dst, int pixel_size, int count)
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

/*
 * Save image to FITS file.
 */
static int saveFITS(int fd, struct CCDexp *exposure)
{
    char           record[FITS_CARD_COUNT][FITS_CARD_SIZE];
    unsigned char *pixelRow;
    int            i, k, result, pixelBytes;
    unsigned cols = exposure->width / exposure->xbin;
    unsigned rows = exposure->height / exposure->ybin;
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
    pixelBytes  = ((exposure->dacBits + 7) / 8);
    pixelRow = (unsigned char *) malloc(exposure->rowBytes);
    if (!pixelRow) {
      fprintf (stderr, "No memory for row buffer!\n");
      return -2;
    }
    while ((result = CCDloadFrame (exposure, pixelRow)) > 0) {
      if (result == 1) {
        progress ("\r  0%% Uploaded        ");
      }else if (!(result & 127)) {
        progress ("\r%3d%%", result*100 / rows);
      }
      convert_pixels(pixelRow, pixelRow, pixelBytes, cols);
      if (write(fd, pixelRow, exposure->rowBytes) != exposure->rowBytes) 
        return -1;
    }
    free(pixelRow);
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
    {"binning", 1, NULL, 'b'},
    {"bin", 1, NULL, 'b'},
    {"offset", 1, NULL, 'o'},
    {"origin", 1, NULL, 'o'},
    {"size", 1, NULL, 's'},
    {"dark", 0, NULL, 'D'},
    {"depth", 1, NULL, 'd'},
    {"nowipe", 0, NULL, 'w'},
    {"noclear", 0, NULL, 'c'},
    {"noaccumulation", 0, NULL, 'a'},
    {"tdi", 0, NULL, 't'},
    {"TDI", 0, NULL, 't'},
    {"camera", 1, NULL, 'n'},
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
      case 'w':  //suppress CCD wipe
        exposure.flags |= CCD_EXP_FLAGS_NOWIPE_FRAME;
        break;
      case 'c':  //suppress image clear
        exposure.flags |= CCD_EXP_FLAGS_NOCLEAR_FRAME;
        break;
      case 't':  //time delay integration
        exposure.flags |= CCD_EXP_FLAGS_TDI;
        break;
      case 'a':  //no binning accumulation
        exposure.flags |= CCD_EXP_FLAGS_NOBIN_ACCUM;
        break;
      case 'n':  //camera device file
        device.filename[NAME_STRING_LENGTH]='\0';
        strncpy (device.filename, optarg, NAME_STRING_LENGTH-1);
        break;
      case 'h':
        usage();
        return 0;
      default:
        syntaxErr("invalid option: %s", argv[optind]);
    }
  }
gotAllOpts: //on to required arguments (exposure time and output file)
  if (!argv[optind]) {
    syntaxErr ("Missing Exposure Time");
  }
  if (*parseFloat (argv[optind], &exposureSecs)) {
    syntaxErr ("Junk text after exposure duration");
  }
  if (exposureSecs < 0.001f) {
    syntaxErr ("Exposure duration (%g) must be >= 0.001 seconds", exposureSecs);
  }
  if (exposureSecs > (float)INT_MAX/1000.0f) {
    syntaxErr ("Exposure duration (%g) is too long!", exposureSecs);
  }
  
  if (!CCDconnect (&device)) {
    fprintf (stderr, "Cannot open camera device: %s\n", device.filename);
    return 1;
  }
  fprintf (stderr, "%s: %dx%d pixel %d-bit CCD camera\n", 
    device.camera, device.width, device.height, device.depth);
       
  outFn = argv[++optind];
  if (outFn) {
    outFile = fopen (outFn, "w");
    if (!outFile) {
      perror(outFn);
      return errno;
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
  if (saveFITS (fileno(outFile), &exposure)) {
    fprintf (stderr, "\nFITS image write failed!");
    return 2;
  }
  progress ("\r%s Upload Complete\n", outFn);
  return 0;
}
