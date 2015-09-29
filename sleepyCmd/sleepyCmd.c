/***************************  resetModem.c  *********************************
 *  Copyright (C) 2015 MBARI
 *
 *  MBARI Proprietary Information. All rights reserved.
 *
 * Command line tool to command ESP 2G sleepy microcontroller
 *  via serial commands to the I2C Gateway
 *   (on port /dev/I2Cgate by default) 
 *
 * Note that this approach works only when the ESP application does not 
 * control the I2C Gateway.  If the ESP app is active, the modem must
 * be reset via the espclient tool, with something like this:
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
int rs232;              //RS-232 port's file descriptor
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

#define sysOnOffset (2)  //# of seconds to stay on before turning off
#define sysOffOffset (6) //# of seconds to stay off before turning on
static char sysPwrOff[] = { //turn off system (host) power
 0x89, -5,
 0, 0, 0, 0,
 0, 0, 0, 0
};

#define envRateOff (2)
static char envStop[] = {  //stop environmental sensor sampling
 0x83, -22, 0, 0
};
static int envPeriod = -1; //change period only if it is >= 0

static unsigned offSecs = 5;
#define MAXSECS  (120)
#define resetOffset (2)
static char resetCmd[] = {  //gateway command to cycle modem power
 0x82, 0xD4, 5, //this byte is # of seconds power shall remain off (overwritten)
 0x81, 0xD3     //to confirm restart time
};

static char *progName;
static unsigned rspTimeout = 20;
static unsigned shutdownDelay = 3;
static int skipGatewayInit = 0;

static void usage (void)
{
  fprintf(stderr, "%s revised 9/28/15 brent@mbari.org\n", progName);
  fprintf(stderr, "\
Send a command to the ESP Sleepy microcontroller.\n\
Usage:  %s {options} {resetModem | powerOff | none} {args}\n\
resetModem {offSeconds} --> turn off power to the ESP's modem to reset it.\n\
  offSeconds is the number of seconds modem shall be off\n\
  range:  0 to 120  #defaults to 5 seconds if unspecified\n\
powerOff sleepSeconds {shutdownDelay} --> turn off ESP host after shutdownDelay\n\
  sleepSeconds is number of seconds system shall sleep\n\
  shutdownDelay is number of seconds before power is shut off [default=%u]\n\
    (note that zero seconds for sleep or shutdown reads as \"indefinately\")\n\
options:  (may be abbreviated)\n\
  -device=[path]   #defaults to /dev/I2Cgate\n\
  -wait=[delay]    #tenths of secs to delay for responses [%u]\n\
  -skipGatewayInit #skip the (re-)configuration of the I2C gateway\n\
  -verbose={level} #print debugging info\n\
  -envPoll=secs    #set environment sensor polling period before command\n\
  -quitEnvPoll     #quit environmental sensor polling before command\n\
  -help            #display this message\n\
",  progName, shutdownDelay, rspTimeout);
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


void sendCmd(char *cmd, unsigned cmdSize, const char *comment)
{
  ssize_t xfrd = write(rs232, cmd, cmdSize);
  if (debug>1) fprintf(stderr, "sent %s cmd\n", comment);
  if (xfrd != cmdSize) {
    fprintf(stderr, "Cannot sent %s command I2C gateway %s: %s\n",
            devName, strerror(errno), comment);
    exit(14);
  }
}


unsigned long posInt(char *digits)
{
  char *end;
  unsigned long secs = strtoul(digits, &end, 10);
  if (*end) {
    fprintf(stderr, "\'%s\' is not a valid positive integer!\n", digits);
    exit(2);
  }
  return secs;
}


void putu32(char *u32, unsigned long value)
/*
  put 32-bit value in network byte order (MSB first)
*/
{
  u32[3]=value;
  u32[2]=value>>=8;
  u32[1]=value>>=8;
  u32[0]=value>>=8;
}


