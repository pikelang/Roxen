/* 
 * cgifcgi.c --
 *
 *	CGI to FastCGI bridge
 *
 *
 * Copyright (c) 1996 Open Market, Inc.
 *
 * See the file "LICENSE.TERMS" for information on usage and redistribution
 * of this file, and for a DISCLAIMER OF ALL WARRANTIES.
 *
 */

#ifndef lint
static const char rcsid[] = "$Id: cgi-fcgi.c,v 1.3 1997/05/09 17:24:01 grubba Exp $";
#endif /* not lint */

#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <ctype.h>
#include <netdb.h>
#include <sys/time.h>
#include <sys/param.h>

#include "fcgimisc.h"
#include "fcgiapp.h"
#include "fcgiappmisc.h"
#include "fastcgi.h"
#include "fcgi_config.h"

/*
 * Some things to make this a bit more portable
 *
 * Henrik Grubbström 1996-12-22
 */

#ifndef STDIN_FILENO
#define STDIN_FILENO 0
#endif /* STDIN_FILENO */

#ifndef STDOUT_FILENO
#define STDOUT_FILENO 1
#endif /* STDOUT_FILENO */

#ifndef STDERR_FILENO
#define STDERR_FILENO 2
#endif /* STDERR_FILENO */

#ifndef O_NONBLOCK
#ifdef FNDELAY
#define O_NONBLOCK FNDELAY
#else
#ifdef O_NDELAY
#define O_NONBLOCK O_NDELAY
#else
#error Insert your nonblock method here
#endif /* O_NDELAY */
#endif /* FNDELAY */
#endif /* O_NONBLOCK */


#ifndef MAXPATHLEN 
# define MAXPATHLEN  2048
#endif


/*
 * Simple buffer (not ring buffer) type, used by all event handlers.
 */
#define BUFFLEN 8192
typedef struct {
    char *next;
    char *stop;
    char buff[BUFFLEN];
} Buffer;

/*
 *----------------------------------------------------------------------
 *
 * GetPtr --
 *
 *      Returns a count of the number of characters available
 *      in the buffer (at most n) and advances past these
 *      characters.  Stores a pointer to the first of these
 *      characters in *ptr.
 *
 *----------------------------------------------------------------------
 */

