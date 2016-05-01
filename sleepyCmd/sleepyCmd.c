/***************************  sleepyCmd.c  *********************************
 *  Copyright (C) 2016 MBARI
 *
 *  MBARI Proprietary Information. All rights reserved.
 *
 * Command line tool to send commands to ESP 2G sleepy microcontroller
 *  via serial commands to the I2C Gateway
 *   (on port /dev/I2Cgate by default)
 *
 * Note that this approach works only when the ESP application does not
 * control the I2C Gateway.  If the ESP app is active, commands must be
 * sent via the espclient tool, with something like this:
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
#define sysSwOffset (1)
static char sysPwrOff[] = { //turn off system (host) power
 0x89, -5,
 0, 0, 0, 0,
 0, 0, 0, 0
};

static char sysPwrQuery[] = {  //query system power status
  0x81, -1
};

static char getWake[] = { //get both wakeup and wake ack strings
  0x81, -7,
  0x81, -9
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
static unsigned wakeTimeout = 10;


static void usage (void)
{
  fprintf(stderr, "%s revised 4/6/16 brent@mbari.org\n", progName);
  fprintf(stderr, "\
Send a command to the ESP Sleepy microcontroller.\n\
Usage:  %s {options} [resetModem|powerOff|powerQuery|wakeString|none] {args}\n\
resetModem {offSeconds} --> turn off power to the ESP's modem to reset it.\n\
  offSeconds is the number of seconds modem shall be off\n\
  range:  0 to 120  #defaults to 5 seconds if unspecified\n\
powerOff sleepSeconds {shutdownDelay} --> turn off ESP host after shutdownDelay\n\
  sleepSeconds is number of seconds system shall sleep\n\
  shutdownDelay is number of seconds before power is shut off [default=%u]\n\
    (note that zero seconds for sleep or shutdown reads as \"indefinately\")\n\
powerQuery --> display power/sleep status\n\
wakeString {wakeString} {wakeAckString} --> set or display wake up strings\n\
    The host wakes up when the wakeup string received within timeout seconds\n\
    The wakeAck string is output when the host is powered on\n\
none       --> do nothing (useful with envPoll options described below)\n\
options:  (may be abbreviated)\n\
  -device=[path]   #defaults to /dev/I2Cgate\n\
  -wait=[delay]    #tenths of secs to delay for responses [%u]\n\
  -timeout=[%u]    #max seconds to wait for the wake up string\n\
  -skipGatewayInit #skip the (re-)configuration of the I2C gateway\n\
  -verbose{=level} #print debugging info\n\
  -envPoll=secs    #set environment sensor polling period before command\n\
  -quitEnvPoll     #quit environmental sensor polling before command\n\
  -help            #display this message\n\
",  progName, shutdownDelay, rspTimeout, wakeTimeout);
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


unsigned posInt(char *digits)
{
  char *end;
  unsigned long secs = strtoul(digits, &end, 10);
  if (*end) {
    fprintf(stderr, "\'%s\' is not a valid positive integer!\n", digits);
    exit(2);
  }
  return secs;
}


void putu32(unsigned char *u32, unsigned value)
/*
  put 32-bit value in network byte order (MSB first)
*/
{
  u32[3]=value;
  u32[2]=value>>=8;
  u32[1]=value>>=8;
  u32[0]=value>>=8;
}


