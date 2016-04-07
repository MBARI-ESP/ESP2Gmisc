/*
  Quicky 'C' program to run the a shell script as another user
  brent@mbari.org 3/17/16
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/stat.h>
#include <unistd.h>
#include <pwd.h>

#define SUDIR   "/suscript/"
#define SUFFIX  ""
#define SUFFIXLEN 0  //sizeof(SUFFIX)-1

int main (int argc, char *const argv[])
{
  struct stat info;
  struct passwd *user;
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

  clearenv();
  if (access(scriptPath, X_OK) || stat(scriptPath, &info)) {
    perror(scriptPath);  //real user must have permission to execute script!
    exit(4);
  }
  if (setuid(0)) {
    fprintf(stderr, "%s is not installed suid root!\n", argv[0]);
    exit(3);
  }
  if (user=getpwuid(info.st_uid))
    setgid(user->pw_gid);
  if (setuid(info.st_uid)) {
    fprintf(stderr, "%s: Cannot assume owner's identity -- %s\n",
                    scriptPath, strerror(errno));
    exit(5);
  }
  execv(scriptPath, argv);  /* pass thru all the arguments */
  fprintf(stderr, "%s: Cannot exec %s -- %s\n",
                  cmdName, scriptPath, strerror(errno));
  exit(1);
}
