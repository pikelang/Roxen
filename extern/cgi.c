#include <string.h>
#include <sys/types.h>
#include <stdio.h>
#include <sys/signal.h>

#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

#if defined(HAVE_POLL) && defined(HAVE_POLL_H)
#ifdef HAVE_STROPTS_H
#include <stropts.h>
#endif
#include <poll.h>
#else
#include <sys/time.h>
#endif

#ifndef HAVE_PIPE
#include <sys/socket.h>
#endif

#include <signal.h>


#ifndef MAXPATHLEN 
# define MAXPATHLEN  2048
#endif

/*  This is the PID of the child process (the CGI script) */
int pid;

/* These variables are here to keep track of the headers sent from all
 * non-nph scripts. At the very least they will include a Content-type.
 * Optionally, an Location: or Status: header might be supplied.
 * headers is a pointer to some memory of size hsize, and hpointer is
 * the end of the last written data in that memory.
 */

char *headers = NULL; /* To make people happy :-) */
int hpointer, hsize;

/* All say "HI!" to compatibility.. */
#if defined(HAVE_POLL) && defined(HAVE_POLL_H)
struct pollfd pollfds[1];
#else
fd_set writefd[1];
#endif


/* This is stdout from the CGI script */
int script;

int start_program(char **argv)
{
  int fds[2];

#ifdef HAVE_PIPE
  pipe(fds);
#else
#ifdef HAVE_SOCKETPAIR
  socketpair(AF_UNIX, SOCK_STREAM, 0, fds);
#else
#error Bad luck.
#endif
#endif

  if((pid = fork()))
  {
    close(fds[1]);
    return fds[0];
  }
  close(fds[0]);
  dup2(fds[1], 1);
  execv(argv[0], argv);
  exit(0);
  return 0;
}


#ifdef HAVE_MEMCPY
#define movemem(to,from,size)   memcpy(to, from, size)
#else
#ifdef HAVE_MEMMOVE
#define movemem(to,from,size)   memmove(to, from, size)
#else
#ifdef HAVE_BCOPY
#define movemem(to,from,size)   bcopy(from, to, size)
#else
#define movemem(to,from,size)\
        do{ int _i; for(_i=0; _i<size; _i++) to[_i]=from[_i]; } while(0)
#endif
#endif
#endif

#ifndef HAVE_REALLOC
char *my_realloc(char *from, int nsize, int osize)
{
  char *tmp;
  tmp=malloc(nsize);
  movemem(from, tmp, osize);
  free(from);
  return tmp;
}
#else
char *my_realloc(char *from, int nsize, int osize)
{
  return realloc(from, nsize);
}
#endif

int is_end_of_headers(char *s, int len)
{
  if(!headers) 
  {
    hsize = (len/1024+1)*1024;
    headers = malloc(hsize);
    hpointer = 0;
  } else if(hsize <= hpointer+len) {
    headers = my_realloc(headers, hsize*2, hsize);
    hsize *= 2;
  }

  movemem(headers+hpointer, s, len);
  hpointer += len;
  headers[hpointer] = 0;

  return (strstr(headers, "\n\n")||strstr(headers, "\r\n\r\n")||strstr(headers, "\n\r\n\r"));
}

void reaper(int i) { exit(0); }

void kill_kill_kill()
{
  if(fork()) 
    exit(0);
  close(0);
  close(1);
  close(script);
  signal(SIGCHLD, reaper);
  kill(pid, 1);
  sleep(10);
  kill(pid, 9);
  exit(0);
}

void send_data(char *bar, int re)
{
  int written;
  do
  {
    written = write(1, bar, re);

    if(written < 0)
      kill_kill_kill();

    if(!written)
    {
#if defined(HAVE_POLL) && defined(HAVE_POLL_H)
      poll(pollfds, 1, 1000);
#else
      select(2, 0, writefd, 0, NULL);
#endif
    } else {
      bar += written;
      re -= written;
    }
  } while(re);
}

int parse_and_send_headers()
{
  char *error, *pointer;
  if(headers)
  {
    if(((error=strstr(headers, "status:")) || 
	(error=strstr(headers, "Status:")))
       && error==headers)
    {
      char *tmp;
      pointer = error;
      while(*error!=' ') error++;
      while(*error==' ') error++;
      tmp=error;
      while(*tmp!='\n') tmp++;
      
      send_data("HTTP/1.0 ", 9);
      send_data(error, tmp-error+1);
      /*  send_data(headers, pointer-headers);*/
      send_data(tmp+1, hpointer-(tmp-headers));
      free(headers);
      return 1;
    }
    if(strstr(headers, "Location:") || strstr(headers, "location:"))
      error = "HTTP/1.0 302 Document Found\n";
    else
      error = "HTTP/1.0 200 Ok\n";
  } else
    error = "HTTP/1.0 200 Ok\n";
  
  send_data(error, strlen(error));
  if(headers)
  {
    send_data(headers, hpointer);
    free(headers);
  }
/*  send_data("\n", 1);*/
  return 1;
}


/* NPH, also known as No Parse Headers. Thanks, CGI for that very.. Eh.... nice
 * standard.
 */

int is_nph(char *foo)
{
  int len;
  for(len=strlen(foo)-1; len>=0; len--) 
    if(foo[len] == '/') 
      break;
  len++;
  if(strlen(foo+len)<3) return 0;
  return !(strncmp(foo+len, "nph", 3));
}

void main(int argc, char **argv)
{
  int raw;
  
  if(argc==1)
  {
    printf("Syntax: %s binary args\n", argv[0]);
    exit(0);
  }

#if defined(HAVE_POLL) && defined(HAVE_POLL_H)
  pollfds[0].fd = 1;
  pollfds[0].events = POLLOUT;
#else
  FD_ZERO(writefd);
  FD_SET(1, writefd);
#endif

  script = start_program(argv+1);
  raw = is_nph(argv[1]);

  while(1)
  {
    int re;
    char foo[2048], *bar;
    
    re = read(script, foo, 2048);

    if(re <= 0)
    {
      if(!raw) parse_and_send_headers();
      kill(pid, 9);
      close(0);
      close(1);
      exit(0);
    }

    bar=foo;
    
    if(!raw)
    {
      if(is_end_of_headers(foo, re)) 
	raw = parse_and_send_headers();
    } else 
      send_data(bar, re);
  }
}