unsigned getu32(unsigned char *buf)
/*
  return 32-bit value in network byte order (MSB first)
*/
{
  unsigned v=buf[0];
  v |= v<<8 | buf[1];
  v |= v<<8 | buf[2];
  return v<<8 | buf[3];
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
    {"timeout", 1, NULL, 't'},
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
      case 't':  //timeout in seconds for wakeup string
        {
          unsigned long secs = strtoul(optarg, &end, 10);
          if (*end)
            goto badarg;
          if (secs > 0xff) {
            fprintf(stderr,"%u > max allowed timeout of %u!\n", secs, 0xff);
            return 42;
          }
          wakeTimeout = secs;
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
      unsigned secs = posInt(argv[optind]);
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
      if (resetCmd[resetOffset] - rstSecs > 1) {
        fprintf(stderr, "Response of Gateway %s to modem reset was invalid!\n",
                devName, strerror(errno));
        return 16;
      }
      printf ("Modem will restart in %u seconds\n", rstSecs);
    }

  }else if (!strcasecmp(cmd, "powerOff")) {
    if (!argv[optind]) goto syntaxErr;
    {
      unsigned sleepSecs = posInt(argv[optind++]);
      putu32(sysPwrOff+sysOffOffset, sleepSecs);
      if (argv[optind])
        shutdownDelay = posInt(argv[optind]);
      putu32(sysPwrOff+sysOnOffset, shutdownDelay);
      setupPort();
      if (shutdownDelay)
        printf("In %u seconds, ", shutdownDelay);
      else
        sysPwrOff[sysSwOffset]=-3;  //go directly to "off" state.
      printf("System will power off");
      if (sleepSecs)
        printf(" for %u seconds\n", sleepSecs);
      else
        printf(" indefinately\n");
      sync();
      sendCmd(sysPwrOff, sizeof sysPwrOff, "power off");
    }

  }else if (!strcasecmp(cmd, "powerQuery")) {
    setupPort();
    sendCmd(sysPwrQuery, sizeof sysPwrQuery, "power query");
    rs232setup.c_cc[VMIN] = sizeof sysPwrOff;
    tcsetattr(rs232, TCSAFLUSH, &rs232setup);
    xfrd = read(rs232, sysPwrOff, sizeof sysPwrOff);
    if (xfrd != sizeof sysPwrOff) {
      fprintf(stderr, xfrd<0 ? "Cannot read I2C gateway %s: %s\n" :
                           "I2C Gateway %s did not respond to power query!\n",
              devName, strerror(errno));
      return 20;
    }
    {
      unsigned onSecs = getu32(sysPwrOff+sysOnOffset);
      offSecs = getu32(sysPwrOff+sysOffOffset);
      unsigned char pwrStatus = 0x100 - sysPwrOff[sysSwOffset];
      if (debug > 3)
        printf("state=%u, onSecs=%u, offSecs=%u\n", pwrStatus, onSecs, offSecs);
      if (pwrStatus > 3) {
        printf("System will stay powered");
        if (!onSecs)
          goto forever;
        printf(" for %u seconds, then switch off", onSecs);
        if (offSecs)
showoff:
          printf(" for %u seconds before switching on again", offSecs);
      }else{
        printf("System will remain off");
        if (offSecs)
          goto showoff;
forever:
        printf(" indefinately");
      }
      puts("");
    }

  }else if (!strcasecmp(cmd, "wakeString")) {
    unsigned char wakeBuf[550];
    unsigned wakeLen, ackLen, wakeTime;
    const char *wakeString = argv[optind++];
    if (wakeString) {  //set wake string, timeout and (optionally) ack string
      const char *ackString = argv[optind];
      unsigned char *cursor = wakeBuf;
      wakeLen=strlen(wakeString);
      if (wakeLen > 40) {
        printf("wakeup string too long (>40 chars)\n");
        return 21;
      }
      if (ackString) {
        ackLen=strlen(ackString);
        if (ackLen > 40) {
          printf("wakeup acknowlegment string too long (>40 chars)\n");
          return 21;
        }
      }else{
        ackString = "";
        ackLen=0;
      }
      setupPort();
      *cursor++ = 0x82+wakeLen;
      *cursor++ = -7;
      *cursor++ = wakeTimeout;
      memcpy(cursor, wakeString, wakeLen); cursor+=wakeLen;
      *cursor++ = 0x81+ackLen;
      *cursor++ = -8;
      memcpy(cursor, ackString, ackLen); cursor+=ackLen;
      sendCmd(wakeBuf, cursor-wakeBuf, "wakeup string");
      printf ("Wake up string is \"%s\" with timeout of %u seconds\n",
              wakeString, wakeTimeout);
      if (ackLen > 0)
        printf ("Wake acknowledge string is \"%s\"\n", ackString);

    }else{  //display wake and ack strings with timeout
      setupPort();
      sendCmd(getWake, sizeof getWake, "wakeup query");
      xfrd = read(rs232, wakeBuf, 1);
      if (xfrd != 1) {
        fprintf(stderr, xfrd<0 ? "Cannot read I2C gateway %s: %s\n" :
                          "I2C Gateway %s did not respond to wakeup query!\n",
                devName, strerror(errno));
        return 20;
      }
      wakeLen = wakeBuf[0] - 0x80;
      if (wakeLen > 127) {
        fprintf(stderr, "wake string length of %d is invalid!\n", wakeLen);
        return 20;
      }
      rs232setup.c_cc[VMIN] = wakeLen+1;  //include length of wakeack response
      tcsetattr(rs232, TCSANOW, &rs232setup);
      xfrd = read(rs232, wakeBuf+1, wakeLen+1);
      if (xfrd != wakeLen+1) {
        fprintf(stderr, xfrd<0 ? "Cannot read I2C gateway %s: %s\n" :
                          "I2C Gateway %s did not respond to wakeUp query!\n",
                devName, strerror(errno));
        return 20;
      }
      wakeTime = wakeBuf[2];
      ackLen = wakeBuf[wakeLen+1] - 0x80;
      if (ackLen > 127) {
        fprintf(stderr, "wake ack string length of %d is invalid!\n", ackLen);
        return 20;
      }
      wakeBuf[wakeLen+1] = '\0';  //terminate string

      rs232setup.c_cc[VMIN] = ackLen;
      tcsetattr(rs232, TCSANOW, &rs232setup);
      xfrd = read(rs232, wakeBuf+wakeLen+2, ackLen);
      if (xfrd != ackLen) {
        fprintf(stderr, xfrd<0 ? "Cannot read I2C gateway %s: %s\n" :
                          "I2C Gateway %s did not respond to wakeAck query!\n",
                devName, strerror(errno));
        return 20;
      }
      wakeBuf[wakeLen+ackLen+2] = '\0';
      if (wakeTime && wakeBuf[3]) {
        printf("To wake system, send \"%s\" within a %u second period\n",
                wakeBuf+3, wakeTime);
        if (wakeBuf[wakeLen+3])
          printf("System responds with \"%s\" to confirm\n", wakeBuf+wakeLen+3);
      }else
        printf("No wake up string is configured\n");
    }

  }else if (!strcasecmp(cmd, "none"))
    setupPort();
  else
    goto syntaxErr;
  return 0;
}