static int GetPtr(char **ptr, int n, Buffer *pBuf)
{
    int result;
    *ptr = pBuf->next;
    result = min(n, pBuf->stop - pBuf->next);
    pBuf->next += result;
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * MakeHeader --
 *
 *      Constructs an FCGI_Header struct.
 *
 *----------------------------------------------------------------------
 */
static FCGI_Header MakeHeader(
        int type,
        int requestId,
        int contentLength,
        int paddingLength)
{
    FCGI_Header header;
    ASSERT(contentLength >= 0 && contentLength <= FCGI_MAX_LENGTH);
    ASSERT(paddingLength >= 0 && paddingLength <= 0xff);
    header.version = FCGI_VERSION_1;
    header.type             =  type;
    header.requestIdB1      = (requestId      >> 8) & 0xff;
    header.requestIdB0      = (requestId          ) & 0xff;
    header.contentLengthB1  = (contentLength  >> 8) & 0xff;
    header.contentLengthB0  = (contentLength      ) & 0xff;
    header.paddingLength    =  paddingLength;
    header.reserved         =  0;
    return header;
}

/*
 *----------------------------------------------------------------------
 *
 * MakeBeginRequestBody --
 *
 *      Constructs an FCGI_BeginRequestBody record.
 *
 *----------------------------------------------------------------------
 */
static FCGI_BeginRequestBody MakeBeginRequestBody(
        int role,
        int keepConnection)
{
    FCGI_BeginRequestBody body;
    ASSERT((role >> 16) == 0);
    body.roleB1 = (role >>  8) & 0xff;
    body.roleB0 = (role      ) & 0xff;
    body.flags = (keepConnection) ? FCGI_KEEP_CONN : 0;
    memset(body.reserved, 0, sizeof(body.reserved));
    return body;
}

/*
 *----------------------------------------------------------------------
 *
 * SetFlags --
 *
 *      Sets selected flag bits in an open file descriptor.
 *
 *----------------------------------------------------------------------
 */
static void SetFlags(int fd, int flags)
{
    int val;
    if((val = fcntl(fd, F_GETFL, 0)) < 0) {
        exit(errno);
    }
    val |= flags;
    if(fcntl(fd, F_SETFL, val) < 0) {
        exit(errno);
    }
}

static int appServerSock;  /* Socket connected to FastCGI application,
                            * used by AppServerReadHandler and
                            * AppServerWriteHandler. */
static Buffer fromAS;      /* Bytes read from the FCGI application server. */
static FCGI_Header header; /* Header of the current record.  Is global
                            * since read may return a partial header. */
static int headerLen = 0;  /* Number of valid bytes contained in header.
                            * If headerLen < sizeof(header),
                            * AppServerReadHandler is reading a record header;
                            * otherwise it is reading bytes of record content
                            * or padding. */
static int contentLen;     /* If headerLen == sizeof(header), contentLen
                            * is the number of content bytes still to be
                            * read. */
static int paddingLen;     /* If headerLen == sizeof(header), paddingLen
                            * is the number of padding bytes still
                            * to be read. */
static int requestId;      /* RequestId of the current request.
                            * Set by main. */
static FCGI_EndRequestBody erBody;
static int readingEndRequestBody = FALSE;
                           /* If readingEndRequestBody, erBody contains
                            * partial content: contentLen more bytes need
                            * to be read. */
static int exitStatus = 0;
static int exitStatusSet = FALSE;

/* Roxen specific code here... */
#ifdef HAVE_MEMMOVE
#define movemem(to,from,size)   memmove(to, from, size)
#else
#ifdef HAVE_MEMCPY
#define movemem(to,from,size)   memcpy(to, from, size)
#else
#define movemem(to,from,size)   bcopy(from, to, size)
#endif
#endif

#ifndef HAVE_REALLOC
static char *my_realloc(char *from, int nsize, int osize)
{
  char *tmp;
  tmp=malloc(nsize);
  movemem(from, tmp, osize);
  free(from);
  return tmp;
}
#else
static char *my_realloc(char *from, int nsize, int osize)
{
  return realloc(from, nsize);
}
#endif

char *headers = NULL;   /* To make people happy :-) */
int hpointer=0, hsize=0;

      
static void send_data(char *bar, int re)
{
  int written;
  do
  {
    written = write(1, bar, re);

    if(written <= 0)
      exit(0);
    bar += written;
    re -= written;
  } while(re);
}

static int parse_and_send_headers(void)
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
      error = "HTTP/1.0 302 Document Found\r\n";
    else
      error = "HTTP/1.0 200 Ok\r\n";
  } else
    error = "HTTP/1.0 200 Ok\r\n";
  
  send_data(error, strlen(error));
  if(headers)
  {
    send_data(headers, hpointer);
    free(headers);
  } else
    send_data("\r\n", 1);
  return 1;
}

static int is_end_of_headers(char *s, int len)
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

  movemem((headers+hpointer), s, len);
  hpointer += len;
  headers[hpointer] = 0;

  return (strstr(headers, "\n\n")
	  || strstr(headers,"\r\n\r\n")
	  || strstr(headers, "\n\r\n\r"));
}

/*
 *----------------------------------------------------------------------
 *
 * AppServerReadHandler --
 *
 *      Reads data from the FCGI application server and (blocking)
 *      writes all of it to the Web server.  Exits the program upon
 *      reading EOF from the FCGI application server.  Called only when
 *      there's data ready to read from the application server.
 *
 *----------------------------------------------------------------------
 */

