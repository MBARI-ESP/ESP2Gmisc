/*
 * GCCD - Gnome CCD Camera Controller
 * Copyright (C) 2001 David Schmenk
 *
 *  derived from dev_ctl.h by brent@mbari.org 
 *  -- removed dependencies on gccd and wheel and scope fns
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
 * USA
 */

#include <fcntl.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>

#include "types.h"
#include "devctl.h"

#define trace(args...) //fprintf(stderr,args)

/***************************************************************************\
*                                                                           *
*                     Low level CCD camera control                          *
*                                                                           *
\***************************************************************************/


/*
 * Connect to CCD camera.
 */
int CCDconnect(struct CCDdev *ccd)
{
    int           fd, msg_len, i;
    CCD_ELEM_TYPE msg[CCD_MSG_CCD_LEN/CCD_ELEM_SIZE];

trace ("CCDconnect %s\n", ccd->filename);

    if ((fd = open(ccd->filename, O_RDWR, 0)) < 0)
        return FALSE;
    /*
     * Request CCD parameters.
     */
    msg[CCD_MSG_HEADER_INDEX]    = CCD_MSG_HEADER;
    msg[CCD_MSG_LENGTH_LO_INDEX] = CCD_MSG_QUERY_LEN;
    msg[CCD_MSG_LENGTH_HI_INDEX] = 0;
    msg[CCD_MSG_INDEX]           = CCD_MSG_QUERY;
    write(fd, (char *)msg, CCD_MSG_QUERY_LEN);
    if ((msg_len = read(fd, (char *)msg, CCD_MSG_CCD_LEN)) != CCD_MSG_CCD_LEN)
    {
        fprintf(stderr, "CCD message length wrong: %d\n", msg_len);
        return FALSE;
    }
    /*
     * Response from CCD query.
     */
    if (msg[CCD_MSG_INDEX] != CCD_MSG_CCD)
    {
        fprintf(stderr, "Wrong message returned from query: 0x%04X", msg[CCD_MSG_INDEX]);
        return FALSE;
    }
    ccd->fd           = fd;
    ccd->width        = msg[CCD_CCD_WIDTH_INDEX];
    ccd->height       = msg[CCD_CCD_HEIGHT_INDEX];
    ccd->pixel_width  = (int)((msg[CCD_CCD_PIX_WIDTH_INDEX]  / 25.6) + 0.5) / 10.0;
    ccd->pixel_height = (int)((msg[CCD_CCD_PIX_HEIGHT_INDEX] / 25.6) + 0.5) / 10.0;
    ccd->fields       = msg[CCD_CCD_FIELDS_INDEX];
    ccd->depth        = msg[CCD_CCD_DEPTH_INDEX];
    ccd->dacBits      = msg[CCD_CCD_DAC_INDEX];
    ccd->color        = msg[CCD_CCD_COLOR_INDEX];
    strncpy(ccd->camera, (char *)&msg[CCD_CCD_NAME_INDEX], CCD_CCD_NAME_LEN);
    ccd->camera[CCD_CCD_NAME_LEN] = '\0';
    for (i = CCD_CCD_NAME_LEN - 1; i && (ccd->camera[i] == '\0' || ccd->camera[i] == ' '); i--)
        ccd->camera[i] = '\0'; // Strip off trailing spaces

trace ("%s: width=%d, height=%d, fields=%d, depth=%d, DACbits=%d, color=0x%04x\n"
          "pixWidth=%f, pixHeight=%f\n", 
          ccd->camera, ccd->width, ccd->height, ccd->fields, ccd->depth, ccd->dacBits, ccd->color,
          ccd->pixel_height, ccd->pixel_width);
    return TRUE;
}


int CCDrelease(struct CCDdev *ccd)
{
    int fd;

trace ("CCDrelease %s\n", ccd->filename);

    if ((fd = ccd->fd))
    {
        ccd->fd = 0;
        return (close(fd));
    }
    return 0;
}


/*
 * Device control.
 */
void CCDcontrol(struct CCDdev *ccd, int cmd, unsigned long param)
{
    CCD_ELEM_TYPE  msg[CCD_MSG_CTRL_LEN/CCD_ELEM_SIZE];
    /*
     * Send the control command.
     */
    msg[CCD_MSG_HEADER_INDEX]    = CCD_MSG_HEADER;
    msg[CCD_MSG_LENGTH_LO_INDEX] = CCD_MSG_CTRL_LEN;
    msg[CCD_MSG_LENGTH_HI_INDEX] = 0;
    msg[CCD_MSG_INDEX]           = CCD_MSG_CTRL;
    msg[CCD_CTRL_CMD_INDEX]      = cmd;
    msg[CCD_CTRL_PARM_LO_INDEX]  = param & 0xFFFF;
    msg[CCD_CTRL_PARM_HI_INDEX]  = param >> 16;
trace ("CCDcontrol #%d(%ld)\n", cmd, param);
    write(ccd->fd, (char *)msg, CCD_MSG_CTRL_LEN);
}


