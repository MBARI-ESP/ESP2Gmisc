/*
  Quicky 'C' program to run the a shell script as another user
  brent@mbari.org 3/16/16
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#define SUDIR   "/suscript/"
#define SUFFIX  ""
#define SUFFIXLEN 0  //sizeof(SUFFIX)-1

int main (int argc, char *const argv[])
{
  char *cmdName = strrchr (*argv, '/');
  cmdName = cmdName ? cmdName+1 : *argv;
  size_t cmdLen = strlen(cmdName);
  char *scriptPath = malloc(sizeof(SUDIR)+cmdLen+sizeof(SUFFIXLEN));
  if (!scriptPath) {
    fprintf(stderr, "out of memory");
    exit(2);
  }

  strcpy(scriptPath, SUDIR);
  strcpy(scriptPath+sizeof(SUDIR)-1, cmdName);
#if SUFFIXLEN
  strcpy(scriptPath+sizeof(SUDIR)-1+cmdLen, SUFFIX);
#endif

  if (setuid (0)) {
    fprintf(stderr, "%s must be installed suid root!\n", argv[0]);
    exit(3);
  }
  clearenv();
  execv(scriptPath, argv);  /* pass thru all the arguments */
  fprintf(stderr, "%s: Cannot exec %s -- %s\n", 
          cmdName, scriptPath, strerror(errno));
  exit(1);
}
