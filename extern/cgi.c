/*
 * $Id: cgi.c,v 1.34 1998/06/08 14:44:06 grubba Exp $
 *
 * CGI-wrapper for Roxen.
 *
 * David Hedbor
 * Per Hedbor
 * Henrik Grubbström
 * and others.
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif /* HAVE_CONFIG_H */

#include <string.h>
#ifdef HAVE_STRINGS_H
#include <strings.h>
#endif /* HAVE_STRINGS_H */
#include <sys/types.h>
#include <stdio.h>
#ifdef HAVE_SIGNAL_H
#include <signal.h>
#endif /* HAVE_SIGNAL_H */
#include <sys/signal.h>
#include <sys/time.h>

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#ifdef HAVE_SYS_RESOURCE_H
#include <sys/resource.h>
#endif

#ifdef HAVE_SYS_WAIT_H
#include <sys/wait.h>
#endif

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
#endif

#ifndef HAVE_PIPE
#include <sys/socket.h>
#endif

#include <signal.h>


#ifndef MAXPATHLEN 
# define MAXPATHLEN  2048
#endif

#ifndef MAXHEADERLEN
/* maximum size of the header before sending and error message and
 * killing the script.
 */
# define MAXHEADERLEN 32769
#endif

/* #define DEBUG */

#include <errno.h>

/*  This is the PID of the child process (the CGI script) */
int pid;

/*  Indicates RAW-mode (for nph-scripts) */
int raw;

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