/*
 * Request exposure.
 */
void CCDexposeFrame(struct CCDexp *exposure)
{
    CCD_ELEM_TYPE  msg[CCD_MSG_EXP_LEN/CCD_ELEM_SIZE];
    /*
     * Send the capture request.
     */
    msg[CCD_MSG_HEADER_INDEX]    = CCD_MSG_HEADER;
    msg[CCD_MSG_LENGTH_LO_INDEX] = CCD_MSG_EXP_LEN;
    msg[CCD_MSG_LENGTH_HI_INDEX] = 0;
    msg[CCD_MSG_INDEX]           = CCD_MSG_EXP;
    msg[CCD_EXP_WIDTH_INDEX]     = exposure->width;
    msg[CCD_EXP_HEIGHT_INDEX]    = exposure->height;
    msg[CCD_EXP_XOFFSET_INDEX]   = exposure->xoffset;
    msg[CCD_EXP_YOFFSET_INDEX]   = exposure->yoffset;
    msg[CCD_EXP_XBIN_INDEX]      = exposure->xbin;
    msg[CCD_EXP_YBIN_INDEX]      = exposure->ybin;
    msg[CCD_EXP_DAC_INDEX]       = exposure->dacBits;
    msg[CCD_EXP_FLAGS_INDEX]     = exposure->flags;
    msg[CCD_EXP_MSEC_LO_INDEX]   = exposure->msec & 0xFFFF;
    msg[CCD_EXP_MSEC_HI_INDEX]   = exposure->msec >> 16;
    
trace ("CCDexposeFrame width=%d, height=%d, xyoffset=(%d,%d),\n"
        "   xybin=(%d,%d),  bits=%d, flags=0x%04x, msec=%d\n",
        exposure->width, exposure->height, exposure->xoffset, exposure->yoffset,
        exposure->xbin, exposure->ybin, exposure->dacBits,
        exposure->flags, exposure->msec);
        
    write(exposure->ccd->fd, (char *)msg, CCD_MSG_EXP_LEN);
    exposure->readRow = 0;
    exposure->rowBytes = exposure->width / exposure->xbin * ((exposure->ccd->depth + 7) / 8);
}


/*
 * Load exposed image one row at a time.
 */
int CCDloadFrame (struct CCDexp *exposure, void *rowBuffer)
{
    size_t        rowBytes    = exposure->rowBytes;
    int           row = exposure->readRow;
    int           rows = exposure->height / exposure->ybin;
    
    if (row == 0)
    {
        /*
         * Get header
         */
        CCD_ELEM_TYPE header[CCD_IMAGE_PIXELS_INDEX];       
        int           bytesRead = read(exposure->ccd->fd, header, sizeof (header));
        if (bytesRead == sizeof(header))
        {
            if (header[CCD_MSG_INDEX] == CCD_MSG_IMAGE)
            {
               size_t len = header[CCD_MSG_LENGTH_LO_INDEX] + (header[CCD_MSG_LENGTH_HI_INDEX] << 16);
               size_t expectedLen = rowBytes * rows + CCD_MSG_IMAGE_LEN;
                /*
                 * Validate image length.
                 */
                if (len != expectedLen)
                {
                    fprintf(stderr, "Image size discrepency! Read %d, expected %d\n", len, expectedLen);
                    return CCDsizeError;
                }
            }else{
                fprintf(stderr, "Invalid (driver) image message!");
                return CCDmsgError;
            }
        } else {
            /*
             * Error reading pixels.  Bail out.
             */
            fprintf(stderr, "Error reading exposure:%s\n", strerror(errno));
            return CCDreadError;
        }
    }
    if (row < rows) {
        int bytesRead = read(exposure->ccd->fd, rowBuffer, rowBytes);
        if (bytesRead == rowBytes)
          return ++exposure->readRow;
        if (bytesRead < 0) {
          fprintf(stderr, "Failure while reading image!");
          return CCDreadError;          
        } else {
          fprintf(stderr, "Truncated image read!");
          return CCDsizeError;          
        }
    }
    return CCDimageEnd;
}
/*
 * Abort current exposures.
 */
void CCDabortExposures(struct CCDexp *exposure)
{
    CCD_ELEM_TYPE msg[CCD_MSG_ABORT_LEN/CCD_ELEM_SIZE];

    /*
     * Send the abort request.
     */
    msg[CCD_MSG_HEADER_INDEX]    = CCD_MSG_HEADER;
    msg[CCD_MSG_LENGTH_LO_INDEX] = CCD_MSG_ABORT_LEN;
    msg[CCD_MSG_LENGTH_HI_INDEX] = 0;
    msg[CCD_MSG_INDEX]           = CCD_MSG_ABORT;
    write(exposure->ccd->fd, (char *)msg, CCD_MSG_ABORT_LEN);
}


