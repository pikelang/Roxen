/* SSL frontend for Roxen. Forking since the SSL library developed
 * by Eric Young (eay@mincom.oz.au) does not really support
 * multithreding of select-based non-blocking I/O, yet.
 * 
 * This program will basically just connect to the Roxen server,
 * as specified on the command line, each time it gets a (SSL) connection
 * on the listen port (also specified on the command line).
 * 
 * It will then send the IP-number of the remote client, followed by a
 * NULL (0) character, and then establish a two-way pipe between the
 * client and the server.
 */

#define ssl_context SSL_CTX
#define forever()  for(;;)

#include <sys/types.h>
#include <sys/socket.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>
#include <ssl.h>
#include <stdlib.h>
#include <pem.h>
#include <err.h>
#include <x509.h>
#include <netdb.h>


#ifdef HAVE_SYS_MMAN_H
#  include <sys/mman.h>
#else
# ifdef HAVE_LINUX_MMAN_H
#   include <linux/mman.h> /* ¤##%¤#% Linux */
# else
#  ifdef HAVE_MLOCKALL
#   include <sys/mman.h>
#  endif
# endif
#endif

#ifdef HAVE_SYS_LOCK_H
#include <sys/lock.h>
#endif

#ifndef HAVE_MEMSET
char *MEMSET(char *s,int c,int n)
{
  char *t;
  for(t=s;n;n--) *(s++)=c;
  return s;
}
#else
#define MEMSET(s, c, n) memset(s, c, n)
#endif

struct sockaddr_in server;
ssl_context *context;
int fd; /* My own listen FD. */

/* Connect to the server specified by the one starting this little process.
 * Returns the filedescriptor of the connection
 */
int connect_to_server()
{
  int fd;

  if((fd = socket(AF_INET, SOCK_STREAM, 0)) == -1)
  {
    perror("Failed to connect to server: Socket");
    return 0;
  }
  if(connect(fd, (struct sockaddr *)&server, sizeof(server)))
  {
    perror("Failed to connect to server: Connect");
    return 0;
  }
  return fd;
}


/* NOT mt safe... */
char *find_hostname(char *from)
{
  struct hostent *h;

  if((h = gethostbyname( from )))
  {
    struct in_addr in;
    in.s_addr = ((unsigned int *)(h->h_addr_list[0]))[0];
    return inet_ntoa(in);
  }
  return 0;
}


/* Initialize the 'server' structure (sockaddr_in) from the 
 * arguments specified by the user.
 *
 * Return 1 on success.
 *
 * The current implementation only use numerical IP-numbers, since I only
 * use 127.0.0.1, a.k.a. localhost.. :-)
 */
int find_server(char *name, int port)
{
  unsigned int addr;
  if(!strcmp(name, "ANY"))
    addr = INADDR_ANY;
  else if((addr=inet_addr(name)) == -1)
    if(!(name = find_hostname(name))
       || ((addr=inet_addr(name))==-1))
      return 0;

  server.sin_family=AF_INET;
  server.sin_addr.s_addr = addr;
  server.sin_port = htons(port);
  return 1;
}


/* Should do it */
#define BUFFER 65535 

static char *key_file, *cert_file;

#ifdef DEBUG
# define PEER_DEBUG
#endif

