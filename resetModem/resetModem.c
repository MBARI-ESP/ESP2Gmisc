/***************************  resetModem.c  *********************************
 *  Copyright (C) 2015 MBARI
 *
 *  MBARI Proprietary Information. All rights reserved.
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

#define EndMark  "\200\r\n"  //gateway end of signon marker
#define EndMarkLen (sizeof EndMark - 1)
#define BeginMark "\r\n\r\n" //marks beginning of signon
#define BeginMarkLen (sizeof BeginMark - 1)

static int debug = 0;
static unsigned offSecs = 5;
#define MAXSECS  (120)

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
static unsigned rspTimeout = 20;
static int skipGatewayInit = 0;

static void usage (void)
{
  fprintf(stderr, "%s revised 9/25/15 brent@mbari.org\n", progName);
  fprintf(stderr,
"Briefly cycle the power on ESP's modem to reset it.\n\
Usage:  %s  {options}  {offSeconds}\n\
offSeconds is the number of seconds modem shall be off\n\
  range:  0 to 120  #defaults to 5 seconds if unspecified\n\
options:  (may be abbreviated)\n\
  -device=[path]   #defaults to /dev/I2Cgate\n\
  -wait=[delay]    #tenths of secs to delay for responses [%u]\n\
  -skipGatewayInit #skip the (re-)configuration of the I2C gateway\n\
  -verbose={level} #print debugging info\n\
  -help            #display this message\n\
",  progName, rspTimeout);
}


char *extractSignon(char *s, char *end)
/*
  Extract signon string from debugging info gateway outputs in response to
  RS232 break.
  Return pointer to the first printing character
  and write a NUL in place of the first trailing non-printing character
*/
{
  while (s <= end && *(signed char *)s<=' ') s++;
  while (s <= end && *(signed char *)end<=' ') --end;
  end[1]='\0';
  return s;
}


int main (int argc, char **argv)
{
  const static struct option options[] = {
    {"device", 1, NULL, 'd'},
    {"wait", 1, NULL, 'w'},
    {"skipGatewayInit", 0, NULL, 's'},
    {"verbose", 2, NULL, 'v'},
    {"help", 0, NULL, 'h'},
    {NULL}
  };
    
  int rs232;  //RS-232 port's file descriptor
  char *digits;
  ssize_t xfrd;  //retCode from read or write
  char rsp;      //response byte received from gateway
  
  progName = basename (argv[0]);
  for (;;) {
    int optc = getopt_long_only (argc, argv, "", options, 0);
    char *end;
    switch (optc) {
      case -1:
        goto gotAllOpts;
      case 'w':  //response timeout in tenths of secs
        {
          unsigned long tenths = strtoul(optarg, &end, 10);
          if (*end) {
            fprintf(stderr,"\'%s\' is not a valid positive integer!\n", optarg);
            return 2;
          }
          rspTimeout = tenths;
        }
        break;
      case 's':  //skip gateway initialization
        skipGatewayInit = 1;
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
  
  cfsetospeed(&rs232setup, BAUD);
  rs232setup.c_cc[VTIME] = rspTimeout;
  rs232setup.c_cc[VMIN] = 0;
  tcsetattr(rs232, TCSAFLUSH, &rs232setup);
  if (debug>1) fprintf(stderr, "setup port\n"); 
  tcflush(rs232, TCOFLUSH);
  fcntl(rs232, F_SETFL, DEVMODE);  //cancel O_NONBLOCK
 
  if (!skipGatewayInit) {
    char *cursor, *end;
    char signon[4095];  //buffer for gateway signon string
    
    tcsendbreak(rs232, 0);
    if (debug>1) fprintf(stderr, "sent break\n");  

    end = signon+sizeof(signon)-1;
    for(cursor=signon; cursor < end; cursor+=xfrd) {
      if (cursor-signon >= EndMarkLen &&
         !memcmp(cursor-EndMarkLen, EndMark, EndMarkLen) )
        break;  //received endmark
      xfrd = read(rs232, cursor, end - cursor);
      if (debug > 2) fprintf(stderr, "xfrd=%d\n", xfrd);
      if (xfrd < 0) {
        fprintf(stderr, "Cannot read I2C gateway %s: %s\n" ,
                devName, strerror(errno));
        return 17;
      }
      if (!xfrd)
        break;  //timeout
    }
    if (cursor >= end) {
        fprintf(stderr, "Signon rcv'd from I2C gateway %s was too long\n",
                devName);
        return 18;
    }  
    if (debug) {
      char *s = extractSignon(signon, cursor);
      if (debug < 2) {
        char *v = strstr(s, BeginMark);
        if (v) s = v+BeginMarkLen;
      }
      fprintf(stderr, "%s\n",  s );
    }

    xfrd = write(rs232, gatewayCfg, sizeof gatewayCfg);
    if (debug>1) fprintf(stderr, "wrote config\n");
    if (xfrd != sizeof gatewayCfg) {
      fprintf(stderr, "Cannot write to I2C gateway %s: %s\n",
              devName, strerror(errno));
      return 11;
    }
    xfrd = read(rs232, &rsp, 1);
    if (debug>1) fprintf(stderr, "read ack\n");
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
  }  // gateway is initialized

  resetCmd[resetOffset] = offSecs;
  xfrd = write(rs232, resetCmd, sizeof resetCmd);
  if (debug>1) fprintf(stderr, "wrote reset cmd\n");
  if (xfrd != sizeof resetCmd) {
    fprintf(stderr, "Cannot write reset command I2C gateway %s: %s\n",
            devName, strerror(errno));
    return 14;
  }
  xfrd = read(rs232, &rsp, 1);
  if (debug>1) fprintf(stderr, "read response %u, 0x%0x\n", xfrd, rsp);
  if (xfrd != 1) {
    fprintf(stderr, xfrd<0 ? "Cannot read I2C gateway %s: %s\n" :
                           "I2C Gateway %s did not respond to modem reset!\n",
            devName, strerror(errno));
    return 20;
  }
  {
    unsigned rstSecs = offSecs ? rsp - 5 : 0;
    if (offSecs - rstSecs > 1) {
      fprintf(stderr, "Response of Gateway %s to modem reset was invalid!\n",
              devName, strerror(errno));
      return 16;
    }
    printf ("Modem will restart in %u seconds\n", rstSecs);
  }
  return 0;
}