static void AppServerReadHandler(void)
{
  int count;
  char *ptr;

    fromAS.next = &fromAS.buff[0];
    count = read(appServerSock, fromAS.next, BUFFLEN);
    if(count <= 0) {
      if(count < 0) {
	parse_and_send_headers();
	exit(errno);
      }
      if(headerLen > 0 || paddingLen > 0) {
	parse_and_send_headers();
	exit(FCGX_PROTOCOL_ERROR);
      }
      /*
       * XXX: Shouldn't be here if exitStatusSet.
       */
      exit((exitStatusSet) ? exitStatus : FCGX_PROTOCOL_ERROR);
    }
    fromAS.stop = fromAS.next + count;
    while(fromAS.next != fromAS.stop) {
        /*
         * fromAS is not empty.  What to do with the contents?
         */
        if(headerLen < sizeof(header)) {
            /*
             * First priority is to complete the header.
             */
            count = GetPtr(&ptr, sizeof(header) - headerLen, &fromAS);
            assert(count > 0);
            memcpy(&header + headerLen, ptr, count);
            headerLen += count;
            if(headerLen < sizeof(header)) {
                break;
            }
            if(header.version != FCGI_VERSION_1) {
	      parse_and_send_headers();
	      exit(FCGX_UNSUPPORTED_VERSION);
	    }
            if((header.requestIdB1 << 8) + header.requestIdB0 != requestId) {
	      parse_and_send_headers();
	      exit(FCGX_PROTOCOL_ERROR);
	    }
            contentLen = (header.contentLengthB1 << 8)
                         + header.contentLengthB0;
            paddingLen =  header.paddingLength;
	} else {
            /*
             * Header is complete (possibly from previous call).  What now?
             */
            switch(header.type)
	    {
	    case FCGI_STDOUT:
	      count = GetPtr(&ptr, contentLen, &fromAS);
	      contentLen -= count;
	      if(count > 0) {
		static int headers_sent;
		
		if(!headers_sent)
		{
		  if(is_end_of_headers(ptr, count))
		  {
		    parse_and_send_headers();
		    headers_sent = 1;
		  }
		} else
		  send_data(ptr, count);
	      }
	      break;
	
	    case FCGI_STDERR:
	      /*
	       * Write the buffered content to stderr.
	       * Blocking writes are OK here; can't prevent a slow
	       * client from tying up the app server without buffering
	       * output in temporary files.
	       */
	      count = GetPtr(&ptr, contentLen, &fromAS);
	      contentLen -= count;
	      if(count > 0) {
		if(write(2, ptr, count) < 0) {
		  exit(errno);
		}
	      }
	      break;
	    case FCGI_END_REQUEST:
	      if(!readingEndRequestBody) {
		if(contentLen != sizeof(erBody)) {
		  exit(FCGX_PROTOCOL_ERROR);
		}
		readingEndRequestBody = TRUE;
	      }
	      count = GetPtr(&ptr, contentLen, &fromAS);
	      if(count > 0) {
		memcpy(&erBody + sizeof(erBody) - contentLen,
		       ptr, count);
		contentLen -= count;
	      }
	      if(contentLen == 0) {
		if(erBody.protocolStatus != FCGI_REQUEST_COMPLETE) {
		  /*
		   * XXX: What to do with FCGI_OVERLOADED?
		   */
		  exit(FCGX_PROTOCOL_ERROR);
		}
		exitStatus = (erBody.appStatusB3 << 24)
		  + (erBody.appStatusB2 << 16)
		  + (erBody.appStatusB1 <<  8)
		  + (erBody.appStatusB0      );
		exitStatusSet = TRUE;
		readingEndRequestBody = FALSE;
	      }
	      break;
	    case FCGI_GET_VALUES_RESULT:
	      /* coming soon */
	    case FCGI_UNKNOWN_TYPE:
	      /* coming soon */
	    default:
	      exit(FCGX_PROTOCOL_ERROR);
	    }
            if(contentLen == 0) {
                if(paddingLen > 0) {
                    paddingLen -= GetPtr(&ptr, paddingLen, &fromAS);
		}
                /*
                 * If we've processed all the data and skipped all the
                 * padding, discard the header and look for the next one.
                 */
                if(paddingLen == 0) {
                    headerLen = 0;
	        }
	    }
        } /* headerLen >= sizeof(header) */
    } /*while*/
}

static Buffer fromWS;   /* Buffer for data read from Web server
                         * and written to FastCGI application. Used
                         * by WebServerReadHandler and
                         * AppServerWriteHandler. */
static int webServerReadHandlerEOF;
                        /* TRUE iff WebServerReadHandler has read EOF from
                         * the Web server. Used in main to prevent
                         * rescheduling WebServerReadHandler. */

