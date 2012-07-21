/***************************  resetModem.c  *********************************
 * $Source$
 *  Copyright (C) 2012 MBARI
 *
 *  MBARI Proprietary Information. All rights reserved.
 * $Id$
 *
 * Command line tool to:
 *  Cycle the power on the ESP's modem to reset it
 *  via serial commands to the I2C Gateway
 *   (on port /dev/I2Cgate by default) 
 *
 * Note that this approach works only when the ESP application does not 
 * control the I2C Gateway.  If the ESP app is active, the modem must
 * be reset via the espclient tool, something like this:
 *    echo "Sleepy.cycleModemPower! 5"  |  espclient resetModem
 *
 * See DrawfFunctions.rtf for documentation of the I2C gateway serial protocol
 * 
 ****************************************************************************/

#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <stddef.h>
#include <malloc.h>
#include <stdlib.h>
#include <getopt.h>   //for getopt_long()
#include <libgen.h>
#include <limits.h>
#include <stdarg.h>
#include <ctype.h>
#include <asm/ioctls.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <unistd.h>

#define DEVMODE  (O_RDWR|O_NOCTTY)

static char *devName = "/dev/I2Cgate";
static int setupPort = 1;
static struct termios rs232setup = {
  c_iflag:  IGNPAR | PARMRK,
  c_cflag:  CLOCAL | CRTSCTS | CS8 | CREAD,
  c_oflag:  0,
  c_lflag:  0
};
#define BAUD B115200

static int debug = 0;
static unsigned offSecs = 5;
#define MAXSECS  (120)
static unsigned long msAfterBreak = 200;

#define gateOK  'O'
static char gatewayCfg[] = {  //gateway configuration string
 0x8b, 0x82, 0x03, 0x04, 0x20, gateOK|0x80, 0x42, 0x4e, 0x53, 0xcd, 0xc3, 0xd8
};
#define resetOffset (2)
static char resetCmd[] = {  //gateway command to cycle modem power
 0x82, 0xD4, 5, //this byte is # of seconds power shall remain off (overwritten)
 0x81, 0xD3     //to confirm restart time
};

static char *progName;

//note that options commented out in usage don't seem to work for SXV-H9 camera
static void usage (void)
{
  fprintf(stderr, "%s revised 7/20/12 brent@mbari.org\n", progName);
  fprintf(stderr,
"Briefly cycle the power on ESP's modem to reset it.\n\
Usage:  %s  {options}  {offSeconds}\n\
offSeconds is the number of seconds modem shall be off\n\
  range:  0 to 120  #defaults to 5 seconds if unspecified\n\
options:  (may be abbriviated)\n\
  -device=[path]   #defaults to /dev/I2Cgate\n\
  -nosetup         #skip port baud rate setup otherwise 115200 baud\n\
  -wait=[ms delay] #milliseconds to delay after end of RS-232 break [%lu]\n\
  -verbose={level} #print debugging info\n\
  -help            #display this message\n\
",  progName, msAfterBreak);
}


