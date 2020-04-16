/******************  holdopen -- brent@mbari.org  ***************************
*    Copyright (C) 2020 MBARI
*    MBARI Proprietary Information. All rights reserved.
*
*     Spawn a daemon to hold stdin and stdout (serial ports) open
*     with options to control stdin's DTR line
****************************************************************************/

#include <stdlib.h>
#include <stdio.h>
#include <termio.h>
#include <unistd.h>

void doDTR(int opcode, const char *err)
{
  int arg = TIOCM_DTR;
  int result = ioctl(0, opcode, &arg);
  if (result < 0) {
    perror("Failed to deassert DTR");
    exit(2);
  }
}

int main(int argc, char **argv)
{
  int holdopen = 1;
  char *arg;

  (void) argc;

  while(arg=*++argv) {
    int c;
    while((c=*arg)=='-') arg++;
    switch(c) {
      case 'd':  //dtroff
        doDTR(TIOCMBIC, "Failed to deassert DTR");
        break;
      case 'o':  //ondtr
        doDTR(TIOCMBIS, "Failed to assert DTR");
        break;
      case 'n':  //nodaemon
        holdopen=0;
        break;

      case '1':
      case '2':
      case '3':
      case '4':
      case '5':
      case '6':
      case '7':
      case '8':
      case '9':
        usleep(atoi(arg)*1000);
        break;

      default:  fprintf(stderr, "\
Hold stdin and stdout ports open indefinately -- 4/15/20 brent@mbari.org\n\
Options (may be abbreviated and proceeded by dashes):\n\
  dtroff    deassert stdin serial port's DTR signal\n\
  ondtr     reassert DTR\n\
  1..9[0..9]*  delay specified milliseconds\n\
  nodaemon  do not fork daemon process\n\
  help      display this\n");
        exit(9);
    }
  }

  //optionally, create a daemon to hold the port open
  if (holdopen) {
    if (daemon(0, 1))
      perror("Could not spawn daemon");
    else{
      close(STDERR_FILENO);
      while(1) pause();  //wait to be terminated
    }
  }

}