void setupPort(void)
{
  rs232 = open(devName, DEVMODE | O_NONBLOCK);
  if (rs232<0) {
    fprintf(stderr, "Cannot open I2C gateway %s: %s\n", 
            devName, strerror(errno));
    exit(10);
  }
  ioctl(rs232, TIOCEXCL, 0);  //lock port for exclusive access
  
  cfsetospeed(&rs232setup, BAUD);
  rs232setup.c_cc[VTIME] = rspTimeout;
  rs232setup.c_cc[VMIN] = 0;
  tcsetattr(rs232, TCSAFLUSH, &rs232setup);
  if (debug>2) fprintf(stderr, "setup port\n"); 
  tcflush(rs232, TCOFLUSH);
  fcntl(rs232, F_SETFL, DEVMODE);  //cancel O_NONBLOCK
 
  if (!skipGatewayInit) {
    char *cursor, *end;
    ssize_t xfrd = 0;
    char signon[4095];  //buffer for gateway signon string
    
    tcsendbreak(rs232, 0);
    if (debug>2) fprintf(stderr, "sent break\n");  

    end = signon+sizeof(signon)-1;
    for(cursor=signon; cursor < end; cursor+=xfrd) {
      if (cursor-signon >= EndMarkLen &&
         !memcmp(cursor-EndMarkLen, EndMark, EndMarkLen) )
        break;  //received endmark
      xfrd = read(rs232, cursor, end - cursor);
      if (debug > 4) fprintf(stderr, "xfrd=%d\n", xfrd);
      if (xfrd < 0) {
        fprintf(stderr, "Cannot read I2C gateway %s: %s\n" ,
                devName, strerror(errno));
        exit(17);
      }
      if (!xfrd)
        break;  //timeout
    }
    if (cursor >= end) {
        fprintf(stderr, "Signon rcv'd from I2C gateway %s was too long\n",
                devName);
        exit(18);
    }  
    if (debug) {
      char *s = extractSignon(signon, cursor);
      if (debug < 4) {
        char *v = strstr(s, BeginMark);
        if (v) s = v+BeginMarkLen;
      }
      fprintf(stderr, "%s\n",  s );
    }
  }  // gateway is initialized
  if (envPeriod >= 0) {  //change environmental sampling period
    envStop[envRateOff] = envPeriod >> 8;
    envStop[envRateOff+1] = envPeriod;
    sendCmd(envStop, sizeof envStop, "env period");
  }
}


int main (int argc, char **argv)
{
  const static struct option options[] = {
    {"device", 1, NULL, 'd'},
    {"wait", 1, NULL, 'w'},
    {"skipGatewayInit", 0, NULL, 's'},
    {"envPoll", 1, NULL, 'e'},
    {"quitEnvPoll", 0, NULL, 'q'},
    {"verbose", 2, NULL, 'v'},
    {"help", 0, NULL, 'h'},
    {NULL}
  };
    
  char *cmd, *digits;
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
badarg:
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
      case 'e':  //change environmental sampling rate 
        envPeriod = atoi(optarg);
        if (!envPeriod) goto badarg;
        break;
      case 'q':  //quit environmental sampling
        envPeriod = 0;
        break;
      case 'd':  //override default device        
        devName = optarg;
        break;
      case 'h':  //help
        usage();
        return 0;
      default:
syntaxErr:
        usage();
        return 1;
    }
  }
gotAllOpts:
  cmd=argv[optind++];
  if (!cmd) {
    usage();
    return 1;
  }
  if (!strcasecmp(cmd, "resetModem")) {
    if (argv[optind]) {
      unsigned long secs = posInt(argv[optind]);
      if (secs > MAXSECS) {
        fprintf(stderr, "specified time %lu seconds > maximum of %u seconds!\n",
                         secs, MAXSECS);
        return 3;
      }
      resetCmd[resetOffset] = secs;
    }
    setupPort();
    sendCmd(resetCmd, sizeof resetCmd, "reset");
    xfrd = read(rs232, &rsp, 1);
    if (debug>2) fprintf(stderr, "read response %u, 0x%0x\n", xfrd, rsp);
    if (xfrd != 1) {
      fprintf(stderr, xfrd<0 ? "Cannot read I2C gateway %s: %s\n" :
                           "I2C Gateway %s did not respond to modem reset!\n",
              devName, strerror(errno));
      return 20;
    }
    {
      unsigned rstSecs = resetCmd[resetOffset] ? rsp - 5 : 0;
      if (offSecs - rstSecs > 1) {
        fprintf(stderr, "Response of Gateway %s to modem reset was invalid!\n",
                devName, strerror(errno));
        return 16;
      }
      printf ("Modem will restart in %u seconds\n", rstSecs);
    }
  }else if (!strcasecmp(cmd, "powerOff")) {
    if (!argv[optind]) goto syntaxErr;
    {
      unsigned long sleepSecs = posInt(argv[optind++]);
      putu32(sysPwrOff+sysOffOffset, sleepSecs);
      if (argv[optind]) {
        shutdownDelay = posInt(argv[optind]);
        putu32(sysPwrOff+sysOnOffset, shutdownDelay);
      }
      setupPort();
      if (shutdownDelay)
        printf("In %u seconds, ", shutdownDelay);
      else
        sysPwrOff[1]=-3;  //go directly to "off" state.
      printf("System will power off");
      if (sleepSecs)
        printf(" for %u seconds\n", sleepSecs);
      else
        printf(" indefinately\n");
      sendCmd(sysPwrOff, sizeof sysPwrOff, "power off");
    }
  }else if (!strcasecmp(cmd, "none"))
    setupPort();
  else
    goto syntaxErr;
  return 0;
}