void got_connection(int s, int server_fd)
{
  char read_buffer[BUFFER];
  int amount, nfds;
  fd_set fds;
  SSL *con;

  con=(SSL *)SSL_new(context);
  SSL_set_verify(con,SSL_VERIFY_NONE, NULL);
  if(cert_file)
  {
    if(SSL_use_certificate_file(con, cert_file, X509_FILETYPE_PEM)<=0)
    {
      fprintf(stderr, "SSL: Failed using certificate file!\n");
      ERR_print_errors_fp(stderr);
      return;
    }
    if(!key_file)
      key_file = cert_file;
    if (SSL_use_RSAPrivateKey_file(con, key_file, SSL_FILETYPE_PEM) <= 0)
    {
      fprintf(stderr,"SSL: UNABLE to set private key file\n");
      ERR_print_errors_fp(stderr);
    }
  }
  SSL_clear(con);
  SSL_set_fd(con, s);

  if(SSL_accept(con) <= 0)
  {
    /* perror("SSL_accept");*/
    ERR_print_errors_fp(stderr);
    SSL_free(con);
    return;
  }

#ifdef PEER_DEBUG
  {
    X509 *peer;
    PEM_write_SSL_SESSION(stdout,SSL_get_session(con));
    peer=SSL_get_peer_certificate(con);
    if (peer != NULL)
    {
      char *str;
      printf("Client certificate\n");
      PEM_write_X509(stdout,peer);
      str=X509_NAME_oneline(X509_get_subject_name(peer));
      if(str)
      {
	printf("subject=%s\n",str);
	free(str);
      }
	  
      str=X509_NAME_oneline(X509_get_issuer_name(peer));
      if(str)
      {
	printf("issuer=%s\n",str);
	free(str);
      }
      X509_free(peer);
    }
    printf("CIPHER is %s\n",SSL_get_cipher(con));
  }
#endif

  if(server_fd > s)
    nfds = server_fd+1;
  else
    nfds = s+1;

  while(1)
  {
    int written;
    FD_ZERO(&fds); /* Faster than copying from another variable. Tested. */
    FD_SET(server_fd, &fds);
    FD_SET(s, &fds);
    if((written=select(nfds, &fds, 0, 0, 0)) == -1)
    {
      if(errno == EINTR)
	continue;
      break;
    }
	   
    if(FD_ISSET(server_fd, &fds)) /* Data from server to client.. */
    {
      amount = read(server_fd, read_buffer, BUFFER);
      if(amount <= 0)
      {
	switch(errno)
	{
	 case EAGAIN: case EINTR:
	  continue;
	 default:
	  break;
	}
      }
      while((written = SSL_write(con, read_buffer, amount)) == -1)
      {
	switch(errno)
	{
	 case EAGAIN:
	 case EINTR:
	  continue;
	 default:
	  SSL_free(con);
	  return;
	}
      }
    } else {
      amount = SSL_read(con, read_buffer, BUFFER);
      if(amount <= 0)
      {
	switch(errno)
	{
	 case EAGAIN: case EINTR:
	  continue;
	 default:
	  break;
	}
      }
      while((written = write(server_fd, read_buffer, amount)) == -1)
      {
	switch(errno)
	{
	 case EAGAIN:
	 case EINTR:
	  continue;
	 default:
	  SSL_free(con);
	  return;
	}
      }
    }
  }
  SSL_free(con);
  return;
}    


int open_listen_socket(char *on, int port)
{
  struct sockaddr_in me;
  int s;

  if(strcmp(on, "ANY"))
    if(inet_addr(on) == -1)
      if(!(on = find_hostname(on)) || (inet_addr(on)==-1))
	return 0;

  MEMSET((char *)&me, 0, sizeof(struct sockaddr_in));
  me.sin_family=AF_INET;
  me.sin_port=htons(port);

  fprintf(stderr, "SSL: Listening on %s, port %d\n", on, port);
  
  if(!strcmp(on, "ANY"))
    me.sin_addr.s_addr=htonl(INADDR_ANY);
  else
    me.sin_addr.s_addr=inet_addr(on);
    
  if((s=socket(AF_INET,SOCK_STREAM,0))==-1)
  {
    perror("socket");
    return 0;
  }

  port = 1;
  setsockopt(s, SOL_SOCKET, SO_REUSEADDR, (char *)&port, sizeof(int));

  if(bind(s, (struct sockaddr *)&me, sizeof(me)) == -1)
  {
    perror("bind");
    return 0;
  }

  if(listen(s, 5000) == -1) 
  {
    perror("listen");
    return 0;
  }
  
  return s;
}

int parse_args(int argc, char **argv)
{
  while (argc)
  {
    if(!strcmp(*argv,"--server")) 
    {
      argc -= 2;
      if (argc<0) {
	fprintf(stderr, "To few arguments to --server.\n");
	return 0;
      }
      find_server(*(argv+1), atoi(*(argv+2))); argv+=2;
    } else if(!strcmp(*argv,"--resident")) {
      /* If possible, keep pages in phys. memory.
       * This will speed up response times on busy
       * computers that have to little memory
       */
#ifdef HAVE_PLOCK
      plock(PROCLOCK);
#else
#ifdef HAVE_MLOCKALL
      mlockall(MCL_CURRENT);
#endif
#endif
    } else if(!strcmp(*argv,"--listen")) {
      argc -= 2;
      if (argc<1) {
	fprintf(stderr, "To few arguments to --listen.\n");
	return 0;
      }
      if(fd) close(fd); 
      argv+=2;
      if(!(fd=open_listen_socket(*(argv-1), atoi(*(argv)))))
      {
	fprintf(stderr, "Failed to open listen socket (%s:%s)\n",
		*(argv-1), *(argv-0));
	return 0;
      }
    } else if(!strcmp(*argv,"--cert-file")) {
      if (--argc<1) {
	fprintf(stderr, "To few arguments to --cert-file.\n");
	return 0;
      }
      cert_file = *++argv;
    } else if(!strcmp(*argv,"--key-file")) {
      if (--argc < 1) {
	fprintf(stderr, "To few arguments to --key-file.\n");
	return 0;
      }
      key_file = *(++argv);
    } else {
      /* Unknown option.. */
      fprintf(stderr, "SSL: Unknown option %s.\n", *argv);
    }
    argv++; argc--;
  }
  return 1;
}

