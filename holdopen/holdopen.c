/******************  holdopen -- brent@mbari.org  ***************************
*    Copyright (C) 2016 MBARI
*    MBARI Proprietary Information. All rights reserved.
*
*     Spawn a daemon to hold stdin and stdout (serial ports) open
*     with an option to deassert stdin's DTR line 
*
****************************************************************************/

#include <stdlib.h>
#include <stdio.h>
#include <termio.h>
#include <unistd.h>
#include <string.h>


int main(int argc, char **argv)
{
  int holdopen = 1;
  int dtroff = 0;
  char *arg;

  (void) argc;
  
  while(arg=*++argv) {
    int c;
    while((c=*arg)=='-') arg++;
    switch(c) {
      case 'd': 
        dtroff=1;
        break;

      case 'n':
        holdopen=0;
        break;

      default:  fprintf(stderr, "\
Hold stdin and stdout ports open indefinately -- 4/30/16 brent@mbari.org\n\
Options (may be abbreviated and proceeded by dashes):\n\
  dtroff    deassert stdin serial port's DTR signal\n\
  nodaemon  do not fork daemon process\n\
  help      display this\n");
                exit(9);
    }
  }
  
  if (dtroff) {
    int arg = TIOCM_DTR;
    int result = ioctl(0, TIOCMBIC, &arg);
    if (result < 0) {
      perror("Failed to deassert DTR");
      exit(2);
    }
  }

  //see if we should create a daemon to hold the port open
  if (holdopen) {
    if (daemon(0, 1))
      perror("Could not spawn daemon");
    else
      close(STDERR_FILENO);
      while(1) pause();  //wait to be terminated
  }
}
