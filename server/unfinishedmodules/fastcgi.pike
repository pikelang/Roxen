string cvs_version = "$Id: fastcgi.pike,v 1.2 1996/12/01 19:18:52 per Exp $";
#if 0
// Native FAST-CGI support

// NOT FINISHED AT ALL

/*
 * Listening socket file number
 */
#define FCGI_LISTENSOCK_FILENO 0

/*
typedef struct {
    unsigned char version;
    unsigned char type;
    unsigned char requestIdB1;
    unsigned char requestIdB0;
    unsigned char contentLengthB1;
    unsigned char contentLengthB0;
    unsigned char paddingLength;
    unsigned char reserved;
} FCGI_Header;
*/

/*
 * Number of bytes in a FCGI_Header.  Future versions of the protocol
 * will not reduce this number.
 */
#define FCGI_HEADER_LEN  8

/*
 * Value for version component of FCGI_Header
 */
#define FCGI_VERSION_1           1

/*
 * Values for type component of FCGI_Header
 */
#define FCGI_BEGIN_REQUEST       1
#define FCGI_ABORT_REQUEST       2
#define FCGI_END_REQUEST         3
#define FCGI_PARAMS              4
#define FCGI_STDIN               5
#define FCGI_STDOUT              6
#define FCGI_STDERR              7
#define FCGI_DATA                8
#define FCGI_GET_VALUES          9
#define FCGI_GET_VALUES_RESULT  10
#define FCGI_UNKNOWN_TYPE       11
#define FCGI_MAXTYPE (FCGI_UNKNOWN_TYPE)

/*
 * Value for requestId component of FCGI_Header
 */
#define FCGI_NULL_REQUEST_ID     0

/*
typedef struct {
    unsigned char roleB1;
    unsigned char roleB0;
    unsigned char flags;
    unsigned char reserved[5];
} FCGI_BeginRequestBody;

typedef struct {
    FCGI_Header header;
    FCGI_BeginRequestBody body;
} FCGI_BeginRequestRecord;
*/


/*
 * Mask for flags component of FCGI_BeginRequestBody
 */
#define FCGI_KEEP_CONN  1


/*
 * Values for role component of FCGI_BeginRequestBody
 */
#define FCGI_RESPONDER  1
#define FCGI_AUTHORIZER 2
#define FCGI_FILTER     3


/*
typedef struct {
    unsigned char appStatusB3;
    unsigned char appStatusB2;
    unsigned char appStatusB1;
    unsigned char appStatusB0;
    unsigned char protocolStatus;
    unsigned char reserved[3];
} FCGI_EndRequestBody;


typedef struct {
    FCGI_Header header;
    FCGI_EndRequestBody body;
} FCGI_EndRequestRecord;
*/

/*
 * Values for protocolStatus component of FCGI_EndRequestBody
 */
#define FCGI_REQUEST_COMPLETE 0
#define FCGI_CANT_MPX_CONN    1
#define FCGI_OVERLOADED       2
#define FCGI_UNKNOWN_ROLE     3

/*
 * Variable names for FCGI_GET_VALUES / FCGI_GET_VALUES_RESULT records
 */
#define FCGI_MAX_CONNS  "FCGI_MAX_CONNS"
#define FCGI_MAX_REQS   "FCGI_MAX_REQS"
#define FCGI_MPXS_CONNS "FCGI_MPXS_CONNS"


/*
typedef struct {
    unsigned char type;    
    unsigned char reserved[7];
} FCGI_UnknownTypeBody;

typedef struct {
    FCGI_Header header;
    FCGI_UnknownTypeBody body;
} FCGI_UnknownTypeRecord;
*/


