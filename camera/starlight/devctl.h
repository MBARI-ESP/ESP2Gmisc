/*
  CCD Camera Device Controller

  Factored out of gccd.h by Brent Roman @ mbari.org
  
  from David Schmenk's GCCD application
*/

#ifndef DEVCTL_H
#define DEVCTL_H

#define DEFAULT_STRING_LENGTH   68
#define NAME_STRING_LENGTH      64
#define CAMERA_STRING_LENGTH    DEFAULT_STRING_LENGTH

#include "ccd_msg.h"

struct CCDdev
{
    char            filename[NAME_STRING_LENGTH];
    int             fd;
    unsigned int    width;
    unsigned int    height;
    unsigned int    depth;
    unsigned int    fields;
    unsigned int    dacBits;
    unsigned int    color;
    float           pixel_width;
    float           pixel_height;
    char            camera[CAMERA_STRING_LENGTH+1];
};

struct CCDexp
{
    struct CCDdev   *ccd;
    unsigned int      xoffset;
    unsigned int      yoffset;
    unsigned int      width;
    unsigned int      height;
    unsigned int      xbin;
    unsigned int      ybin;
    unsigned int      dacBits;
    unsigned int      flags;
    unsigned int      msec;
    unsigned int      readRow;
    size_t            rowBytes;
};

/*
 * Device control.
 */
int  CCDconnect(struct CCDdev *ccd);
int  CCDrelease(struct CCDdev *ccd);
void CCDexposeFrame(struct CCDexp *exposure);
int  CCDloadFrame(struct CCDexp *exposure, void *rowBuffer);
void CCDabortExposures(struct CCDexp *exposure);

#endif


/*
  Errors returned from CCDloadFrame
*/
enum {
  CCDreadError = -3,   /* cannot read device */
  CCDmsgError,         /* message header invalid */
  CCDsizeError,        /* image size invalid */
  CCDimageEnd = 0      /* end of image */
};