/*
 *----------------------------------------------------------------------
 *
 * WebServerReadHandler --
 *
 *      Non-blocking reads data from the Web server into the fromWS
 *      buffer.  Called only when fromWS is empty, no EOF has been
 *      received from the Web server, and there's data available to read.
 *
 *----------------------------------------------------------------------
 */

static void WebServerReadHandler(void)
{
    int count;
    assert(fromWS.next == fromWS.stop);
    assert(fromWS.next == &fromWS.buff[0]);
    count = read(STDIN_FILENO, fromWS.next + sizeof(FCGI_Header),
                 BUFFLEN - sizeof(FCGI_Header));
    if(count < 0) {
        exit(errno);
    }
    *((FCGI_Header *) &fromWS.buff[0])
            = MakeHeader(FCGI_STDIN, requestId, count, 0);
    fromWS.stop = &fromWS.buff[sizeof(FCGI_Header) + count];
    webServerReadHandlerEOF = (count == 0);
}

/*
 *----------------------------------------------------------------------
 *
 * AppServerWriteHandler --
 *
 *      Non-blocking writes data from the fromWS buffer to the FCGI
 *      application server.  Called only when fromWS is non-empty
 *      and the socket is ready to accept some data.
 *
 *----------------------------------------------------------------------
 */

static void AppServerWriteHandler(void)
{
    int count;
    int length = fromWS.stop - fromWS.next;
    assert(length > 0);
    count = write(appServerSock, fromWS.next, length);
    assert(count != 0);
    if(count < 0) {
        exit(errno);
    }
    if(count < length) {
        fromWS.next += count;
    } else {
        fromWS.stop = fromWS.next = &fromWS.buff[0];
    }
}      

/*
 *----------------------------------------------------------------------
 *
 * OS_BuildSockAddrUn --
 *
 *      Using the pathname bindPath, fill in the sockaddr_un structure
 *      *servAddrPtr and the length of this structure *servAddrLen.
 *
 *      The format of the sockaddr_un structure changed incompatibly in
 *      4.3BSD Reno.  Digital UNIX supports both formats, other systems
 *      support one or the other.
 *
 * Results:
 *      0 for normal return, -1 for failure (bindPath too long).
 *
 *----------------------------------------------------------------------
 */

static int OS_BuildSockAddrUn(char *bindPath,
                              struct sockaddr_un *servAddrPtr,
                              int *servAddrLen)
{
    int bindPathLen = strlen(bindPath);

#ifdef HAVE_SOCKADDR_UN_SUN_LEN /* 4.3BSD Reno and later: BSDI, DEC */
    if(bindPathLen >= sizeof(servAddrPtr->sun_path)) {
        return -1;
    }
#else                           /* 4.3 BSD Tahoe: Solaris, HPUX, DEC, ... */
    if(bindPathLen > sizeof(servAddrPtr->sun_path)) {
        return -1;
    }
#endif
    memset((char *) servAddrPtr, 0, sizeof(*servAddrPtr));
    servAddrPtr->sun_family = AF_UNIX;
    memcpy(servAddrPtr->sun_path, bindPath, bindPathLen);
#ifdef HAVE_SOCKADDR_UN_SUN_LEN /* 4.3BSD Reno and later: BSDI, DEC */
    *servAddrLen = sizeof(servAddrPtr->sun_len)
            + sizeof(servAddrPtr->sun_family)
            + bindPathLen + 1;
    servAddrPtr->sun_len = *servAddrLen;
#else                           /* 4.3 BSD Tahoe: Solaris, HPUX, DEC, ... */
    *servAddrLen = sizeof(servAddrPtr->sun_family) + bindPathLen;
#endif
    return 0;
}

union SockAddrUnion {
    struct  sockaddr_un	unixVariant;
    struct  sockaddr_in	inetVariant;
};

/*
 *----------------------------------------------------------------------
 *
 * FCGI_Connect --
 *
 *      Attempts to connect to a listening socket at bindPath.
 *	if bindPath is in the form of string:int then it is to
 *	be treated as a hostname:port and we'll connect to that
 *      socket. Otherwise bindPath is going to be interpreted as
 *	a path to a UNIX domain socket.
 *
 * Results:
 *	A connected socket, or -1 if no connection could be established.
 *
 *----------------------------------------------------------------------
 */