program fcgi_record = class {
  string data;
  mapping contents = ([ ]);
  int type = -1;
  int requestID;


  string decode_name_value(string from)
  {
    int total_len;
    int value_len, name_len;
    
    if(from[total_len]&128)
      name_len=(((from[total_len++]&0x7f)<<24)+(from[total_len++]<<16)
		+(from[total_len++]<<8)+from[total_len++]);
    else 
      name_len = from[total_len++];

    if(from[total_len]&128)
      value_len=(((from[total_len++]&0x7f)<<24)+(from[total_len++]<<16)
		 +(from[total_len++]<<8)+from[total_len++]);
    else 
      name_len = from[total_len++];
    
    if(strlen(from) < total_len + name_len + value_len) 
      return 0; /* Nope. */
    
    contents->from[total_len..(total_len + name_len-1)] = 
      from[(total_len+name_len) .. (total_len+name_len+value_len-1)];

    total_len += name_len+value_len;
    return from[total_len..];
  }


  string encode_name_values()
  {
    string res = "", f;
    foreach(indices(contents), f)
    {
      int l;
      if(l = strlen(f) > 256)
	res += sprintf("%c%c%c%c", (l>>24)|0x7f, l>>16, l>>8, l);
      else
	res += sprintf("%c", l);
      if(l = strlen(contents[f]) > 256)
	res += sprintf("%c%c%c%c", (l>>24)|0x7f, l>>16, l>>8, l);
      else
	res += sprintf("%c", l);
      res += f+contents[f];
    }
    data = res;
  }

  void encode_data()
  {
    switch(type)
    {
     case FCGI_BEGIN_REQUEST:
      data = sprintf("%c%c%c     ", contents->role>>8, contents->role&255,
		     contents->flags);
      return;

     case FCGI_ABORT_REQUEST:
      data = "";
      return;

     case FCGI_END_REQUEST:
      perror("FCGI: Server send of a END_REQUEST record. Odd.\n");
      return;
      
     case FCGI_PARAMS:
      encode_name_values();
      return;

     case FCGI_STDOUT:
      perror("FCGI: Server send of a STDIN record. Odd.\n");
      
     case FCGI_STDIN:
     case FCGI_STDERR:
     case FCGI_DATA:
      /* No encoding nessesary. */
      return;

     case FCGI_GET_VALUES:
      if(requestID)
	perror("FCGI: GET_VALUES with non-null request ID. Odd.\n");
      requestID=0;
      encode_name_values()
      return;

     case FCGI_GET_VALUES_RESULT:
      perror("FCGI: We are not allowed to send a GET_VALUES_RESULT.\n");
    }
  }

  void decode_data()
  {
    switch(type)
    {
     case FCGI_UNKNOWN_TYPE: /* Not all that interresting. */
      break;

     case FCGI_BEGIN_REQUEST:
      perror("FCGI: Client send BEGIN_REQUEST record. Odd.\n");
      break;
     case FCGI_ABORT_REQUEST:
      perror("FCGI: Client send ABORT_REQUEST record. Odd.\n");
      break;
      
     case FCGI_END_REQUEST:
      if(strlen(data) < 8)
      {
	perror("FCGI: Protocol error.\n");
	return;
      }
      contents->appStatus = (data[0]<<24)+(data[1]<<16)+(data[2]<<8)+data[3];
      contents->protocolStatus = data[4];
      break;
      
     case FCGI_PARAMS:
      perror("FCGI: Client send FCGI_PARAMS record. Odd.\n");
      return;

     case FCGI_STDIN:
      perror("FCGI: Client send STDIN record. Odd.\n");
     case FCGI_STDOUT:
     case FCGI_STDERR:
     case FCGI_DATA:
      /* No decoding nessesary. */
      return;
     case FCGI_GET_VALUES:
      perror("FCGI: Client send GET_VALUES record. Odd.\n");
      return;
     case FCGI_GET_VALUES_RESULT:
      if(requestID)
	perror("FCGI: GET_VALUES_RESULT with non-null request ID. Odd.\n");
      decode_name_values()
      requestID=0;
    }
  }

  string encode() 
  {
    /* vers, type, requestid>>8, requestid&255, contentlen>>8, contentlen&256
     * padding len reserved, contentdata
     */
    if(strlen(data) > 65535)
    {
      object tmp = clone(object_program(this_object()));
      string res;
      tmp->data = data[65535..];
      tmp->type = type;
      tmp->requestID = requestID;
      data = data[..65534];
      res = encode() + tmp->encode();
      return res;
    }

    string padding = "        ";
    padding=padding[1..strlen(data)%8]:

    return sprintf("%c%c%c%c%c%c%c%c%s", FCGI_VERSION_1, type, requestid>>8,
		   requestid&255, strlen(data)>>8, strlen(data)&255,
		   0, strlen(padding), data, padding);
  }

  int assign(string from) 
  {
    int contentlen, paddinglen;
    if(strlen(from) < 8) return -1; /* More needed. */
    
    version = from[0];
    type = from[1];
    requestID = from[2]<<8 + from[3];
    contentlen = from[4]<<8 + from[5];
    paddinglen = from[6];
    /* from[7] == reserved */
    if(strlen(from)-8 < contentlen + paddinglen) return -1;
    
    if(version != FCGI_VERSION_1) {
      perror("FCGI: Protocol version mismatch.");
    }

    data = from[8..contentlen+7];
    decode_data();

    
    return contentlen+paddinglen+8; /* Used X bytes from the stream. */
  }


};

mapping extravars = ([ ]);


void fix_uid_and_exec(string path)
{
#if efun(setuid)
  array stat;
  int uid=0, gid=0;
  stat = file_stat( path );
  if(stat)
  {
    if(QUERY(fix_uid))
    {
      uid = stat[-2];
      gid = stat[-1];
    }
  }
#if efun(geteuid)
  else {
    uid = geteuid();
    gid = getegid();
  }
#else

  if(gid) 
  {
#if efun(setegid)
    setegid(0); 
#endif
    setgid(uid); 
  }
  if(uid) 
  { 
#if efun(seteuid)
    seteuid(0); 
#endif
    setuid(uid); 
  }
#endif
#if efun(initgroups)
  initgroups();
#endif
  string basename;
  cd(dirname(path));
  sscanf(reverse(path, "%s/", basename));
#if efun(renice)
  renice(10);
#endif
  exece("./"+basename, ({ }), extravars);
}


/* Returns the new PID and port. */
int spawn_fcgi_process(string path) 
{
  int pid;
  int port;
  port = find_free_port("127.0.0.1");
  
  if(pid=fork()) return ({ port, pid });
  stdin->close();    /* 0 */
  stdout->close();   /* 1 */
  stderr->close();   /* 2 */
  fcgi_create_listen_socket();
  catch(fix_uid_and_exec( path ));
  perror("exec() of "+path+" failed.\n");
  exit(0);
}
#endif
#endif
