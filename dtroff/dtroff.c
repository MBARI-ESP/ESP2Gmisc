/******************  dtroff -- brent@mbari.org  ***************************
*    Copyright (C) 2016 MBARI
*    MBARI Proprietary Information. All rights reserved.
*
*     Simply deassert stdin's DTR line 
*
****************************************************************************/

#include <stdlib.h>
#include <stdio.h>
#include <termio.h>


int main(int argc, char **argv)
{
  int arg = TIOCM_DTR;
  int result = ioctl(0, TIOCMBIC, &arg);
  if (result < 0) {
    fprintf(stderr, "Failed to deassert DTR\n");
    exit(2);
  }
}