#define LONGHEADER "HTTP/1.0 500 Buggy CGI Script\r\n\
Content-Type: text/html\r\n\r\n\
<title>CGI-script error</title> \n\
<h1>CGI-script error</h1> \n\
The CGI script you accessed is not working correctly. It tried \n\
to send too much header data (probably due to incorrect separation between \n\
the headers and the body. Please notify the author of the script of this\n\
problem.\n"




/* This is stdout from the CGI script */
int script;

int start_program(char **argv)
{
  int fds[2];
  char *nice_val = getenv("ROXEN_CGI_NICE_LEVEL");
/* HAVE_SETRLIMIT */
#ifdef HAVE_SETRLIMIT
  char *more_options = getenv("ROXEN_CGI_LIMITS");
  if(more_options)
  {
    int limit=1;
    struct rlimit rl;
    char *p = malloc(strlen(more_options));

    while(limit!=-1)
    {
      int n;
      limit=-1;
      n = sscanf(more_options, "%[a-z_]:%d;%s", p, &limit, more_options);
      if(n==2) more_options="";
      rl.rlim_cur = limit;
      rl.rlim_max = limit;
      
      if(strlen(p) && limit >= 0)
      {
	switch(p[0])
	{
#ifdef RLIMIT_CORE
	 case 'c': /* core=... */
#ifdef DEBUG
	  fprintf(stderr, "core size limited to %d\n", rl.rlim_max);
#endif
	  setrlimit(RLIMIT_CORE, &rl);
	  break;
#endif
#ifdef RLIMIT_CPU
	 case 't': /* time=... */
#ifdef DEBUG
	  fprintf(stderr, "time limited to %d\n", rl.rlim_max);
#endif
	  setrlimit(RLIMIT_CPU, &rl);
	  break;
#endif
#ifdef RLIMIT_DATA
	 case 'd': /* data_size=... */
#ifdef DEBUG
	  fprintf(stderr, "data size limited to %d\n", rl.rlim_max);
#endif
	  setrlimit(RLIMIT_DATA, &rl);
	  break;
#endif
#ifdef RLIMIT_FSIZE
	 case 'f': /* file_size=... */
#ifdef DEBUG
	  fprintf(stderr, "file size limited to %d\n", rl.rlim_max);
#endif
	  setrlimit(RLIMIT_FSIZE, &rl);
	  break;
#endif
#ifdef RLIMIT_NOFILE
	 case 'o': /* open_files=... */
	  if(rl.rlim_max < 64) rl.rlim_max=rl.rlim_cur = 64;
#ifdef DEBUG
	  fprintf(stderr, "open files limited to %d\n", rl.rlim_max);
#endif
	  setrlimit(RLIMIT_NOFILE, &rl);
	  break;
#endif
#ifdef RLIMIT_STACK
	 case 's': /* stack=... */
#ifdef DEBUG
	  fprintf(stderr, "stack limited to %d\n", rl.rlim_max);
#endif
	  setrlimit(RLIMIT_STACK, &rl);
	  break;
#endif
#ifdef RLIMIT_VMEM
	 case 'm': /* mem_max=... */
#ifdef DEBUG
	  fprintf(stderr, "mem_max limited to %d\n", rl.rlim_max);
#endif
	  setrlimit(RLIMIT_VMEM, &rl);
	  break;
#endif
	}
      }
    }
    free(p);
  }
#endif

#ifdef HAVE_NICE
  if(nice_val) {
#ifdef DEBUG
    fprintf(stderr, "nice level set to %s\n", nice_val);
#endif
    nice(atoi(nice_val) - nice(0));
  }
#endif

  if (!raw) {
#ifdef HAVE_PIPE
    if (pipe(fds) != 0) {
#ifdef DEBUG
      perror("CGI: pipe() failed");
#endif /* DEBUG */
      exit(1);
    }
#else
#ifdef HAVE_SOCKETPAIR
    if (socketpair(AF_UNIX, SOCK_STREAM, 0, fds) != 0) {
#ifdef DEBUG
      perror("CGI: socketpair() failed");
#endif /* DEBUG */
      exit(1);
    }
#else
#error Bad luck.
#endif
#endif

    if((pid = fork())) {
      if (pid == -1) {
	int e = errno;

	fprintf(stderr, "CGI: fork() failed\n"
		"errno: %d\n", e);
#ifdef HAVE_PERROR
	perror("CGI");
#endif /* HAVE_PERROR */
	exit(1);
      }
      close(fds[1]);
      return fds[0];
    }

    close(fds[0]);
    dup2(fds[1], 1);
    close(fds[1]);
  }

  execv(argv[0], argv);

  fprintf(stderr, "Exec of %s failed\n", argv[0]);
  fprintf(stdout, "Exec of %s failed\n", argv[0]);
#ifdef HAVE_PERROR
  perror("CGI");
#endif /* HAVE_PERROR */

  exit(0);

  return 0; /*Keep all (at least most) compilers happy..*/
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

void reaper(int i)
{
  int status;

  /* Reap our child */
  if (pid && (wait(&status) != pid)) {
    /* Not dead yet */
    return;
  }
#ifdef DEBUG
  fprintf(stderr, "Child died\n");
  fprintf(stdout, "Child died\n");
#endif
  exit(0);
}

void kill_kill_kill(void)
{
#ifdef DEBUG
  fprintf(stderr, "kill kill kill\n");
#endif
  if(fork()) 
    exit(0);
  close(0);
  close(1);
  close(script);
  signal(SIGCHLD, reaper);
  kill(pid, 1);		/* HUP */
  sleep(3);
  kill(pid, 13);	/* PIPE */
  sleep(3);
  kill(pid, 2);		/* INT */
  sleep(3);
  kill(pid, 15);	/* TERM */
  sleep(3);
  kill(pid, 9);		/* KILL */
  exit(0);
}

void send_data(char *bar, int re)
{
  int written;
  do
  {
    written = write(1, bar, re);
#ifdef DEBUG
    fprintf(stderr, "wrote %d bytes to client\n", written);
#endif

    if(written <= 0)
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


char *is_end_of_headers(char *s, int len)
{
  char *end_of_header;

  if(!headers) 
  {
    hpointer = 0;
    hsize = (len/1024+1)*1024;
    headers = malloc(hsize);
    if ((s[0] == '\r') || (s[0] == '\n')) {
      /* No headers. */
      movemem(headers, s, len);
      hpointer = len;
      headers[hpointer] = 0;
      return(headers);
    }
  } else if(hsize <= hpointer+len) {
    headers = my_realloc(headers, (hpointer+len)*2+1, hsize);
    hsize = (hpointer+len)*2;
  }
  if(hsize > MAXHEADERLEN) {
    send_data(LONGHEADER, strlen(LONGHEADER));
    kill_kill_kill();
  }
    
  
  movemem(headers + hpointer, s, len);
  hpointer += len;
  headers[hpointer] = 0;

  end_of_header = strstr(headers, "\r\n\r\n");
  if (!end_of_header) {
    end_of_header = strstr(headers, "\n\n");
  }
  if (!end_of_header) {
    end_of_header = strstr(headers, "\n\r\n\r");
  }
  return(end_of_header);
}


void parse_and_send_headers(char *header_end)
{
  char *error, *pointer = NULL;
  if(headers)
  {
    if(((error=strstr(headers, "status:")) || 
	(error=strstr(headers, "Status:")))
       && error==headers)
    {
      char *tmp;
      int skip;
      pointer = error;
      while(*error!=' ' && *error != ':') error++;
      while(*error==' ' || *error == ':') error++;
      tmp=error;
      while(*tmp!='\n' && *tmp!='\r') tmp++;
      if ((*tmp == '\n' && tmp[1] == '\r') ||
	  (*tmp == '\r' && tmp[1] == '\n'))
	skip = 2;
      else
	skip = 1;
      
      send_data("HTTP/1.0 ", 9);
      send_data(error, tmp - error);
      send_data("\r\n", 2);
      /*  send_data(headers, hpointer-headers);*/
      send_data(tmp+skip, hpointer-(tmp+skip-headers));
      free(headers);
      return;
    }
    if(((pointer = strstr(headers, "Location:")) &&
	(!header_end || (pointer < header_end))) ||
       ((pointer = strstr(headers, "location:")) &&
	(!header_end || (pointer < header_end)))) {
#ifdef DEBUG
      fprintf(stderr, "Redirect: pointer:%p, header_end:%p, headers:%p\n",
	      pointer, header_end, headers);
#endif /* DEBUG */
	      
      error = "HTTP/1.0 302 Redirect\r\n";
    } else {
      error = "HTTP/1.0 200 Ok\r\n";
    }
  } else
    error = "HTTP/1.0 200 Ok\r\n";
  
  send_data(error, strlen(error));
  if(headers)
  {
    send_data(headers, hpointer);
    free(headers);
  }
/*  send_data("\n", 1);*/
  return;
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

int main(int argc, char **argv)
{
  int i;
  /* Insure that all filedecriptors except stdin, stdout and stderr are closed
   */
  for (i=3; i < MAX_OPEN_FILEDESCRIPTORS; i++) {
    close(i);
  }

  /* We want to die of SIGPIPE */
  signal(SIGPIPE, SIG_DFL);

  /* Do not allow root execution
   *
   * This is probably already fixed in Roxen,
   * but two levels of security are better than one.
   */
  if(!geteuid()) {
    printf("Execution of CGI-scripts as root is disabled\n");
    exit(1);
  }
  if(!getuid()) {
    int euid = geteuid();
    int egid = getegid();
#if defined(HAVE_SETRESUID) && !defined(HAVE_SETEUID)
    setresgid(egid, egid, -1);
    setresuid(euid, euid, -1);
#else
#ifdef HAVE_SETEUID
    seteuid(0);
#else
    /* No way to change euid, so we don't */
#endif /* HAVE_SETEUID */
    setgid(egid);
    setuid(euid);
#endif /* HAVE_SETRESUID */
  }
  if(!getuid()) {
    printf("Couldn't change uid from root.\n");
    exit(1);
  }
  
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

  raw = is_nph(argv[1]);
  script = start_program(argv+1);

  while(1)
  {
    int re;
    char foo[2049], *bar;
    
    do {
      re = read(script, foo, 2048);
    } while((re < 0) && (errno == EINTR));

    if(re <= 0)
    {
#ifdef DEBUG
      perror("read failed");
#endif
      if(!raw) parse_and_send_headers(NULL);
      kill(pid, 9);
      close(0); close(1); close(2);
      exit(0);
    }
    foo[re]=0;
#ifdef DEBUG
    fprintf(stderr, "read %s\n", foo);
#endif

    bar=foo;
    
    if(!raw)
    {
      char *header_end;
      if((header_end = is_end_of_headers(foo, re))) {
	parse_and_send_headers(header_end);
	raw = 1;
      }
    } else 
      send_data(bar, re);
  }
}