int main (int argc, char **argv)
{
  const static struct option options[] = {
    {"device", 1, NULL, 'd'},
    {"nosetup", 0, NULL, 'n'},
    {"wait", 1, NULL, 'w'},
    {"verbose", 2, NULL, 'v'},
    {"help", 0, NULL, 'h'},
    {NULL}
  };
    
  int rs232;  //RS-232 port's file descriptor
  char *digits;
  progName = basename (argv[0]);
  for (;;) {
    int optc = getopt_long_only (argc, argv, "", options, 0);
    switch (optc) {
      case -1:
        goto gotAllOpts;
      case 'n':  //nosetup
        setupPort=0;
        break;
      case 'w':  //ms delay after break signal
        {
          char *end;
          unsigned long ms = strtoul(optarg, &end, 10);
          if (*end) {
            fprintf(stderr,"\'%s\' is not a valid positive integer!\n", optarg);
            return 2;
          }
          msAfterBreak = ms;
        }
        break;
      case 'v':  //verbose debug
        debug = optarg ? atoi(optarg) : 1;
        break;
      case 'd':  //override default device        
        devName = optarg;
        break;
      case 'h':  //help
        usage();
        return 0;
      default:
        usage();
        return 1;
    }
  }
gotAllOpts:
  digits = argv[optind];
  if (digits) {
    char *end;
    unsigned long secs = strtoul(digits, &end, 10);
    if (*end) {
      fprintf(stderr, "\'%s\' is not a valid positive integer!\n", digits);
      return 2;
    }
    if (secs > MAXSECS) {
      fprintf(stderr, "specified time %lu seconds > maximum of %u seconds!\n",
                       secs, MAXSECS);
      return 2;
    }
    offSecs = secs;
  }
  
  rs232 = open(devName, DEVMODE | O_NONBLOCK);
  if (rs232<0) {
    fprintf(stderr, "Cannot open I2C gateway %s: %s\n", 
            devName, strerror(errno));
    return 10;
  }
  ioctl(rs232, TIOCEXCL, 0);  //lock port for exclusive access
  
  if (setupPort) {
    cfsetospeed(&rs232setup, BAUD);
    rs232setup.c_cc[VTIME] = 10;
    rs232setup.c_cc[VMIN] = 0;
    tcsetattr(rs232, TCSANOW, &rs232setup);
    if (debug) fprintf(stderr, "setup port\n");
  }
  
  tcflush(rs232, TCIOFLUSH);
  tcsendbreak(rs232, 0);
  if (debug) fprintf(stderr, "sent break\n");
  usleep(msAfterBreak*1000);  //TODO:  check the version string returned!
  tcflush(rs232, TCIFLUSH);
  if (debug) fprintf(stderr, "flushed input\n");
  
  {
    ssize_t xfrd = write(rs232, gatewayCfg, sizeof gatewayCfg);
    char rsp;
    unsigned rstSecs;
    if (debug) fprintf(stderr, "wrote config\n");
    if (xfrd != sizeof gatewayCfg) {
      fprintf(stderr, "Cannot write to I2C gateway %s: %s\n",
              devName, strerror(errno));
      return 11;
    }
    fcntl(rs232, F_SETFL, DEVMODE);
    xfrd = read(rs232, &rsp, 1);
    if (debug) fprintf(stderr, "read ack\n");
    if (xfrd != 1) {
      fprintf(stderr, xfrd<0 ? "Cannot read I2C gateway %s: %s\n" :
                               "No response from I2C gateway %s\n",
              devName, strerror(errno));
      return 12;
    }
    if (rsp != gateOK) {
      fprintf(stderr, "I2C gateway %s rejected configuration!\n",
              devName);
      return 13;
    }
    fcntl(rs232, F_SETFL, DEVMODE | O_NONBLOCK);
    resetCmd[resetOffset] = offSecs;
    xfrd = write(rs232, resetCmd, sizeof resetCmd);
    if (debug) fprintf(stderr, "wrote reset cmd\n");
    if (xfrd != sizeof resetCmd) {
      fprintf(stderr, "Cannot write reset command I2C gateway %s: %s\n",
              devName, strerror(errno));
      return 14;
    }
    fcntl(rs232, F_SETFL, DEVMODE);
    xfrd = read(rs232, &rsp, 1);
    if (debug) fprintf(stderr, "read response %u, 0x%0x\n", xfrd, rsp);
    if (xfrd != 1) {
      fprintf(stderr, xfrd<0 ? "Cannot read I2C gateway %s: %s\n" :
                             "I2C Gateway %s did not respond to modem reset!\n",
              devName, strerror(errno));
      return 15;
    }
    rstSecs = offSecs ? rsp - 5 : 0;
    if (offSecs - rstSecs > 1) {
      fprintf(stderr, "Response of Gateway %s to modem reset was invalid!\n",
              devName, strerror(errno));
      return 14;
    }
    printf ("Modem will restart in %u seconds\n", rstSecs);
  }
}