int next_accept(int from, char **name)
{
  int fd;
  struct sockaddr_in foo;
  int len;

  {
    fd_set wait_for;
    FD_ZERO(&wait_for);
    FD_SET(0, &wait_for);
    FD_SET(from, &wait_for);
    while(select(from+1, &wait_for, 0, 0, 0) == -1)
    {
      switch(errno)
      {
      case EBADF:
	fprintf(stderr, "SSL: Exiting (badfd in select, roxen dead?).\n");
	exit(0);
	break;

      case EINVAL:
	fprintf(stderr, "Impossible error in select.\n");
	abort();
	
      case EINTR: /* Just continue .. */
       continue;
      }
    }
    

#if 0
    /* This did not work on Linux */
    if(FD_ISSET(0, &wait_for))
    {
/*      fprintf(stderr, "SSL: Exiting.\n");
      exit(0); */
    }
#endif
  }
  
  len = sizeof(foo);
  while(((fd = accept(from, (struct sockaddr *)&foo, &len))==-1)
	&& ((errno==EAGAIN) || (errno==EINTR)));
  if(fd==-1)
  {
    perror("accept");
    return 0;
  }
  *name = inet_ntoa(foo.sin_addr);
  return fd;
}

static RETSIGTYPE reaper(int arg)
{
  /* We carefully reap what we saw */
#ifdef HAVE_WAITPID
  while(waitpid(-1,0,WNOHANG) > 0); 
#else
#ifdef HAVE_WAIT3
  while(wait3(0,WNOHANG,0) > 0);
#else
#ifdef HAVE_WAIT4
  while(wait4(-1,0,WNOHANG,0) > 0);
#else

  /* Bugger */

#endif /* HAVE_WAIT4 */
#endif /* HAVE_WAIT3 */
#endif /* HAVE_WAITPID */

#ifdef SIGNAL_ONESHOT
  signal(SIGCHLD, reaper);
#endif
}

/* So shoot me.. I am tired of the names 'argc' and 'argv' */
int main(int nargs, char *args[])
{
  char *addr;
  int res;
  SSL_load_error_strings();
  server.sin_port = 0;

  if(!(context = SSL_CTX_new()))
  {
    puts("Failed to allocate a context!\n");
    return 1;
  }


  res = parse_args(nargs-1,args+1);
#ifndef ITS_OK
/* This should _never_ happen. The certificate file and the rest of
 * the arguments are supplied by Roxen But, a file could have been
 * removed, or something else could have failed..  
 */
  if(!res)
  {
    fprintf(stderr, "SSL: Illegal argument\n");
    exit(-1);
  }
  
  if(cert_file == NULL)
  { 
    fprintf(stderr,"SSL: No certificate. Exiting.\n");
    exit(-1);
  }

  if(!SSL_set_default_verify_paths(context))
  {
    fprintf(stderr, "SSL: Cannot load verify locations.\n");
    exit(-1);
  }

  if(!server.sin_port)
  {
    fprintf(stderr, "SSL: No remote server was specified.\n");
    exit(-1);
  }
#endif
  signal(SIGCHLD, reaper);

  forever()
  {
    int nfd, sfd;
    
    if(write(1,&nfd,0) != 0) exit(0); /* Stdout closed, Roxen is dead. */

    if(!(nfd = next_accept(fd, &addr))) /* addr will be sent to server. */
      return 0;

    if(!(sfd = connect_to_server()))
      return 0;

    if(!fork()) /* I do not like this either. */
    {
      write(sfd, addr, strlen(addr)+1); /* The \0 _should_ be sent. */
      /* The peer info should be sent in the 'got_connection' function.. */
      /* Not currently done. */
      got_connection(nfd, sfd);
      return 0;
    } else {
      close(nfd);
      close(sfd);
    }
  }
}