static int FCGI_Connect(char *bindPath)
{
    union   SockAddrUnion sa;
    int servLen, resultSock;
    int connectStatus;
    char    *tp;
    char    host[MAXPATHLEN];
    short   port;
    int	    tcp = FALSE;

    strcpy(host, bindPath);
    if((tp = strchr(host, ':')) != 0) {
	*tp++ = 0;
	if((port = atoi(tp)) == 0) {
	    *--tp = ':';
	 } else {
	    tcp = TRUE;
	 }
    }
    if(tcp == TRUE) {
	struct	hostent	*hp;
	if((hp = gethostbyname((*host ? host : "localhost"))) == NULL) {
	    fprintf(stderr, "Unknown host: %s\n", bindPath);
	    exit(1000);
	}
	sa.inetVariant.sin_family = AF_INET;
	memcpy((caddr_t)&sa.inetVariant.sin_addr, hp->h_addr, hp->h_length);
	sa.inetVariant.sin_port = htons(port);
	servLen = sizeof(sa.inetVariant);
	resultSock = socket(AF_INET, SOCK_STREAM, 0);
    } else {
	if(OS_BuildSockAddrUn(bindPath, &sa.unixVariant, &servLen)) {
	    fprintf(stderr, "Listening socket's path name is too long.\n");
	    exit(1000);
	}
	resultSock = socket(AF_UNIX, SOCK_STREAM, 0);
    }

    assert(resultSock >= 0);
    connectStatus = connect(resultSock, (struct sockaddr *) &sa.unixVariant,
                             servLen);
    if(connectStatus >= 0) {
        return resultSock;
    } else {
        /*
         * Most likely (errno == ENOENT || errno == ECONNREFUSED)
         * and no FCGI application server is running.
         */
        close(resultSock);
        return -1;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * FCGI_Start --
 *
 *      Starts nServers copies of FCGI application appPath, all
 *      listening to a Unix Domain socket at bindPath.
 *
 *----------------------------------------------------------------------
 */

static void FCGI_Start(char *bindPath, char *appPath, int nServers)
{
    int listenSock, tmpFD, servLen, forkResult, i;
    union   SockAddrUnion sa;
    char    *tp;
    short   port;
    int	    tcp = FALSE;
    char    host[MAXPATHLEN];

    strcpy(host, bindPath);
    if((tp = strchr(host, ':')) != 0) {
	*tp++ = 0;
	if((port = atoi(tp)) == 0) {
	    *--tp = ':';
	 } else {
	    tcp = TRUE;
	 }
    }
    if(tcp && (*host && strcmp(host, "localhost") != 0)) {
	fprintf(stderr, "To start a service on a TCP port can not "
			"specify a host name.\n"
			"You should either use \"localhost:<port>\" or "
			" just use \":<port>.\"\n");
	exit(1);
    }

    if(access(appPath, X_OK) == -1) {
	fprintf(stderr, "%s is not executable\n", appPath);
	exit(1);
    }

    /*
     * Create the listening socket
     */
    if(FCGI_LISTENSOCK_FILENO == STDIN_FILENO) {
        tmpFD = dup(STDIN_FILENO);
        close(STDIN_FILENO);
    }
    if(tcp) {
	listenSock = socket(AF_INET, SOCK_STREAM, 0);
        if(listenSock >= 0) {
            int flag = 1;
            if(setsockopt(listenSock, SOL_SOCKET, SO_REUSEADDR,
                          (char *) &flag, sizeof(flag)) < 0) {
                fprintf(stderr, "Can't set SO_REUSEADDR.\n");
	        exit(1001);
	    }
	}
    } else {
	listenSock = socket(AF_UNIX, SOCK_STREAM, 0);
    }
    if(listenSock < 0) {
	exit(errno);
    }
    if(listenSock != FCGI_LISTENSOCK_FILENO) {
        dup2(listenSock, FCGI_LISTENSOCK_FILENO);
        close(listenSock);
    }
    /*
     * If the file already exists we need to delete it.  Don't
     * check for file-not-found errors since the file may not exist.
     */
    if(!tcp) {
	unlink(bindPath);
    }
    /*
     * Bind the listening socket.
     */
    if(tcp) {
	memset((char *) &sa.inetVariant, 0, sizeof(sa.inetVariant));
	sa.inetVariant.sin_family = AF_INET;
	sa.inetVariant.sin_addr.s_addr = htonl(INADDR_ANY);
	sa.inetVariant.sin_port = htons(port);
	servLen = sizeof(sa.inetVariant);
    } else {
	if(OS_BuildSockAddrUn(bindPath, &sa.unixVariant, &servLen)) {
	    fprintf(stderr, "Listening socket's path name is too long.\n");
	    exit(1000);
	}
    }
    if(bind(FCGI_LISTENSOCK_FILENO,
               (struct sockaddr *) &sa.unixVariant, servLen) < 0
            || listen(FCGI_LISTENSOCK_FILENO, 5) < 0) {
	perror("bind/listen");
        exit(errno);
    }

    /*
     * Create the server processes
     */
    for(i = 0; i < nServers; i++) {
        forkResult = fork();
        if(forkResult < 0) {
            exit(errno);
        }
        if(forkResult == 0) {
            /*
             * We're a child.  Exec the application.
             */
            if(FCGI_LISTENSOCK_FILENO != STDIN_FILENO) {
                close(STDIN_FILENO);
	    }
            close(STDOUT_FILENO);
            close(STDERR_FILENO);
            /*
             * Note: entire environment passes through
             */
            execl(appPath, appPath, NULL);
	    perror("exec");
            exit(errno);
	}
    }
    close(FCGI_LISTENSOCK_FILENO);
    if(FCGI_LISTENSOCK_FILENO == STDIN_FILENO) {
        dup2(tmpFD, STDIN_FILENO);
        close(tmpFD);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * FCGIUtil_BuildNameValueHeader --
 *
 *      Builds a name-value pair header from the name length
 *      and the value length.  Stores the header into *headerBuffPtr,
 *      and stores the length of the header into *headerLenPtr.
 *
 * Side effects:
 *      Stores header's length (at most 8) into *headerLenPtr,
 *      and stores the header itself into
 *      headerBuffPtr[0 .. *headerLenPtr - 1].
 *
 *----------------------------------------------------------------------
 */
static buildNameValueHeaderCalls = 0; /* XXX: for testing */

static void FCGIUtil_BuildNameValueHeader(
        int nameLen,
        int valueLen,
        unsigned char *headerBuffPtr,
        int *headerLenPtr) {
    unsigned char *startHeaderBuffPtr = headerBuffPtr;

    ASSERT(nameLen >= 0);
    if(nameLen < 0x80 && (buildNameValueHeaderCalls & 1) == 0) {
        *headerBuffPtr++ = nameLen;
    } else {
        *headerBuffPtr++ = (nameLen >> 24) | 0x80;
        *headerBuffPtr++ = (nameLen >> 16);
        *headerBuffPtr++ = (nameLen >> 8);
        *headerBuffPtr++ = nameLen;
    }
    ASSERT(valueLen >= 0);
    if(valueLen < 0x80 && (buildNameValueHeaderCalls & 2) == 0) {
        *headerBuffPtr++ = valueLen;
    } else {
        *headerBuffPtr++ = (valueLen >> 24) | 0x80;
        *headerBuffPtr++ = (valueLen >> 16);
        *headerBuffPtr++ = (valueLen >> 8);
        *headerBuffPtr++ = valueLen;
    }
    *headerLenPtr = headerBuffPtr - startHeaderBuffPtr;
    buildNameValueHeaderCalls++;
}


#define MAXARGS	16
static int ParseArgs(int argc, char *argv[],
        int *doBindPtr, int *doStartPtr,
        char *connectPathPtr, char *appPathPtr, int *nServersPtr) {
    int	    i,
	    x,
	    err = 0,
	    ac;
    char    *tp1,
	    *tp2,
	    *av[MAXARGS];
    FILE    *fp;
    char    line[BUFSIZ];

    *doBindPtr = TRUE;
    *doStartPtr = TRUE;
    *connectPathPtr = '\0';
    *appPathPtr = '\0';
    *nServersPtr = 0;

    for(i = 1; i < argc; i++) {
        if(argv[i][0] == '-') {
            if(!strcmp(argv[i], "-f")) {
		if(++i == argc) {
		    fprintf(stderr,
                            "Missing command file name after -f\n");
		    return 1;
		}
		if((fp = fopen(argv[i], "r")) == NULL) {
		    fprintf(stderr, "Cannot open command file %s\n", argv[i]);
		    return 1;
		}
		ac = 1;
		while(fgets(line, BUFSIZ, fp)) {
		    if(line[0] == '#') {
			continue;
		    }
		    if((tp1 = (char *) strrchr(line,'\n')) != NULL) {
			*tp1-- = 0;
			while(*tp1 == ' ' || *tp1 =='\t') {
			    *tp1-- = 0;
		        }
		    } else {
			fprintf(stderr, "Line to long\n");
			return 1;
		    }
		    tp1 = line;
		    while(tp1) {
			if((tp2 = strchr(tp1, ' ')) != NULL) {
			    *tp2++ =  0;
		        }
    			if(ac >= MAXARGS) {
			    fprintf(stderr,
                                    "To many arguments, "
                                    "%d is max from a file\n", MAXARGS);
				exit(-1);
			}
			if((av[ac] = malloc(strlen(tp1)+1)) == NULL) {
			    fprintf(stderr, "Cannot allocate %d bytes\n",
				    strlen(tp1)+1);
			    exit(-1);
			}
			strcpy(av[ac++], tp1);
			tp1 = tp2;
		    }
		}
		err = ParseArgs(ac, av, doBindPtr, doStartPtr,
                        connectPathPtr, appPathPtr, nServersPtr);
		for(x = 1; x<=ac; x++) {
		    free(av[x]);
	        }
		return err;
	    } else if(!strcmp(argv[i], "-start")) {
		*doBindPtr = FALSE;
	    } else if(!strcmp(argv[i], "-bind")) {
		*doStartPtr = FALSE;
	    } else if(!strcmp(argv[i], "-connect")) {
                if(++i == argc) {
	            fprintf(stderr,
                            "Missing connection name after -connect\n");
                    err++;
                } else {
                    strcpy(connectPathPtr, argv[i]);
                }
	    } else {
		fprintf(stderr, "Unknown option %s\n", argv[i]);
		err++;
	    }
	} else if(*appPathPtr == '\0') {
            strcpy(appPathPtr, argv[i]);
        } else if(isdigit(argv[i][0]) && *nServersPtr == 0) {
            *nServersPtr = atoi(argv[i]);
            if(*nServersPtr <= 0) {
                fprintf(stderr, "Number of servers must be greater than 0\n");
                err++;
            }
        } else {
            fprintf(stderr, "Unknown argument %s\n", argv[i]);
            err++;
        }
    }
    if(*doStartPtr && *appPathPtr == 0) {
        fprintf(stderr, "Missing application pathname\n");
        err++;
    }
    if(*connectPathPtr == 0) {
	fprintf(stderr, "Missing -connect <connName>\n");
	err++;
    } else if(strchr(connectPathPtr, ':')) {
        if(*doStartPtr && *doBindPtr) {
	    fprintf(stderr,
                    "<connName> of form hostName:portNumber "
                    "requires -start or -bind\n");
	    err++;
        }
    }
    if(*nServersPtr == 0) {
        *nServersPtr = 1;
    }
    return err;
}

void main(int argc, char **argv, char **envp)
{
    int count;
    FCGX_Stream *paramsStream;
    fd_set readFdSet, writeFdSet;
    int numFDs, selectStatus;
    unsigned char headerBuff[8];
    int headerLen, valueLen;
    char *equalPtr;
    FCGI_BeginRequestRecord beginRecord;
    int	doBind, doStart, nServers;
    char appPath[MAXPATHLEN], bindPath[MAXPATHLEN];

    if(ParseArgs(argc, argv, &doBind, &doStart,
		   (char *) &bindPath, (char *) &appPath, &nServers)) {
	fprintf(stderr,
"Usage:\n"
"    cgi-fcgi -f <cmdPath> , or\n"
"    cgi-fcgi -connect <connName> <appPath> [<nServers>] , or\n"
"    cgi-fcgi -start -connect <connName> <appPath> [<nServers>] , or\n"
"    cgi-fcgi -bind -connect <connName> ,\n"
"where <connName> is either the pathname of a UNIX domain socket\n"
"or (if -bind is given) a hostName:portNumber specification\n"
"or (if -start is given) a :portNumber specification (uses local host).\n");
	exit(1);
    }
    if(doBind) {
        appServerSock = FCGI_Connect(bindPath);
    }
    if(doStart && (!doBind || appServerSock < 0)) {
        FCGI_Start(bindPath, appPath, nServers);
        if(!doBind) {
            exit(0);
        } else {
            appServerSock = FCGI_Connect(bindPath);
	}
    }
    if(appServerSock < 0) {
        fprintf(stderr, "Could not connect to %s\n", bindPath);
        exit(errno);
    }
    /*
     * Set an arbitrary non-null FCGI RequestId
     */
    requestId = 1;
    /*
     * XXX: Send FCGI_GET_VALUES
     */

    /*
     * XXX: Receive FCGI_GET_VALUES_RESULT
     */

    /*
     * Send FCGI_BEGIN_REQUEST (XXX: hack, separate write)
     */
    beginRecord.header = MakeHeader(FCGI_BEGIN_REQUEST, requestId,
            sizeof(beginRecord.body), 0);
    beginRecord.body = MakeBeginRequestBody(FCGI_RESPONDER, TRUE);
    count = write(appServerSock, &beginRecord, sizeof(beginRecord));
    if(count != sizeof(beginRecord)) {
        exit(errno);
    }
    /*
     * Send environment to the FCGI application server
     */
    paramsStream = CreateWriter(appServerSock, requestId, 8192, FCGI_PARAMS);
    for( ; *envp != NULL; envp++) {
        equalPtr = strchr(*envp, '=');
        if(equalPtr  == NULL) {
            exit(1000);
        }
        valueLen = strlen(equalPtr + 1);
        FCGIUtil_BuildNameValueHeader(
                equalPtr - *envp,
                valueLen,
                &headerBuff[0],
                &headerLen);
        if(FCGX_PutStr((char *) &headerBuff[0], headerLen, paramsStream) < 0
                || FCGX_PutStr(*envp, equalPtr - *envp, paramsStream) < 0
                || FCGX_PutStr(equalPtr + 1, valueLen, paramsStream) < 0) {
            exit(FCGX_GetError(paramsStream));
        }
    }
    FCGX_FClose(paramsStream);
    FreeStream(&paramsStream);
    /*
     * Perform the event loop until AppServerReadHander sees FCGI_END_REQUEST
     */
    fromWS.stop = fromWS.next = &fromWS.buff[0];
    webServerReadHandlerEOF = FALSE;
    FD_ZERO(&readFdSet);
    FD_ZERO(&writeFdSet);
    numFDs = max(appServerSock, STDIN_FILENO) + 1;
    SetFlags(appServerSock, O_NONBLOCK);
    for(;;) {
        if((fromWS.stop == fromWS.next) && !webServerReadHandlerEOF) {
            FD_SET(STDIN_FILENO, &readFdSet);
        } else {
            FD_CLR(STDIN_FILENO, &readFdSet);
        }
        if(fromWS.stop != fromWS.next) {
            FD_SET(appServerSock, &writeFdSet);
        } else {
            FD_CLR(appServerSock, &writeFdSet);
        }
        FD_SET(appServerSock, &readFdSet);
        selectStatus = select(numFDs, &readFdSet, &writeFdSet, NULL, NULL);
        if(selectStatus < 0) {
            exit(errno);
        }
        if(selectStatus == 0) {
            /*
             * Should not happen, no select timeout.
             */
            continue;
        }
        if(FD_ISSET(STDIN_FILENO, &readFdSet)) {
            WebServerReadHandler();
        }
        if(FD_ISSET(appServerSock, &writeFdSet)) {
            AppServerWriteHandler();
        }
        if(FD_ISSET(appServerSock, &readFdSet)) {
            AppServerReadHandler();
	}
        if(exitStatusSet) {
            exit(exitStatus);
	}
    } 
}
