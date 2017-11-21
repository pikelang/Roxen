// This is a roxen protocol module.
// Copyright © 1997 - 2009, Roxen IS.

/*
 * FTP protocol mk 2
 *
 * $Id$
 *
 * Henrik Grubbström <grubba@roxen.com>
 */

/*
 * TODO:
 *
 * How much is supposed to be logged?
 */

/*
 * Relevant RFC's:
 *
 * RFC 764	TELNET PROTOCOL SPECIFICATION
 * RFC 765	FILE TRANSFER PROTOCOL
 * RFC 959	FILE TRANSFER PROTOCOL (FTP)
 * RFC 1123	Requirements for Internet Hosts -- Application and Support
 * RFC 1579	Firewall-Friendly FTP
 * RFC 1635	How to Use Anonymous FTP
 *
 * RFC's describing extra commands:
 *
 * RFC 683	FTPSRV - Tenex extension for paged files
 * RFC 737	FTP Extension: XSEN
 * RFC 743	FTP extension: XRSQ/XRCP
 * RFC 775	DIRECTORY ORIENTED FTP COMMANDS
 * RFC 949	FTP unique-named store command
 * RFC 1639	FTP Operation Over Big Address Records (FOOBAR)
 * RFC 2228	FTP Security Extensions
 * RFC 2428	FTP Extensions for IPv6 and NATs
 * RFC 3659	Extensions to FTP
 *
 * RFC's with recomendations and discussions:
 *
 * RFC 607	Comments on the File Transfer Protocol
 * RFC 614	Response to RFC 607, "Comments on the File Transfer Protocol"
 * RFC 624	Comments on the File Transfer Protocol
 * RFC 640	Revised FTP Reply Codes
 * RFC 691	One More Try on the FTP
 * RFC 724	Proposed Official Standard for the
 * 		Format of ARPA Network Messages
 * RFC 4217	Securing FTP with TLS
 *
 * RFC's describing gateways and proxies:
 *
 * RFC 1415	FTP-FTAM Gateway Specification
 *
 * More or less obsolete RFC's:
 *
 * RFC 412	User FTP documentation
 * RFC 438	FTP server-server interaction
 * RFC 448	Print files in FTP
 * RFC 458	Mail retrieval via FTP
 * RFC 463	FTP comments and response to RFC 430
 * RFC 468	FTP data compression
 * RFC 475	FTP and network mail system
 * RFC 478	FTP server-server interaction - II
 * RFC 479	Use of FTP by the NIC Journal
 * RFC 480	Host-dependent FTP parameters
 * RFC 505	Two solutions to a file transfer access problem
 * RFC 506	FTP command naming problem
 * RFC 520	Memo to FTP group: Proposal for File Access Protocol
 * RFC 532	UCSD-CC Server-FTP facility
 * RFC 542	File Transfer Protocol for the ARPA Network
 * RFC 561	Standardizing Network Mail Headers
 * RFC 571	Tenex FTP problem
 * RFC 630	FTP error code usage for more reliable mail service
 * RFC 686	Leaving well enough alone
 * RFC 697	CWD Command of FTP
 * RFC 751	SURVEY OF FTP MAIL AND MLFL
 * RFC 754	Out-of-Net Host Addresses for Mail
 *
 * (RFCs are available from http://pike.lysator.liu.se/docs/ietf/rfc/).
 */


#include <config.h>
#include <module.h>
#include <stat.h>

//#define FTP2_DEBUG

#define FTP2_XTRA_HELP ({ "Report any bugs at http://community.roxen.com/crunch/" })

#define FTP2_TIMEOUT	(5*60)

// Enable the use of handler threads.
#define FTP_USE_HANDLER_THREADS

// #define Query(X) conf->variables[X][VAR_VALUE]

#ifdef FTP2_DEBUG
# define DWRITE(X ...)	werror(X)
#else
# define DWRITE(X ...)
#endif

#define BACKEND_CLOSE(FD)	do { DWRITE("close\n"); FD->set_blocking(); call_out(FD->close, 0); FD = 0; } while(0)

class RequestID2
{
  inherit RequestID;

  mapping file;

#ifdef FTP2_DEBUG
  protected void trace_enter(mixed a, mixed b)
  {
    write("FTP: TRACE_ENTER(%O, %O)\n", a, b);
  }

  protected void trace_leave(mixed a)
  {
    write("FTP: TRACE_LEAVE(%O)\n", a);
  }
#endif /* FTP2_DEBUG */

  void ready_to_receive()
  {
    // FIXME: Should hook the STOR reply to this function.
  }

  Configuration configuration()
  {
    return conf;
  }

  Stdio.File connection( )
  {
    return my_fd;
  }

  void send_result(mapping|void result)
  {
    if (mappingp(result) && my_fd && my_fd->done) {
      my_fd->done(result);
      return;
    }

    error("Async sending with send_result() not supported yet.\n");
  }

  object(RequestID2) clone_me()
  {
    object(RequestID2) o = this_object();
    return(object_program(o)(o));
  }

  void end()
  {
  }

  protected constant __num = ({ 0 });
  int _num;

  void destroy()
  {
#ifdef FTP_REQUESTID_DEBUG
    report_debug("REQUESTID: Destroy request id #%d.\n", _num);
#endif
  }

  void create(object|void m_rid)
  {
#ifdef FTP_REQUESTID_DEBUG
    _num = ++__num[0];
    if (m_rid) {
      report_debug("REQUESTID: New request id #%d (CHILD to #%d).\n",
		   _num, m_rid->_num);
    } else {
      report_debug("REQUESTID: New request id #%d (MASTER).\n", _num);
    }
#else
    DWRITE("REQUESTID: New request id.\n");
#endif

    if (m_rid) {
      object o = this_object();
      foreach(indices(m_rid), string var) {
	if (object_variablep(o, var)) {
#ifdef DEBUG
	  if (catch {
#endif /* DEBUG */
	    o[var] = m_rid[var];
#ifdef DEBUG
	  }) {
	    report_error("FTP2: "
			 "Failed to copy variable %s (value:%O)\n",
			 var, m_rid[var]);
	  }
#endif /* DEBUG */
	}
      }
      o->misc = m_rid->misc + ([]);
    } else {
      // Defaults...
      client = ({ "ftp" });
      prot = "FTP";
      clientprot = "FTP";
      variables = FakedVariables(real_variables = ([]));
      misc = (["pref_languages": PrefLanguages()]);
      cookies = CookieJar();
      throttle = ([]);
      client_var = ([]);
      request_headers = ([]);

      prestate = (<>);
      config = (<>);
      supports = (< "ftp", "images", "tables", >);
      pragma = (<>);
      rest_query = "";
      extra_extension = "";
      root_id = this_object();
    }
    time = predef::time(1);
#ifdef FTP2_DEBUG
    misc->trace_enter = trace_enter;
    misc->trace_leave = trace_leave;
#endif /* FTP2_DEBUG */
  }
};

class FileWrapper
{
  protected string convert(string s);

  private function read_cb;
  private function close_cb;
  private mixed id;

  private object f;
  private string data;
  private object ftpsession;

  int is_file;

  protected void create(object f_, string data_, object ftpsession_)
  {
    f = f_;
    data = data_;
    ftpsession = ftpsession_;

    is_file = f_->is_file;
  }

  private void read_callback(mixed i, string s)
  {
    read_cb(id, convert(s));
    ftpsession->touch_me();
  }

  private void close_callback(mixed i)
  {
    ftpsession->touch_me();
    close_cb(id);
  }

  private void delayed_nonblocking(function w_cb)
  {
    string d = data;
    data = 0;
    f->set_nonblocking(read_callback, w_cb, close_callback);
    if (d) {
      read_callback(0, d);
    }
  }

  void set_nonblocking(function r_cb, function w_cb, function c_cb)
  {
    read_cb = r_cb;
    close_cb = c_cb;
    remove_call_out(delayed_nonblocking);
    if (r_cb) {
      if (data) {
	// We need to call r_cb as soon as possible, but we can't do it here
	// and we can't enable the read_callback just yet to maintain order.
	call_out(delayed_nonblocking, 0, w_cb);
	f->set_nonblocking(0, w_cb, 0);
      } else {
	f->set_nonblocking(read_callback, w_cb, close_callback);
      }
    } else {
      f->set_nonblocking(0, w_cb, 0);
    }
  }

  void set_blocking()
  {
    if (data) {
      remove_call_out(delayed_nonblocking);
    }
    f->set_blocking();
  }

  void set_id(mixed i)
  {
    id = i;
    f->set_id(i);
  }

  int query_fd()
  {
    return -1;
  }

  string read(int|void n)
  {
    ftpsession->touch_me();
    if (data) {
      if (n) {
	if (n < sizeof(data)) {
	  string d = data[..n-1];
	  data = data[n..];
	  return convert(d);
	} else {
	  string d = data;
	  data = 0;
	  return convert(d + f->read(n - sizeof(d)));
	}
      } else {
	string d = data;
	data = 0;
	return convert(d + f->read());
      }
    }
    return(convert(f->read(n)));
  }

  void close()
  {
    if (ftpsession)
      ftpsession->touch_me();
    if (f) {
      f->set_blocking();
      BACKEND_CLOSE(f);
    }
  }

  string query_address(int|void loc)
  {
    if (!f->query_address) {
      werror("%O->query_address(%O)\n", f, loc);
    }
    return f->query_address(loc);
  }
}

class ToAsciiWrapper
{
  inherit FileWrapper;

  int converted;

  protected string convert(string s)
  {
    converted += sizeof(s);
    return(replace(s, ({ "\r\n", "\n", "\r" }), ({ "\r\n", "\r\n", "\r\n" })));
  }
}

class FromAsciiWrapper
{
  inherit FileWrapper;

  int converted;

  protected string convert(string s)
  {
    converted += sizeof(s);
#ifdef __NT__
    // This replace shouldn't be needed, but we're paranoid.
    return(replace(s, ({ "\r\n", "\n", "\r" }), ({ "\r\n", "\r\n", "\r\n" })));
#else /* !__NT__ */
#ifdef __MACOS__
    return(replace(s, ({ "\r\n", "\n", "\r" }), ({ "\r", "\r", "\r" })));
#else /* !__MACOS__ */
    return(replace(s, ({ "\r\n", "\n", "\r" }), ({ "\n", "\n", "\n" })));
#endif /* __MACOS__ */
#endif /* __NT__ */
  }
}

// This one is needed for touch_me() to be called as needed.
class BinaryWrapper
{
  inherit FileWrapper;

  protected string convert(string s)
  {
    return(s);
  }
}

// EBCDIC Wrappers here.

class ToEBCDICWrapper
{
  inherit FileWrapper;

  int converted;

  protected Charset.Encoder converter = Charset.encoder("EBCDIC-US", "");

  protected string convert(string s)
  {
    converted += sizeof(s);
    return(converter->feed(s)->drain());
  }
}

class FromEBCDICWrapper
{
  inherit FileWrapper;

  int converted;

  protected Charset.Decoder converter = Charset.decoder("EBCDIC-US");

  protected string convert(string s)
  {
    converted += sizeof(s);
    return(converter->feed(s)->drain());
  }
}


class PutFileWrapper
{
  protected int response_code = 226;
  protected array(string) response = ({"Stored."});
  protected string gotdata = "";
  protected int closed, recvd;
  protected function other_read_callback;

  protected object from_fd;
  protected object session;
  protected object ftpsession;

  int is_file;

  protected void create(object from_fd_, object session_, object ftpsession_)
  {
    from_fd = from_fd_;
    session = session_;
    ftpsession = ftpsession_;

    is_file = from_fd->is_file;
  }

  int bytes_received()
  {
    return recvd;
  }

  int close(string|void how)
  {
    DWRITE("FTP: PUT: close()\n");
    ftpsession->touch_me();
    if(how != "w" && !closed) {
      ftpsession->send(response_code, response);
      closed = 1;
      session->conf->received += recvd;
      session->file->len = recvd;
      session->conf->log(session->file, session);
      destruct(session);
    }
    if (how) {
      return from_fd->close(how);
    } else {
      BACKEND_CLOSE(from_fd);
      return 0;
    }
  }

  string read(mixed ... args)
  {
    DWRITE("FTP: PUT: read()\n");
    ftpsession->touch_me();
    string r = from_fd->read(@args);
    if(stringp(r))
      recvd += sizeof(r);
    return r;
  }

  protected mixed my_read_callback(mixed id, string data)
  {
    DWRITE("FTP: PUT: my_read_callback(X, \"%s\")\n", data||"");
    ftpsession->touch_me();
    if(stringp(data))
      recvd += sizeof(data);
    return other_read_callback(id, data);
  }

  void set_read_callback(function read_callback)
  {
    DWRITE("FTP: PUT: set_read_callback()\n");
    ftpsession->touch_me();
    if(read_callback) {
      other_read_callback = read_callback;
      from_fd->set_read_callback(my_read_callback);
    } else
      from_fd->set_read_callback(read_callback);
  }

  void set_nonblocking(function ... args)
  {
    DWRITE("FTP: PUT: set_nonblocking()\n");
    if(sizeof(args) && args[0]) {
      other_read_callback = args[0];
      from_fd->set_nonblocking(my_read_callback, @args[1..]);
    } else
      from_fd->set_nonblocking(@args);
  }

  void set_blocking()
  {
    from_fd->set_blocking();
  }

  void set_id(mixed id)
  {
    from_fd->set_id(id);
  }

  int write(string data)
  {
    DWRITE("FTP: PUT: write(\"%s\")\n", data||"");

    ftpsession->touch_me();

    int n, code;
    string msg;
    gotdata += data;
    while((n=search(gotdata, "\n"))>=0) {
      if(3==sscanf(gotdata[..n], "HTTP/%*s %d %[^\r\n]", code, msg)
         && code>199) {
        if(code < 300)
          code = 226;
        else
          code = 550;
	response_code = code;
	response = ({msg});
      }
      gotdata = gotdata[n+1..];
    }
    return strlen(data);
  }

  void done(mapping result)
  {
    if (result->error < 300) {
      response_code = 226;
    } else {
      response_code = 550;
    }

    // Cut away the code.
    if (result->rettext)
      response = result->rettext / "\n";
    else
      response = ({Roxen.http_status_messages[result->error] || ""});
    gotdata = result->data || "";

    close();
  }

  string query_address(int|void loc)
  {
    if (!from_fd->query_address) {
      werror("%O->query_address(%O)\n", from_fd, loc);
    }
    return from_fd->query_address(loc);
  }
}


// Simulated /usr/bin/ls pipe

#define LS_FLAG_A       0x00001
#define LS_FLAG_a       0x00002
#define LS_FLAG_b	0x00004
#define LS_FLAG_C       0x00008
#define LS_FLAG_d       0x00010
#define LS_FLAG_F       0x00020
#define LS_FLAG_f       0x00040
#define LS_FLAG_G       0x00080
#define LS_FLAG_h	0x00100
#define LS_FLAG_l       0x00200
#define LS_FLAG_m	0x00400
#define LS_FLAG_n       0x00800
#define LS_FLAG_r       0x01000
#define LS_FLAG_Q	0x02000
#define LS_FLAG_R       0x04000
#define LS_FLAG_S	0x08000
#define LS_FLAG_s	0x10000
#define LS_FLAG_t       0x20000
#define LS_FLAG_U       0x40000
#define LS_FLAG_v	0x80000

class LS_L(protected RequestID master_session,
	   protected int|void flags)
{
  protected constant decode_mode = ({
    ({ S_IRUSR, S_IRUSR, 1, "r" }),
    ({ S_IWUSR, S_IWUSR, 2, "w" }),
    ({ S_IXUSR|S_ISUID, S_IXUSR, 3, "x" }),
    ({ S_IXUSR|S_ISUID, S_ISUID, 3, "S" }),
    ({ S_IXUSR|S_ISUID, S_IXUSR|S_ISUID, 3, "s" }),
    ({ S_IRGRP, S_IRGRP, 4, "r" }),
    ({ S_IWGRP, S_IWGRP, 5, "w" }),
    ({ S_IXGRP|S_ISGID, S_IXGRP, 6, "x" }),
    ({ S_IXGRP|S_ISGID, S_ISGID, 6, "S" }),
    ({ S_IXGRP|S_ISGID, S_IXGRP|S_ISGID, 6, "s" }),
    ({ S_IROTH, S_IROTH, 7, "r" }),
    ({ S_IWOTH, S_IWOTH, 8, "w" }),
    ({ S_IXOTH|S_ISVTX, S_IXOTH, 9, "x" }),
    ({ S_IXOTH|S_ISVTX, S_ISVTX, 9, "T" }),
    ({ S_IXOTH|S_ISVTX, S_IXOTH|S_ISVTX, 9, "t" })
  });

  protected constant months = ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
			      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" });

  protected string name_from_uid(int uid)
  {
    string res;
    // NB: find_user_from_uid() can be quite slow(!), so we
    //     cache the result for the duration of the connection.
    if (!master_session->misc->username_from_uid) {
      master_session->misc->username_from_uid = ([]);
    } else if (res = master_session->misc->username_from_uid[uid]) {
      return res;
    }
    User user;
    foreach(master_session->conf->user_databases(), UserDB user_db) {
      if (user = user_db->find_user_from_uid(uid)) {
	master_session->misc->username_from_uid[uid] = res = user->name();
	return res;
      }
    }
    master_session->misc->username_from_uid[uid] = res =
      (uid?((string)uid):"root");
    return res;
  }

  string ls_l(string file, array st)
  {
    DWRITE("ls_l(\"%s\")\n", file);

    int mode = st[0] & 007777;
    array(string) perm = "----------"/"";

    if (st[1] < 0) {
      perm[0] = "d";
    }

    foreach(decode_mode, array(string|int) info) {
      if ((mode & info[0]) == info[1]) {
	perm[info[2]] = info[3];
      }
    }

    mapping lt = localtime(st[3]);

    // NOTE: SiteBuilder may set st[5] and st[6] to strings.
    string user = (string)st[5];
    string group = (string)st[6];
    if (!(flags & LS_FLAG_n)) {
      // Use symbolic names for uid and gid.
      if (!stringp(st[5])) {
	user = name_from_uid(st[5]);
      }

      if (!stringp(st[6])) {
	// FIXME: Convert st[6] to symbolic group name.
	if (!st[6]) group = "wheel";
      }
    }

    string ts;
    int now = time(1);
    // Half a year:
    //   365.25*24*60*60/2 = 15778800
    if ((st[3] <= now - 15778800) || (st[3] > now)) {
      // Month Day  Year
      ts = sprintf("%s %02d  %04d",
		   months[lt->mon], lt->mday, 1900+lt->year);
    } else {
      // Month Day Hour:minute
      ts = sprintf("%s %02d %02d:%02d",
		   months[lt->mon], lt->mday, lt->hour, lt->min);
    }

    if (flags & LS_FLAG_G) {
      // No group.
      return sprintf("%s   1 %-10s %12d %s %s\n", perm*"",
		     user, (st[1]<0? 512:st[1]),
		     ts, file);
    } else {
      return sprintf("%s   1 %-10s %-6s %12d %s %s\n", perm*"",
		     user, group, (st[1]<0? 512:st[1]),
		     ts, file);
    }
  }
}

class LSFile
{
  protected inherit LS_L;

  protected string cwd;
  protected array(string) argv;
  protected object ftpsession;

  protected array(string) output_queue = ({});
  protected int output_pos;
  protected string output_mode = "A";

  protected mapping(string:array|object) stat_cache = ([]);

  protected Charset.Encoder conv;

  protected array|object stat_file(string long, RequestID|void session)
  {
    array|object st = stat_cache[long];
    if (zero_type(st)) {
      session = RequestID2(session || master_session);
      session->method = "DIR";
      long = replace(long, "//", "/");
      st = session->conf->stat_file(long, session);
      stat_cache[long] = st;
      destruct(session);
    }
    return st;
  }

  // FIXME: Should convert output somewhere below.
  protected void output(string s)
  {
    if(stringp(s)) {
      // ls is always ASCII-mode...
      s = replace(s, "\n", "\r\n");
      if (conv) {
	// EBCDIC or potentially other charsets.
	s = conv->feed(s)->drain();
      }
    }
    output_queue += ({ s });
  }

  protected string quote_non_print(string s)
  {
    return(replace(s, ({
      "\000", "\001", "\002", "\003", "\004", "\005", "\006", "\007",
      "\010", "\011", "\012", "\013", "\014", "\015", "\016", "\017",
      "\200", "\201", "\202", "\203", "\204", "\205", "\206", "\207",
      "\210", "\211", "\212", "\213", "\214", "\215", "\216", "\217",
      "\177",
    }), ({
      "\\000", "\\001", "\\002", "\\003", "\\004", "\\005", "\\006", "\\007",
      "\\010", "\\011", "\\012", "\\013", "\\014", "\\015", "\\016", "\\017",
      "\\200", "\\201", "\\202", "\\203", "\\204", "\\205", "\\206", "\\207",
      "\\210", "\\211", "\\212", "\\213", "\\214", "\\215", "\\216", "\\217",
      "\\177",
    })));
  }

  protected string list_files(array(string) files, string|void dir)
  {
    dir = dir || cwd;

    DWRITE("FTP: LSFile->list_files(%O, \"%s\"\n", files, dir);

    if (!(flags & LS_FLAG_U)) {
      if (flags & LS_FLAG_S) {
	array(int) sizes = allocate(sizeof(files));
	int i;
	for (i=0; i < sizeof(files); i++) {
	  array|object st = stat_file(combine_path(dir, files[i]));
	  if (st) {
	    sizes[i] = st[1];
	  } else {
	    // Should not happen, but...
	    files -= ({ files[i] });
	  }
	}
	sort(sizes, files);
      } else if (flags & LS_FLAG_t) {
	array(int) times = allocate(sizeof(files));
	int i;
	for (i=0; i < sizeof(files); i++) {
	  array|object st = stat_file(combine_path(dir, files[i]));
	  if (st) {
	    times[i] = -st[-4];	// Note: Negative time.
	  } else {
	    // Should not happen, but...
	    files -= ({ files[i] });
	  }
	}
	sort(times, files);
      } else {
	sort(files);
      }
      if (flags & LS_FLAG_r) {
	files = reverse(files);
      }
    }

    string res = "";
    int total;
    foreach(files, string short) {
      string long = combine_path(dir, short);
      array|object st = stat_file(long);
      if (st) {
	if (flags & LS_FLAG_Q) {
	  // Enclose in quotes.
	  // Space needs to be quoted to be compatible with -m
	  short = "\"" +
	    replace(short,
		    ({ "\n", "\r", "\\", "\"", "\'", " " }),
		    ({ "\\n", "\\r", "\\\\", "\\\"", "\\\'", "\\020" })) +
	    "\"";
	}
	if (flags & LS_FLAG_F) {
	  if (st[1] < 0) {
	    // Directory
	    short += "/";
	  } else if (st[0] & 0111) {
	    // Executable
	    short += "*";
	  }
	}
	int blocks = 1;
	if (st[1] >= 0) {
	  blocks = (st[1] + 1023)/1024;	// Blocks are 1KB.
	}
	total += blocks;
	if (flags & LS_FLAG_s) {
	  res += sprintf("%7d ", blocks);
	}
	if (flags & LS_FLAG_b) {
	  short = quote_non_print(short);
	}
	if (flags & LS_FLAG_l) {
	  res += ls_l(short, st);
	} else {
	  res += short + "\n";
	}
      }
    }
    switch (flags & (LS_FLAG_l|LS_FLAG_C|LS_FLAG_m)) {
    case LS_FLAG_C:
      res = sprintf("%#-79s\n", res);
      break;
    case LS_FLAG_m:
      res = sprintf("%=-79s\n", (res/"\n")*", ");
      break;
    case LS_FLAG_l:
      res = "total " + total + "\n" + res;
      break;
    default:
      break;
    }
    return(res);
  }

#if constant (ADT.Stack)
  protected ADT.Stack dir_stack = ADT.Stack();
#else
  protected object(Stack.stack) dir_stack = Stack.stack();
#endif
  protected int name_directories;

  protected string fix_path(string s)
  {
    return(combine_path(cwd, s));
  }

  protected int(0..1) list_next_directory()
  {
    if (dir_stack->ptr) {
      string short = dir_stack->pop();
      string long = fix_path(short);

      if ((!sizeof(long)) || (long[-1] != '/')) {
	long += "/";
      }
      RequestID session = RequestID2(master_session);
      session->method = "DIR";

      mixed err;
      mapping(string:array) dir;
      err = catch {
	dir = session->conf->find_dir_stat(long, session);
      };

      destruct(session);

      if (err) {
	report_error("FTP: LSFile->list_next_directory(): "
		     "find_dir_stat(\"%s\") failed:\n"
		     "%s\n", long, describe_backtrace(err));
      }

      DWRITE("FTP: LSFile->list_next_directory(): "
	     "find_dir_stat(\"%s\") => %O\n", long, dir);

      // Put them in the stat cache.
      foreach(indices(dir||({})), string f) {
	stat_cache[combine_path(long, f)] = dir[f];
      }

      dir = dir || ([]);

      if (flags & LS_FLAG_a) {
	if (long != "/") {
	  dir[".."] = stat_file(combine_path(long,"../"));
	}
	dir["."] = stat_file(combine_path(long));
      }

      string listing = "";
      if (sizeof(dir)) {
	if (!(flags & LS_FLAG_A)) {
	  foreach(indices(dir), string f) {
	    if (sizeof(f) && (f[0] == '.')) {
	      m_delete(dir, f);
	    }
	  }
	} else if (!(flags & LS_FLAG_a)) {
	  foreach(indices(dir), string f) {
	    if ((< ".", ".." >)[f]) {
	      m_delete(dir, f);
	    }
	  }
	}
	if (flags & LS_FLAG_R) {
	  foreach(indices(dir), string f) {
	    if (!((<".","..">)[f])) {
	      array(mixed) st = dir[f];
	      if (st && (st[1] < 0)) {
		if (short[-1] == '/') {
		  dir_stack->push(short + f);
		} else {
		  dir_stack->push(short + "/" + f);
		}
	      }
	    }
	  }
	}
	if (sizeof(dir)) {
	  listing = list_files(indices(dir), long);
	} else if (flags & LS_FLAG_l) {
	  listing = "total 0\n";
	}
      } else {
	DWRITE("FTP: LSFile->list_next_directory(): NO FILES!\n");

	if (flags & LS_FLAG_l) {
	  listing = "total 0\n";
	}
      }
      if (name_directories) {
	listing = "\n" + short + ":\n" + listing;
      }
      if (listing != "") {
	output(listing);
      }
      session = RequestID2(master_session);
      session->method = "LIST";
      session->not_query = long;
      session->conf->log(([ "error":200, "len":sizeof(listing) ]), session);
    }
    if (!dir_stack->ptr) {
      output(0);		// End marker.
      return 0;
    } else {
      name_directories = 1;
      return 1;
    }
  }

  void set_blocking()
  {
  }

  int query_fd()
  {
    return -1;
  }

  protected mixed id;

  void set_id(mixed i)
  {
    id = i;
  }

  void fill_output_queue()
  {
    if (!sizeof(output_queue) || output_queue[-1]) {
      while (list_next_directory())
	;
    }
  }

  string read(int|void n, int|void not_all)
  {
    DWRITE("FTP: LSFile->read(%d, %d)\n", n, not_all);

    ftpsession->touch_me();

    while(sizeof(output_queue) <= output_pos) {
      // Clean anything pending in the queue.
      output_queue = ({});
      output_pos = 0;

      // Generate some more output...
      list_next_directory();
    }
    string s = output_queue[output_pos];

    if (s) {
      if (n && (n < sizeof(s))) {
	output_queue[output_pos] = s[n..];
	s = s[..n-1];
      } else {
	output_queue[output_pos++] = 0;
      }
      return s;
    } else {
      // EOF
      master_session->file = 0;	// Avoid extra log-entry.
      return "";
    }
  }

  void create(string cwd_, array(string) argv_, int flags_,
	      object session_, string output_mode_, object ftpsession_)
  {
    DWRITE("FTP: LSFile(\"%s\", %O, %08x, X, \"%s\")\n",
	   cwd_, argv_, flags_, output_mode_);

    ::create(session_, flags_);

    cwd = cwd_;
    argv = argv_;
    output_mode = output_mode_;
    ftpsession = ftpsession_;

    if (output_mode == "E") {
      // EBCDIC
      conv = Charset.encoder("EBCDIC-US", "");
    }

    array(string) files = allocate(sizeof(argv));
    int n_files;

    foreach(argv, string short) {
      RequestID session = RequestID2(master_session);
      session->method = "LIST";
      string long = fix_path(short);
      array|object st = stat_file(long, session);
      if (st) {
	if ((< -2, -3 >)[st[1]] &&
	    (!(flags & LS_FLAG_d))) {
	  // Directory
	  dir_stack->push(short);
	} else {
	  files[n_files++] = short;
	}
      } else {
	output(short + ": not found\n");
	session->conf->log(([ "error":404 ]), session);
      }
      destruct(session);
    }

    DWRITE("FTP: LSFile: %d files, %d directories\n",
	   n_files, dir_stack->ptr);

    if (n_files) {
      if (n_files < sizeof(files)) {
	files -= ({ 0 });
      }
      string s = list_files(files, cwd);	// May modify dir_stack (-R)
      output(s);
      RequestID session = RequestID2(master_session);
      session->not_query = Array.map(files, fix_path) * " ";
      session->method = "LIST";
      session->conf->log(([ "error":200, "len":sizeof(s) ]), session);
      destruct(session);
    }
    if (dir_stack->ptr) {
      name_directories = dir_stack->ptr &&
	((dir_stack->ptr > 1) || n_files);

      list_next_directory();
    } else {
      output(0);
    }
  }
}

class TelnetSession {
  protected object fd;
  protected object conf;

  private mapping cb;
  private mixed id;
  protected function(mixed|void:string) write_cb;
  protected function(mixed, string:void) read_cb;
  protected function(mixed|void:void) close_cb;

  private constant TelnetCodes = ([
    236:"EOF",		// End Of File
    237:"SUSP",		// Suspend Process
    238:"ABORT",	// Abort Process
    239:"EOR",		// End Of Record

    // The following ones are specified in RFC 959:
    240:"SE",		// Subnegotiation End
    241:"NOP",		// No Operation
    242:"DM",		// Data Mark
    243:"BRK",		// Break
    244:"IP",		// Interrupt Process
    245:"AO",		// Abort Output
    246:"AYT",		// Are You There
    247:"EC",		// Erase Character
    248:"EL",		// Erase Line
    249:"GA",		// Go Ahead
    250:"SB",		// Subnegotiation
    251:"WILL",		// Desire to begin/confirmation of option
    252:"WON'T",	// Refusal to begin/continue option
    253:"DO",		// Request to begin/confirmation of option
    254:"DON'T",	// Demand/confirmation of stop of option
    255:"IAC",		// Interpret As Command
  ]);

  // Some prototypes needed by Pike 0.5
  private void got_data(mixed ignored, string s);
  private void send_data();
  private void got_oob(mixed ignored, string s);

  void set_write_callback(function(mixed|void:string) w_cb)
  {
    if (fd) {
      write_cb = w_cb;
      fd->set_nonblocking(got_data, w_cb && send_data, close_cb, got_oob);
    }
  }

  private string to_send = "";
  private void send(string s)
  {
    to_send += s;
  }

  private void send_data()
  {
    if (!sizeof(to_send)) {
      to_send = write_cb(id);
    }
    if (fd) {
      if (!to_send) {
	// Support for delayed close.
	BACKEND_CLOSE(fd);
      } else if (sizeof(to_send)) {
	int n = fd->write(to_send);

	if (n >= 0) {
	  conf->hsent += n;

	  to_send = to_send[n..];

	  if (sizeof(to_send)) {
	    fd->set_write_callback(send_data);
	  }
	} else {
	  // Error.
	  DWRITE("TELNET: write failed: errno:%d\n", fd->errno());
	  BACKEND_CLOSE(fd);
	}
      } else {
	// Nothing to send for the moment.

	// FIXME: Is this the correct use?
	fd->set_write_callback(0);

	report_warning("FTP2: Write callback with nothing to send.\n");
      }
    } else {
      report_error("FTP2: Write callback with no fd.\n");
      destruct();
    }
  }

  private mapping(string:function) default_cb = ([
    "BRK":lambda() {
	    if (fd) {
	      fd->close();
	      fd = 0;
	    }
	    destruct();
	    throw(0);
	  },
    "AYT":lambda() {
	    send("\377\361");	// NOP
	  },
    "WILL":lambda(int code) {
	      send(sprintf("\377\376%c", code));	// DON'T xxx
	   },
    "DO":lambda(int code) {
	   send(sprintf("\377\374%c", code));	// WON'T xxx
	 },
  ]);

  private int sync = 0;

  private void got_oob(mixed ignored, string s)
  {
    DWRITE("TELNET: got_oob(\"%s\")\n", s);

    sync = sync || (s == "\377");
    if (cb["URG"]) {
      cb["URG"](id, s);
    }
  }

  private string rest = "";
  private void got_data(mixed ignored, string s)
  {
    DWRITE("TELNET: got_data(\"%s\")\n", s);

    if (sizeof(s) && (s[0] == 242)) {
      DWRITE("TELNET: Data Mark\n");
      // Data Mark handing.
      s = s[1..];
      sync = 0;
    }

    // A single read() can contain multiple or partial commands
    // RFC 1123 4.1.2.10

    array lines = s/"\r\n";

    // Censor the raw string.
    s = sprintf("string(%d bytes)", sizeof(s));

    int lineno;
    for(lineno = 0; lineno < sizeof(lines); lineno++) {
      string line = lines[lineno];
      if (search(line, "\377") != -1) {
	array a = line / "\377";

	string parsed_line = a[0];
	int i;
	for (i=1; i < sizeof(a); i++) {
	  string part = a[i];
	  if (sizeof(part)) {
	    string name = TelnetCodes[part[0]];

	    DWRITE("TELNET: Code %s\n", name || "Unknown");

	    int j;
	    function fun;
	    switch (name) {
	    case 0:
	      // FIXME: Should probably have a warning here.
	      break;
	    default:
	      if (fun = (cb[name] || default_cb[name])) {
		mixed err = catch {
		  fun();
		};
		if (err) {
		  throw(err);
		} else if (!zero_type(err)) {
		  // We were just destructed.
		  return;
		}
	      }
	      a[i] = a[i][1..];
	      break;
	    case "EC":	// Erase Character
	      for (j=i; j--;) {
		if (sizeof(a[j])) {
		  a[j] = a[j][..sizeof(a[j])-2];
		  break;
		}
	      }
	      a[i] = a[i][1..];
	      break;
	    case "EL":	// Erase Line
	      for (j=0; j < i; j++) {
		a[j] = "";
	      }
	      a[i] = a[i][1..];
	      break;
	    case "WILL":
	    case "WON'T":
	    case "DO":
	    case "DON'T":
	      if (fun = (cb[name] || default_cb[name])) {
		fun(a[i][1]);
	      }
	      a[i] = a[i][2..];
	      break;
	    case "DM":	// Data Mark
	      if (sync) {
		for (j=0; j < i; j++) {
		  a[j] = "";
		}
	      }
	      a[i] = a[i][1..];
	      sync = 0;
	      break;
	    }
	  } else {
	    a[i] = "\377";
	    i++;
	  }
	}
	line = a * "";
      }
      if (!lineno) {
	line = rest + line;
      }
      if (lineno < (sizeof(lines)-1)) {
	if ((!sync) && read_cb) {
	  DWRITE("TELNET: Calling read_callback(X, \"%s\")\n", line);
	  read_cb(id, line);
	}
      } else {
	DWRITE("TELNET: Partial line is \"%s\"\n", line);
	rest = line;
      }
    }
  }

  void create(object f,
	      function(mixed,string:void) r_cb,
	      function(mixed|void:string) w_cb,
	      function(mixed|void:void) c_cb,
	      mapping callbacks, mixed|void new_id)
  {
    fd = f;
    cb = callbacks;

    read_cb = r_cb;
    write_cb = w_cb;
    close_cb = c_cb;
    id = new_id;

    fd->set_nonblocking(got_data, w_cb && send_data, close_cb, got_oob);
  }
};

class FTPSession
{
  // However, a server-FTP MUST be capable of
  // accepting and refusing Telnet negotiations (i.e., sending
  // DON'T/WON'T). RFC 1123 4.1.2.12

  inherit TelnetSession;

  inherit "roxenlib";

  private constant cmd_help = ([
    // FTP commands in reverse RFC order.

    // The following is a command suggested by the author of ncftp.
    "CLNT":"<sp> <client-name> <sp> <client-version> "
    "[<sp> <optional platform info>] (Set client name)",

    // The following are in
    // "Extended Directory Listing, TVFS, and Restart Mechanism for FTP"
    // IETF draft 4.
    "FEAT":"(Feature list)",
    "MDTM":"<sp> path-name (Modification time)",
    "SIZE":"<sp> path-name (Size)",
    "MLST":"<sp> path-name (Machine Processing List File)",
    "MLSD":"<sp> path-name (Machine Processing List Directory)",
    "OPTS":"<sp> command <sp> options (Set Command-specific Options)",

    // These are from RFC 2428
    "EPRT":"<sp> <d>net-prt<d>net-addr<d>tcp-port<d> (Extended Address Port)",
    "EPSV":"[<sp> net-prt|ALL] (Extended Address Passive Mode)",

    // These are from RFC 2228 (FTP Security Extensions)
    "AUTH":"security-mechanism (Authentication/Security Mechanism)",
    "ADAT":"security-data (Authentication/Security Data)",
    "PBSZ":"<sp> size (Protection Buffer SiZe)",
    "PROT":"<sp> [ C | S | E | P ] (Data Channel Protection Level)",
    "CCC":"(Clear Command Channel)",
    "MIC":"command (Integrity Protected Command)",
    "CONF":"command (Confidentiality Protected Command)",
    "ENC":"command (Privacy Protected Command)",

    // These are in RFC 1639
    "LPRT":"<sp> <long-host-port> (Long Port)",
    "LPSV":"(Long Passive)",

    // Commands in the order from RFC 959

    // Login
    "USER":"<sp> username (Change user)",
    "PASS":"<sp> password (Change password)",
    "ACCT":"<sp> <account-information> (Account)",
    "CWD":"[ <sp> directory-name ] (Change working directory)",
    "CDUP":"(Change to parent directory)",
    "SMNT":"<sp> <pathname> (Structure mount)",
    // Logout
    "REIN":"(Reinitialize)",
    "QUIT":"(Terminate service)",
    // Transfer parameters
    "PORT":"<sp> b0, b1, b2, b3, b4 (Set port IP and number)",
    "PASV":"(Set server in passive mode)",
    "TYPE":"<sp> [ A | E | I | L ] (Ascii, Ebcdic, Image, Local)",
    "STRU":"<sp> <structure-code> (File structure)",
    "MODE":"<sp> <mode-code> (Transfer mode)",
    // File action commands
    "ALLO":"<sp> <decimal-integer> [<sp> R <sp> <decimal-integer>]"
    " (Allocate space for file)",
    "REST":"<sp> marker (Set restart marker)",
    "STOR":"<sp> file-name (Store file)",
    "STOU":"(Store file with unique name)",
    "RETR":"<sp> file-name (Retreive file)",
    "LIST":"[ <sp> <pathname> ] (List directory)",
    "NLST":"[ <sp> <pathname> ] (List directory)",
    "APPE":"<sp> <pathname> (Append file)",
    "RNFR":"<sp> <pathname> (Rename from)",
    "RNTO":"<sp> <pathname> (Rename to)",
    "DELE":"<sp> file-name (Delete file)",
    "RMD":"<sp> <pathname> (Remove directory)",
    "MKD":"<sp> <pathname> (Make directory)",
    "PWD":"(Return current directory)",
    "ABOR":"(Abort current transmission)",
    // Informational commands
    "SYST":"(Get type of operating system)",
    "STAT":"[ <sp> <pathname> ] (Status for server/file)",
    "HELP":"[ <sp> <string> ] (Give help)",
    // Miscellaneous commands
    "SITE":"<sp> <string> (Site parameters)",	// Has separate help
    "NOOP":"(No operation)",

    // Old "Experimental commands"
    // These are in RFC 775
    // Required by RFC 1123 4.1.3.1
    "XMKD":"<sp> path-name (Make directory)",
    "XRMD":"<sp> path-name (Remove directory)",
    "XPWD":"(Return current directory)",
    "XCWD":"[ <sp> directory-name ] (Change working directory)",
    "XCUP":"(Change to parent directory)",

    // These are in RFC 765 but not in RFC 959
    "MAIL":"[<sp> <recipient name>] (Mail to user)",
    "MSND":"[<sp> <recipient name>] (Mail send to terminal)",
    "MSOM":"[<sp> <recipient name>] (Mail send to terminal or mailbox)",
    "MSAM":"[<sp> <recipient name>] (Mail send to terminal and mailbox)",
    "MRSQ":"[<sp> <scheme>] (Mail recipient scheme question)",
    "MRCP":"<sp> <recipient name> (Mail recipient)",

    // These are in RFC 743
    "XRSQ":"[<sp> <scheme>] (Scheme selection)",
    "XRCP":"<sp> <recipient name> (Recipient specification)",

    // These are in RFC 737
    "XSEN":"[<sp> <recipient name>] (Send to terminal)",
    "XSEM":"[<sp> <recipient name>] (Send, mail if can\'t)",
    "XMAS":"[<sp> <recipient name>] (Mail and send)",

    // These are in RFC 542
    "BYE":"(Logout)",
    "BYTE":"<sp> <bits> (Byte size)",
    "SOCK":"<sp> host-socket (Data socket)",

#if 0
    // These are in RFC 475
    "MLTO":"<sp> <recipient name> (Initiate mail to user)",
    "FROM":"<sp> <sender name> (Mail from)",
    "MTYP":"<sp> [ U | O | L ] (Mail type)",
    "RECO":"[<sp> <mail unique id>] (Mail record)",
#if 0
    // NB: Conflicts with AUTH from RFC 2228 above.
    "AUTH":"<sp> <author id> (Mail author)",
#endif
    "TITL":"<sp> <title> (Mail title/subject)",
    "ACKN":"(Mail acknowledge)",
    "TEXT":"(Mail text)",
    "FILE":"<sp> <filename> (Mail file)",
    "CITA":"<sp> <file name> (Mail citation)",
#endif

    // This one is referenced in a lot of old RFCs
    "MLFL":"(Mail file)",
  ]);

  private constant site_help = ([
    "CHMOD":"<sp> mode <sp> file",
    "UMASK":"<sp> mode",
    "PRESTATE":"<sp> prestate",
  ]);

  private constant opts_help = ([
    "MLST":"<sp> <fact-list>",
  ]);

  private constant modes = ([
    "A":"ASCII",
    "E":"EBCDIC",
    "I":"BINARY",
    "L":"LOCAL",
  ]);

  private int time_touch = time();

  private object(ADT.Queue) to_send = ADT.Queue();

  private int end_marker = 0;

  void touch_me()
  {
    time_touch = time();
  }

  private string write_cb()
  {
    touch_me();

    if (to_send->is_empty()) {

      DWRITE("FTP2: write_cb(): Empty send queue.\n");

      ::set_write_callback(0);
      if (end_marker) {
	DWRITE("FTP2: write_cb(): Sending EOF.\n");
	return(0);	// Mark EOF
      }
      DWRITE("FTP2: write_cb(): Sending \"\"\n");
      return("");	// Shouldn't happen, but...
    } else {
      string|int s = to_send->get();

      if (s == 1) {
	DWRITE("FTP2: write_cb(): STARTTLS.\n");

	// NB: This callback is only called when the send buffers
	//     are empty, and it is thus safe to switch to TLS.

	// Switch to TLS.
	if (!fd->renegotiate) {
#if constant(SSL.File)
	  fd = SSL.File(fd, port_obj->ctx);
	  master_session->my_fd = fd;
	  fd->accept();
#else
	  fd = SSL.sslfile(fd, port_obj->ctx);
#endif
	}
	// Restore the callbacks in the new SSL connection.
	::set_write_callback(write_cb);
	return "";
      } else if (s == 2) {
	DWRITE("FTP2: write_cb(): ENDTLS.\n");

	if (fd->renegotiate &&
	    !has_prefix(sprintf("%O", port_obj), "SSLProtocol")) {
	  // Deactive StartTLS connection.
	  master_session->my_fd = fd = fd->shutdown();

	  if (fd) {
	    // Move the callbacks back to the raw connection.
	    ::set_write_callback(write_cb);
	  }
	}
	return "";
      }

      DWRITE("FTP2: write_cb(): Sending %O.\n", s);

      if ((to_send->is_empty()) && (!end_marker)) {
	::set_write_callback(0);
      } else if (stringp(to_send->peek())) {
	// Not about to switch TLS mode.
	::set_write_callback(write_cb);
      }
      return(s);
    }
  }

  int(0..1) busy;

#ifdef FTP_USE_HANDLER_THREADS
#define next_cmd()	call_out(low_next_cmd, 0)
#else
#define low_next_cmd()	next_cmd()
#endif

  void low_send(int code, array(string) data, int|void enumerate_all)
  {
    DWRITE("FTP2: low_send(%d, %O)\n", code, data);

    if (!data || end_marker) {
      end_marker = 1;
      ::set_write_callback(write_cb);
      return;
    }

    string s;
    int i;
    if (sizeof(data) > 1) {
      data[0] = sprintf("%03d-%s\r\n", code, data[i]);
      for (i = sizeof(data)-1; --i; ) {
	if (enumerate_all) {
	  data[i] = sprintf("%03d-%s\r\n", code, data[i]);
	} else {
	  data[i] = " " + data[i] + "\r\n";
	}
      }
    }
    data[sizeof(data)-1] = sprintf("%03d %s\r\n", code, data[sizeof(data)-1]);
    s = data * "";

    if (sizeof(s)) {
      if (to_send->is_empty()) {
	to_send->put(s);
	::set_write_callback(write_cb);
      } else {
	to_send->put(s);
      }
    } else {
      DWRITE("FTP2: send(): Nothing to send!\n");
    }
  }

  void send(int code, array(string) data, int|void enumerate_all)
  {
    DWRITE("FTP2: send(%d, %O)\n", code, data);

    low_send(code, data, enumerate_all);

    if (code >= 200) {
      // Command finished, get the next.
      busy = 0;
      next_cmd();
    }
  }

  private RequestID master_session;

  private string dataport_addr;
  private int dataport_port;

  private string mode = "A";

  private string cwd = "/";

  private User auth_user;
  // Authenticated user.

  private string user;
  private string password;
  private int logged_in;

  private object curr_pipe;
  private int restart_point;

  private multiset|int allowed_shells = 0;

  // On a multihomed server host, the default data transfer port
  // (L-1) MUST be associated with the same local IP address as
  // the corresponding control connection to port L.
  // RFC 1123 4.1.2.12
  string local_addr;
  int local_port;
  string e_mode = "1";	/* IPv4 */

  // The listen port object
  roxen.Protocol port_obj;

  /*
   * Misc
   */

  private int check_shell(string shell)
  {
    // FIXME: Should the shell database be protocol specific or
    // virtual-server specific?
    if (port_obj->query_option("shells") != "") {
      // FIXME: Hmm, the cache will probably be empty almost always
      // since it's part of the FTPsession object.
      // Oh, well, shouldn't matter much unless you have *lots* of
      // shells.
      //	/grubba 1998-05-21
      if (!allowed_shells) {
	object(Stdio.File) file = Stdio.File();

	if (file->open(port_obj->query_option("shells"), "r")) {
	  allowed_shells =
	    aggregate_multiset(@(Array.map(file->read(0x7fffffff)/"\n",
					   lambda(string line) {
					     return(((((line/"#")[0])/"") -
						     ({" ", "\t"}))*"");
					   } )-({""})));
	  DWRITE("ftp.pike: allowed_shells: %O\n", allowed_shells);
	} else {
	  report_debug("ftp.pike: Failed to open shell database (%O)\n",
		       port_obj->query_option("shells"));
	  return 0;
	}
      }
      return(allowed_shells[shell]);
    }
    return 1;
  }

  private string fix_path(string s)
  {
    if (!sizeof(s)) {
      if (cwd[-1] == '/') {
	return(cwd);
      } else {
	return(cwd + "/");
      }
    } else if (s[0] == '~') {
      return(combine_path("/", s));
    } else if (s[0] == '/') {
      return(simplify_path(s));
    } else {
      return(combine_path(cwd, s));
    }
  }

  /*
   * PASV handling
   */
  private object pasv_port;
  private function(object, mixed ...:void) pasv_callback;
  private mixed pasv_args;
  private array(object) pasv_accepted = ({});

  void pasv_accept_callback(mixed id)
  {
    DWRITE("FTP: pasv_accept_callback(%O)...\n", id);
    touch_me();

    if(pasv_port) {
      object fd = pasv_port->accept();
      if(fd) {
	// On a multihomed server host, the default data transfer port
	// (L-1) MUST be associated with the same local IP address as
	// the corresponding control connection to port L.
	// RFC 1123 4.1.2.12

	array(string) remote = (fd->query_address()||"? ?")/" ";
#ifdef FD_DEBUG
	mark_fd(fd->query_fd(),
		"ftp communication: -> "+remote[0]+":"+remote[1]);
#endif
	if(pasv_callback) {
	  pasv_callback(fd, "", @pasv_args);
	  pasv_callback = 0;
	} else {
	  pasv_accepted += ({ fd });
	}
      }
    }
  }

  private void ftp_async_accept(function(object,mixed ...:void) fun,
				mixed ... args)
  {
    DWRITE("FTP: async_accept(%O, %@O)...\n", fun, args);
    touch_me();

    if (sizeof(pasv_accepted)) {
      fun(pasv_accepted[0], "", @args);
      pasv_accepted = pasv_accepted[1..];
    } else {
      pasv_callback = fun;
      pasv_args = args;
    }
  }

  /*
   * PORT handling
   */

  private void ftp_async_connect(function(object,string,mixed ...:void) fun,
				 mixed ... args)
  {
    DWRITE("FTP: async_connect(%O, %@O)...\n", fun, args);

    // More or less copied from socket.pike

    if (!dataport_addr) {
      DWRITE("FTP: No dataport specified.\n");
      fun(0, "", @args);
      return;
    }

    object(Stdio.File)|object(SSL.File) f = Stdio.File();

    // FIXME: Race-condition: open_socket() for other connections will fail
    //        until the socket has been connected.

    object privs;
    if(local_port-1 < 1024 && geteuid())
      privs = Privs("FTP: Opening the data connection on " + local_addr +
		    ":" + (local_port-1) + ".");

    if(!f->open_socket(local_port-1, local_addr))
    {
      privs = 0;
      DWRITE("FTP: socket(%d, %O) failed. Trying with any port.\n",
	     local_port-1, local_addr);

      if(!f->open_socket(0, local_addr))
      {
	DWRITE("FTP: socket(0, %O) failed. "
	       "Trying with any port, any ip.\n", local_addr);
	if (!f->open_socket()) {
	  DWRITE("FTP: socket() failed. Out of sockets?\n");
	  fun(0, 0, @args);
	  destruct(f);
	  return;
	}
      }
    }
    privs = 0;

    Stdio.File raw_connection = f;

    f->set_nonblocking(lambda(mixed ignored, string data) {
			 DWRITE("FTP: async_connect ok. Got data.\n");
			 f->set_nonblocking(0,0,0,0,0);
			 fun(f, data, @args);
		       },
		       lambda(mixed ignored) {
			 DWRITE("FTP: async_connect ok.\n");
			 f->set_nonblocking(0,0,0,0,0);
			 fun(f, "", @args);
		       },
		       lambda(mixed ignored) {
			 DWRITE("FTP: connect_and_send failed: %s (%d)\n",
				strerror(f->errno()), f->errno());
			 destruct(f);
			 fun(0, 0, @args);
		       },
		       lambda(mixed ignored) {
			 DWRITE("FTP: connect_and_send failed (oob): %s (%d)\n",
				strerror(f->errno()), f->errno());
			 destruct(f);
			 fun(0, 0, @args);
		       });

#ifdef FD_DEBUG
    mark_fd(raw_connection->query_fd(),
	    sprintf("ftp communication: %s:%d -> %s:%d",
		    local_addr, local_port - 1,
		    dataport_addr, dataport_port));
#endif

    if(mixed err = catch{
	if (!(raw_connection->connect(dataport_addr, dataport_port))) {
	  DWRITE("FTP: connect(%O, %O) failed with: %s!\n"
		 "FTP: local_addr: %O:%O (%O)\n",
		 dataport_addr, dataport_port,
		 strerror(raw_connection->errno()),
		 local_addr, local_port-1,
		 raw_connection->is_open() && raw_connection->query_address(1));
	  destruct(f);
	  fun(0, 0, @args);
	  return;
	}
      }) {
      DWRITE("FTP: Illegal IP address (%s:%d) in async connect.\n",
	     dataport_addr||"", dataport_port);
      DWRITE("FTP: %s\n", describe_backtrace(err));
      destruct(f);
      fun(0, 0, @args);
      return;
    }
  }

  /*
   * Data connection handling
   */

  enum SSLMode {
    SSL_NONE = 0,
    SSL_ACTIVE = 1,
    SSL_PASSIVE = 2,
    SSL_ALL = 3,
  };

  // Set to SSL_ALL by PROT S,E and P.
  // Cleared by PROT C.
  // Set to SSL_ACTIVE by AUTH SSL.
  SSLMode use_ssl;

  private void send_done_callback(array(object) args)
  {
    DWRITE("FTP: send_done_callback()\n");

    object fd = args[0];
    object session = args[1];

    if(fd)
    {
      //DWRITE("FTP: fd: %O: %O\n", fd, mkmapping(indices(fd), values(fd)));
      if (fd->set_blocking) {
	fd->set_blocking();       // Force close() to flush any buffers.
      }
      call_out(fd->close, 0);
      fd = 0;
      //BACKEND_CLOSE(fd);
    }
    curr_pipe = 0;

    if (session && session->file) {
      session->conf->log(session->file, session);
      session->file = 0;
    }
    destruct(session);
    send(226, ({ "Transfer complete." }));
  }

  private mapping|array|object stat_file(string fname,
					 object|void session)
  {
    mapping file;

    session = RequestID2(session || master_session);
    session->method = "STAT";
    session->not_query = fname;

    foreach(conf->first_modules(), function funp) {
      if ((file = funp(session))) {
	break;
      }
    }

    if (!file) {
      fname = replace(fname, "//", "/");
      file = conf->stat_file(fname, session);
    }
    destruct(session);
    return file;
  }

  private int expect_argument(string cmd, string args)
  {
    if ((< "", 0 >)[args]) {
      send(504, ({ sprintf("Syntax: %s %s", cmd, cmd_help[cmd]) }));
      return 0;
    }
    return 1;
  }

  private void send_error(string cmd, string f, mapping file,
			  object session)
  {
    switch(file && file->error) {
    case 301:
    case 302:
      if (file->extra_heads && file->extra_heads->Location) {
	send(504, ({ sprintf("'%s': %s: Redirect to %O.",
			     cmd, f, file->extra_heads->Location) }));
      } else {
	send(504, ({ sprintf("'%s': %s: Redirect.", cmd, f) }));
      }
      break;
    case 401:
      send(530, ({ sprintf("'%s': %s: Access denied.",
			   cmd, f) }));
      break;
    case 403:
      send(451, ({ sprintf("'%s': %s: Forbidden.",
			   cmd, f) }));
      break;
    case 405:
      send(550, ({ sprintf("'%s': %s: Method not allowed.",
			   cmd, f) }));
      break;
    case 500:
      send(451, ({ sprintf("'%s': Requested action aborted: "
			   "local error in processing.", cmd) }));
      break;
    default:
      if (!file) {
	file = ([ "error":404 ]);
      }
      send(550, ({ sprintf("'%s': %s: No such file or directory.",
			   cmd, f) }));
      break;
    }
    session->conf->log(file, session);
  }

  private mapping open_file(string fname, object session, string cmd)
  {
    object|array|mapping file;

    file = stat_file(fname, session);

    // The caller is assumed to have made a new session object for us
    // but not to set not_query in it..
    session->not_query = fname;

    if (objectp(file) || arrayp(file)) {
      array|object st = file;
      file = 0;
      if (st && (st[1] < 0) && !((<"RMD", "XRMD", "CHMOD">)[cmd])) {
	send(550, ({ sprintf("%s: not a plain file.", fname) }));
	return 0;
      }
      mixed err;
      if ((err = catch(file = conf->get_file(session)))) {
	report_error("FTP: Error opening file \"%s\"\n"
		     "%s\n", fname, describe_backtrace(err));
	send(550, ({ sprintf("%s: Error, can't open file.", fname) }));
	return 0;
      }
    } else if ((< "STOR", "APPE", "MKD", "XMKD", "MOVE" >)[cmd]) {
      mixed err;
      if ((err = catch(file = conf->get_file(session)))) {
	report_error("FTP: Error opening file \"%s\"\n"
		     "%s\n", fname, describe_backtrace(err));
	send(550, ({ sprintf("%s: Error, can't open file.", fname) }));
	return 0;
      }
    }

    // file is a mapping.

    session->file = file;

    if (!file || (file->error && (file->error >= 300))) {
      DWRITE("FTP: open_file(\"%s\") failed: %O\n", fname, file);
      send_error(cmd, fname, file, session);
      return 0;
    }

    //  If data is a wide string we flatten it according to the charset
    //  preferences in the current ID object.
    if (file->data && String.width(file->data) > 8)
      file->data = session->output_encode(file->data, 0)[1];
    
    file->full_path = fname;
    file->request_start = time(1);

    if (!file->len) {
      if (file->data) {
	file->len = sizeof(file->data);
      }
      if (objectp(file->file)) {
	file->len += file->file->stat()[1];
      }
    }

    return file;
  }

  private void connected_to_send(object fd, string ignored,
				 mapping file, object session)
  {
    DWRITE("FTP: connected_to_send(%O, %O, %O, X)\n", fd, ignored, file);

    touch_me();

    if(!file->len)
      file->len = file->data?(stringp(file->data)?strlen(file->data):0):0;

    if (!file->mode) {
      file->mode = mode;
    }

    if(fd)
    {
      if (file->len) {
	send(150, ({ sprintf("Opening %s data connection for %s (%d bytes).",
			     modes[file->mode], file->full_path, file->len) }));
      } else {
	send(150, ({ sprintf("Opening %s mode data connection for %s",
			     modes[file->mode], file->full_path) }));
      }

      SSLMode ssl_mask = SSL_ACTIVE;
      if (pasv_port) ssl_mask = SSL_PASSIVE;

      if (use_ssl & ssl_mask) {
	DWRITE("FTP: Initiating SSL/TLS connection.\n");

	// RFC 4217 7:
	// For i) and ii), the FTP client MUST be the TLS client and the FTP
	// server MUST be the TLS server.
	//
	// That is to say, it does not matter which side initiates the
	// connection with a connect() call or which side reacts to the
	// connection via the accept() call; the FTP client, as defined in
	// [RFC-959], is always the TLS client, as defined in [RFC-2246].
#if constant(SSL.File)
	fd = SSL.File(fd, port_obj->ctx);
	fd->accept();
#else
	fd = SSL.sslfile(fd, port_obj->ctx);
#endif
	DWRITE("FTP: Created an sslfile: %O\n", fd);
      }
    }
    else
    {
      send(425, ({ "Can't build data connect: Connection refused." }));
      destruct(session);
      return;
    }
    switch(file->mode) {
    case "A":
      if (file->data) {
	file->data = replace(file->data,
			     ({ "\r\n", "\n",   "\r" }),
			     ({ "\r\n", "\r\n", "\r\n" }));
      }
      if(objectp(file->file) && file->file->set_nonblocking)
      {
	// The list_stream object doesn't support nonblocking I/O,
	// but converts to ASCII anyway, so we don't have to do
	// anything about it.
	file->file = ToAsciiWrapper(file->file, 0, this_object());
      }
      break;
    case "E":
      // EBCDIC handling here.
      if (file->data) {
	Charset.Encoder conv = Charset.encoder("EBCDIC-US", "");
	file->data = conv->feed(file->data)->drain();
      }
      if(objectp(file->file) && file->file->set_nonblocking)
      {
	// The list_stream object doesn't support nonblocking I/O,
	// but converts to ASCII anyway, so we don't have to do
	// anything about it.
	// But EBCDIC doen't work...
	file->file = ToEBCDICWrapper(file->file, 0, this_object());
      }
      break;
    default:
      // "I" and "L"
      // Binary -- no conversion needed.
      if (objectp(file->file) && file->file->set_nonblocking) {
	file->file = BinaryWrapper(file->file, 0, this_object());
      }
      break;
    }

#ifndef DISABLE_FTP_THROTTLING
    mapping throttle=session->throttle||([]);
    object pipe;
    if ( conf &&
         ((throttle->doit && conf->query("req_throttle")) ||
          conf->throttler
          ) ) {
//       report_debug("ftp: using slowpipe\n");
      pipe=((program)"slowpipe")();
    } else {
//       report_debug("ftp: using fastpipe\n");
      pipe=((program)"fastpipe")(); //will use Stdio.sendfile if possible
      throttle->doit=0;
    }
    if (throttle->doit) {
      throttle->rate=max(throttle->rate,
                         conf->query("req_throttle_min"));
      pipe->throttle(throttle->rate,
                     (int)(throttle->rate*
                           conf->query("req_throttle_depth_mult")),
                     0);
    }
    if (conf && conf->throttler) { //we are sure to be using slowpipe
      pipe->assign_throttler(conf->throttler);
    }
#else
    object pipe=((program)"fastpipe")();
#endif

    pipe->set_done_callback(send_done_callback, ({ fd, session }) );
    master_session->file = session->file = file;
    if(stringp(file->data)) {
      pipe->write(file->data);
    }
    if(file->file) {
      file->file->set_blocking();
      pipe->input(file->file, file->len);
    }
    curr_pipe = pipe;
    pipe->output(fd);
  }

  private void connected_to_receive(object fd, string data, string args)
  {
    DWRITE("FTP: connected_to_receive(X, %O, %O)\n", data, args);

    touch_me();

    if (fd) {
      send(150, ({ sprintf("Opening %s mode data connection for %s.",
			   modes[mode], args) }));

      SSLMode ssl_mask = SSL_ACTIVE;
      if (pasv_port) ssl_mask = SSL_PASSIVE;

      if (use_ssl & ssl_mask) {
	DWRITE("FTP: Initiating SSL/TLS connection.\n");

#if constant(SSL.File)
	fd = SSL.File(fd, port_obj->ctx);
	fd->accept();
#else
	fd = SSL.sslfile (fd, port_obj->ctx);
#endif
	DWRITE("FTP: Created an sslfile: %O\n", fd);
      }
    } else {
      send(425, ({ "Can't build data connect: Connection refused." }));
      return;
    }

    data = data && sizeof(data) && data;

    switch(mode) {
    case "A":
      fd = FromAsciiWrapper(fd, data, this_object());
      break;
    case "E":
      fd = FromEBCDICWrapper(fd, data, this_object());
      return;
    default:	// "I" and "L"
      // Binary, no need to do anything.
      fd = BinaryWrapper(fd, data, this_object());
      break;
    }

    RequestID session = RequestID2(master_session);
    session->method = "PUT";
    session->my_fd = PutFileWrapper(fd, session, this_object());
    session->misc->len = 0x7fffffff;

    mapping file;
    if (file = open_file(args, session, "STOR")) {
      if (!(file->pipe)) {
	if (fd) {
	  BACKEND_CLOSE(fd);
	}
	switch(file->error) {
	case 401:
	  send(530, ({ sprintf("%s: Need account for storing files.", args)}));
	  break;
	case 413:
	  send(550, ({ sprintf("%s: Quota exceeded.", args) }));
	  break;
	case 501:
	  send(502, ({ sprintf("%s: Command not implemented.", args) }));
	  break;
	default:
	  send(550, ({ sprintf("%s: Error opening file.", args) }));
	  break;
	}
	session->conf->log(file, session);
	destruct(session);
	return;
      }
      master_session->file = file;
    } else {
      // Error message has already been sent.
      if (fd) {
	BACKEND_CLOSE(fd);
      }
      destruct(session);
    }
  }

  private void discard_data_connection() {
    if(pasv_port && sizeof(pasv_accepted))
      pasv_accepted = pasv_accepted[1..];
  }

  private void connect_and_send(mapping file, object session)
  {
    DWRITE("FTP: connect_and_send(%O)\n", file);

    if (pasv_port) {
      ftp_async_accept(connected_to_send, file, session);
    } else {
      ftp_async_connect(connected_to_send, file, session);
    }
  }

  private void connect_and_receive(string arg)
  {
    DWRITE("FTP: connect_and_receive(\"%s\")\n", arg);

    if (pasv_port) {
      ftp_async_accept(connected_to_receive, arg);
    } else {
      ftp_async_connect(connected_to_receive, arg);
    }
  }

  /*
   * Command-line simulation
   */

  // NOTE: base is modified destructably!
  array(string) my_combine_path_array(array(string) base, string part)
  {
    if ((part == ".") || (part == "")) {
      if ((part == "") && (!sizeof(base))) {
        return(({""}));
      } else {
        return(base);
      }
    } else if ((part == "..") && sizeof(base) &&
               (base[-1] != "..") && (base[-1] != "")) {
      base[-1] = part;
      return(base);
    } else {
      return(base + ({ part }));
    }
  }

  private string my_combine_path(string base, string part)
  {
    if ((sizeof(part) && (part[0] == '/')) ||
        (sizeof(base) && (base[0] == '/'))) {
      return(combine_path(base, part));
    }
    // Combine two relative paths.
    int i;
    array(string) arr = ((base/"/") + (part/"/")) - ({ ".", "" });
    foreach(arr, string part) {
      if ((part == "..") && i && (arr[i-1] != "..")) {
        i--;
      } else {
        arr[i++] = part;
      }
    }
    if (i) {
      return(arr[..i-1]*"/");
    } else {
      return("");
    }
  }

  private constant IFS = (<" ", "\t">);
  private constant Quote = (< "\'", "\"", "\`", "\\" >);
  private constant Specials = IFS|Quote;

  private array(string) split_command_line(string cmdline)
  {
    // Check if we need to handle quoting at all...
    int need_quoting;
    foreach(indices(Quote), string c) {
      if (need_quoting = (search(cmdline, c) >= 0)) {
	break;
      }
    }
    if (!need_quoting) {
      // The easy case...
      return ((replace(cmdline, "\t", " ")/" ") - ({ "" }));
    }

    array(string) res = ({});
    string arg = 0;
    int argstart = 0;
    int i;
    for(i=0; i < sizeof(cmdline); i++) {
      string c;
      if (Specials[c = cmdline[i..i]]) {
	if (argstart < i) {
	  arg = (arg || "") + cmdline[argstart..i-1];
	}
	switch(c) {
	case "\"":
	case "\'":
	case "\`":
	  // NOTE: We handle all of the above as \'.
	  int j = search(cmdline, c, i+1);
	  if (j == -1) {
	    // No endquote!
	    // Simulate one at EOL.
	    j = sizeof(cmdline);
	  }
	  arg = (arg || "") + cmdline[i+1..j-1];
	  i = j;
	  break;
	case "\\":
	  i++;
	  arg += cmdline[i..i];
	  break;
	case " ":
	case "\t":
	  // IFS
	  if (arg) {
	    res += ({ arg });
	    arg = 0;
	  }
	  break;
	}
	argstart = i+1;
      }
    }
    if (argstart < i) {
      arg = (arg || "") + cmdline[argstart..];
    }
    if (arg) {
      res += ({ arg });
    }
    return res;
  }

  private array(string) glob_expand_command_line(string cmdline)
  {
    DWRITE("glob_expand_command_line(\"%s\")\n", cmdline);

    array(string|array(string)) args = split_command_line(cmdline);

    int index;

    for(index = 0; index < sizeof(args); index++) {

      // Glob-expand args[index]

      // FIXME: Does not check if "*" or "?" was quoted!
      if (replace(args[index], ({"*", "?"}), ({ "", "" })) != args[index]) {

        // Globs in the file-name.

        array(string|array(string)) matches = ({ ({ }) });
        multiset(string) paths; // Used to filter out duplicates.
        int i;
        foreach(my_combine_path("", args[index])/"/", string part) {
          paths = (<>);
          if (replace(part, ({"*", "?"}), ({ "", "" })) != part) {
            // Got a glob.
            array(array(string)) new_matches = ({});
            foreach(matches, array(string) path) {
              array(string) dir;
	      RequestID id = RequestID2(master_session);
	      id->method = "LIST";
              dir = id->conf->find_dir(combine_path(cwd, path*"/")+"/", id);
              if (dir && sizeof(dir)) {
                dir = glob(part, dir);
                if ((< '*', '?' >)[part[0]]) {
                  // Glob-expanding does not expand to files starting with '.'
                  dir = Array.filter(dir, lambda(string f) {
                    return (sizeof(f) && (f[0] != '.'));
                  });
                }
                foreach(sort(dir), string f) {
                  array(string) arr = my_combine_path_array(path, f);
                  string p = arr*"/";
                  if (!paths[p]) {
                    paths[p] = 1;
                    new_matches += ({ arr });
                  }
                }
              }
	      destruct(id);
            }
            matches = new_matches;
          } else {
            // No glob
            // Just add the part. Modify matches in-place.
            for(i=0; i<sizeof(matches); i++) {
              matches[i] = my_combine_path_array(matches[i], part);
              string path = matches[i]*"/";
              if (paths[path]) {
                matches[i] = 0;
              } else {
                paths[path] = 1;
              }
            }
            matches -= ({ 0 });
          }
          if (!sizeof(matches)) {
            break;
          }
        }
        if (sizeof(matches)) {
          // Array => string
          for (i=0; i < sizeof(matches); i++) {
            matches[i] *= "/";
          }
          // Filter out non-existing or forbiden files/directories
          matches = Array.filter(matches,
				 lambda(string short, string cwd,
					object m_id) {
				   object id = RequestID2(m_id);
				   id->method = "LIST";
				   id->not_query = combine_path(cwd, short);
				   mapping res =
				     id->conf->stat_file(id->not_query, id);
				   destruct(id);
				   return res;
				 }, cwd, master_session);
          if (sizeof(matches)) {
            args[index] = matches;
          }
        }
      }
      if (stringp(args[index])) {
        // No glob
        args[index] = ({ my_combine_path("", args[index]) });
      }
    }
    return(args * ({}));
  }

  /*
   * LS handling
   */

  private constant ls_options = ({
    ({ ({ "-A", "--almost-all" }),	LS_FLAG_A,
       "do not list implied . and .." }),
    ({ ({ "-a", "--all" }),		LS_FLAG_a|LS_FLAG_A,
       "do not hide entries starting with ." }),
    ({ ({ "-b", "--escape" }),		LS_FLAG_b,
       "print octal escapes for nongraphic characters" }),
    ({ ({ "-C" }),			LS_FLAG_C,
       "list entries by columns" }),
    ({ ({ "-d", "--directory" }),	LS_FLAG_d,
       "list directory entries instead of contents" }),
    ({ ({ "-F", "--classify" }),	LS_FLAG_F,
       "append a character for typing each entry"}),
    ({ ({ "-f" }),			LS_FLAG_a|LS_FLAG_A|LS_FLAG_U,
       "do not sort, enable -aU, disable -lst" }),
    ({ ({ "-G", "--no-group" }),	LS_FLAG_G,
       "inhibit display of group information" }),
    ({ ({ "-g" }), 			0,
       "(ignored)" }),
    ({ ({ "-h", "--help" }),		LS_FLAG_h,
       "display this help and exit" }),
    ({ ({ "-k", "--kilobytes" }),	0,
       "use 1024 blocks (ignored, always done anyway)" }),
    ({ ({ "-L", "--dereference" }),	0,
       "(ignored)" }),
    ({ ({ "-l" }),			LS_FLAG_l,
       "use a long listing format" }),
    ({ ({ "-m" }),			LS_FLAG_m,
       "fill width with a comma separated list of entries" }),
    ({ ({ "-n", "--numeric-uid-gid" }),	LS_FLAG_n,
       "list numeric UIDs and GIDs instead of names" }),
    ({ ({ "-o" }),			LS_FLAG_l|LS_FLAG_G,
       "use long listing format without group info" }),
    ({ ({ "-Q", "--quote-name" }),	LS_FLAG_Q,
       "enclose entry names in double quotes" }),
    ({ ({ "-R", "--recursive" }),	LS_FLAG_R,
       "list subdirectories recursively" }),
    ({ ({ "-r", "--reverse" }),		LS_FLAG_r,
       "reverse order while sorting" }),
    ({ ({ "-S" }),			LS_FLAG_S,
       "sort by file size" }),
    ({ ({ "-s", "--size" }),		LS_FLAG_s,
       "print block size of each file" }),
    ({ ({ "-t" }),			LS_FLAG_t,
       "sort by modification time; with -l: show mtime" }),
    ({ ({ "-U" }),			LS_FLAG_U,
       "do not sort; list entries in directory order" }),
    ({ ({ "-v", "--version" }),		LS_FLAG_v,
       "output version information and exit" }),
  });

  private array(array(string)|string|int)
    ls_getopt_args = Array.map(ls_options,
			       lambda(array(array(string)|int|string) entry) {
				 return({ entry[1], Getopt.NO_ARG, entry[0] });
			       });

  private string ls_help(string ls)
  {
    return sprintf("Usage: %s [OPTION]... [FILE]...\n"
		   "List information about the FILEs "
		   "(the current directory by default).\n"
		   "Sort entries alphabetically if none "
		   "of -cftuSUX nor --sort.\n"
		   "\n"
		   "%@s\n",
		   ls,
		   Array.map(ls_options,
			     lambda(array entry) {
			       if (sizeof(entry[0]) > 1) {
				 return(sprintf("  %s, %-22s %s\n",
						@(entry[0]), entry[2]));
			       }
			       return(sprintf("  %s  "
					      "                       %s\n",
					      entry[0][0], entry[2]));
			     }));
  }

  void call_ls(array(string) argv)
  {
    /* Parse options */
    array options;
    mixed err;

    if (err = catch {
      options = Getopt.find_all_options(argv, ls_getopt_args, 1, 1);
    }) {
      send(550, (argv[0]+": "+err[0])/"\n");
      discard_data_connection();
      return;
    }

    int flags;

    foreach(options, array(int) option) {
      flags |= option[0];
    }

    if (err = catch {
      argv = Getopt.get_args(argv, 1, 1);
    }) {
      send(550, (argv[0] + ": " + err[0])/"\n");
      discard_data_connection();
      return;
    }

    if (sizeof(argv) == 1) {
      argv += ({ "./" });
    }

    RequestID session = RequestID2(master_session);
    session->method = "LIST";
    // For logging purposes...
    session->not_query = Array.map(argv[1..], fix_path)*" ";

    mapping file = ([]);

    // The listings returned by a LIST or NLST command SHOULD use an
    // implied TYPE AN, unless the current type is EBCDIC, in which
    // case an implied TYPE EN SHOULD be used.
    // RFC 1123 4.1.2.7
    if (mode != "E") {
      file->mode = "A";
    } else {
      file->mode = "E";
    }

    if (flags & LS_FLAG_v) {
      file->data = "ls - builtin_ls 1.1\n";
    } else if (flags & LS_FLAG_h) {
      file->data = ls_help(argv[0]);
    } else {
      if (flags & LS_FLAG_d) {
	flags &= ~LS_FLAG_R;
      }
      if (flags & (LS_FLAG_f|LS_FLAG_C|LS_FLAG_m)) {
	flags &= ~LS_FLAG_l;
      }
      if (flags & LS_FLAG_C) {
	flags &= ~LS_FLAG_m;
      }

      file->file = LSFile(cwd, argv[1..], flags, session,
			  file->mode, this_object());

#ifdef FTP_USE_HANDLER_THREADS
      // Create the listing synchronously when running in
      // a handler thread.
      file->file && file->file->fill_output_queue();
#endif
    }

    if (!file->full_path) {
      file->full_path = argv[0];
    }
    session->file = file;
    connect_and_send(file, session);
  }

  /*
   * Listings for Machine Processing
   */

  constant supported_mlst_facts = (<
    "size", "type", "modify", "charset", "media-type",
    "unix.mode", "unix.atime", "unix.ctime", "unix.uid", "unix.gid",
  >);

  multiset(string) current_mlst_facts = (<
    "size", "type", "modify", "unix.mode", "unix.uid", "unix.gid",
  >);

  protected string format_factlist(multiset(string) all,
				   multiset(string)|void selected)
  {
    if (!selected) selected = (<>);

    string ret = "";
    foreach(sort(indices(all)), string fact) {
      ret += fact;
      if (selected[fact]) {
	ret += "*";
      }
      ret += ";";
    }
    return ret;
  }

  string make_MDTM(int t)
  {
    mapping lt = gmtime(t);
    return sprintf("%04d%02d%02d%02d%02d%02d",
		   lt->year + 1900, lt->mon + 1, lt->mday,
		   lt->hour, lt->min, lt->sec);
  }

  string make_MLSD_fact(string f, mapping(string:array) dir, object session)
  {
    array st = dir[f];

    mapping(string:string) facts = ([]);

    // Construct the facts here.

    if (st[1] >= 0) {
      facts->size = (string)st[1];
      facts->type = "file";
      if (current_mlst_facts["media-type"]) {
	string|array(string) ct = session->conf->type_from_filename(f);
	if (arrayp(ct)) {
	  ct = (sizeof(ct) > 1) && ct[1];
	}
	facts["media-type"] = ct || "application/octet-stream";
      }
    } else {
      facts->type = ([ "..":"pdir", ".":"cdir" ])[f] || "dir";
    }

    facts->modify = make_MDTM(st[3]);		/* mtime */

    facts->charset = "8bit";

    // FIXME: Consider adding support for the "unique" fact.
    //        Typically based on dev-no + inode-no.

    // FIXME: Consider adding support for the "perm" fact.

    // Facts from
    // https://www.iana.org/assignments/os-specific-parameters/os-specific-parameters.xml
    facts["unix.atime"] = make_MDTM(st[2]);	/* atime */
    facts["unix.ctime"] = make_MDTM(st[4]);	/* ctime */

    // FIXME: Consider adding support for "unix.ownername" and
    //        "unix.groupname".

    // Defacto standard facts here.
    // Cf eg https://github.com/giampaolo/pyftpdlib
    facts["unix.mode"] = sprintf("0%o", st[0]);	/* mode */
    facts["unix.uid"] = sprintf("%d", st[5]);	/* uid */
    facts["unix.gid"] = sprintf("%d", st[6]);	/* gid */

    // Construct, filter and return the answer.

    return((Array.map(indices(facts),
		      lambda(string s, mapping f, multiset(string) current) {
			if (!current[s]) return "";
			return s + "=" + f[s] + ";";
		      }, facts, current_mlst_facts) - ({ "" })) * "" + " " + f);
  }

  void send_MLSD_response(mapping(string:array) dir, object session)
  {
    dir = dir || ([]);

    array f = indices(dir);

    session->file->data = sizeof(f) ?
      (Array.map(f, make_MLSD_fact, dir, session) * "\r\n") + "\r\n" :
      "" ;

    session->file->mode = "I";
    connect_and_send(session->file, session);
  }

  void send_MLST_response(mapping(string:array) dir, object session)
  {
    dir = dir || ([]);
    send(250,({ "OK" }) + 
	 Array.map(indices(dir), make_MLSD_fact, dir, session) +
	 ({ "OK" }) );
  }

  /*
   * Session handling
   */

  int login()
  {
    int session_limit = port_obj->query_option("ftp_user_session_limit");

    if (session_limit > 0) {

      if (session_limit <= (port_obj->ftp_sessions[user])) {
	return 0;		// Session limit reached.
      }

      if (logged_in) {
	report_error("Internal error in session-handler.");
	return 1;
      }

      DWRITE("FTP2: Increasing # of sessions for user %O\n", user);
      port_obj->ftp_sessions[user]++;
    }
    logged_in = (user != 0) || -1;

    return 1;
  }

  void logout()
  {
    if (!logged_in) return;

    int session_limit = port_obj->query_option("ftp_user_session_limit");

    if (session_limit > 0) {

      DWRITE("FTP2: Decreasing # of sessions for user %O\n", user);
      if ((--port_obj->ftp_sessions[user]) < 0) {
	port_obj->ftp_sessions[user] = 0;
      }
    }
    logged_in = 0;
  }

  int check_login()
  {
    int session_limit = port_obj->query_option("ftp_user_session_limit");

    if (session_limit <= 0) return 1;

    if (session_limit <= (port_obj->ftp_sessions[user])) {
      return 0;		// Session limit reached.
    }

    return 1;
  }

  /*
   * FTP commands begin here
   */

  // Set to 1 by EPSV ALL.
  int epsv_only;

  void ftp_REIN(string|int args)
  {
    logout();

    // FIXME: What about EPSV ALL mode? RFC 2428 doesn't say.
    // I guess that it shouldn't be reset.

    // Compatibility...
    m_delete(master_session->misc, "home");

    dataport_addr = 0;
    dataport_port = 0;
    mode = "A";
    cwd = "/";
    auth_user = 0;
    user = password = 0;
    curr_pipe = 0;
    restart_point = 0;
    logged_in = 0;
    if (pasv_port) {
      destruct(pasv_port);
      pasv_port = 0;
    }
    if (args != 1) {
      // Not called by QUIT or AUTH.
      low_send(220, ({ "Server ready for new user." }));

      // RFC 4217 13:
      //   When this command is processed by the server, the TLS
      //   session(s) MUST be cleared and the control and data
      //   connections revert to unprotected, clear communications.
      to_send->put(2);	// End TLS marker.
      use_ssl = SSL_NONE;

      busy = 0;
      next_cmd();
    }
  }

  void ftp_AUTH(string args)
  {
    if (!expect_argument("AUTH", args)) return;

    args = upper_case(replace(args, ({ " ", "\t" }), ({ "", "" })));

    // RFC 4217 17:
    // To request the TLS protocol in accordance with this document,
    // the client MUST use 'TLS'
    //
    //    To maintain backward compatibility with older versions of this
    //    document, the server SHOULD accept 'TLS-C' as a synonym for 'TLS'.
    if (!(< "TLS", "SSL", "SSL-C", "TLS-C", "SSL-P", "TLS-P" >)[args]) {
      // RFC 2228 AUTH:
      // If the server does not understand the named security mechanism, it
      // should respond with reply code 504.
      send(504, ({ "Unknown authentication mechanism." }));
      return;
    }
    if ((port_obj->query_option("require_starttls") < 0) ||
	!port_obj->ctx) {
      // RFC 2228 AUTH:
      // If the server is not willing to accept the named security
      // mechanism, it should respond with reply code 534.
      send(534, ({ "TLS not configured." }));
      return;
    }
    // RFC 2228 AUTH:
    // The AUTH command, if accepted, removes any state associated with
    // prior FTP Security commands. The server must also require that the
    // user reauthorize (that is, reissue some or all of the USER, PASS,
    // and ACCT commands) in this case (see section 4 for an explanation
    // of "authorize" in this context).
    //
    // RFC 4217 4.2 requires REIN.
    ftp_REIN(1);

    // Inform the client that we agree to switch to TLS.
    low_send(234, ({ "TLS enabled." }));

    // Make sure not to read any more from the fd before
    // the TLS handshaking is done.
    fd->set_read_callback(0);
    fd->set_close_callback(0);

    // Switch to TLS marker.
    to_send->put(1);

    // Compatibility with early draft-murray-auth-ftp-ssl
    // (drafts of RFC 4217).
    if (args == "TLS-P") {
      // AUTH TLS-P: Enable PROT P by default.
      use_ssl = SSL_ALL;
    } else if ((args == "SSL") || (args == "SSL-P")) {
      // AUTH SSL: Enable PROT P by default in active mode.
      //
      // Use SSL/TLS for the data connection in active mode but
      // not in passive mode. This behaviour probably has to do
      // with the server initiating the connection in passive mode,
      // which would imply it to be the SSL/TLS client.
      //
      // cf RFC 4217 (AUTH TLS) which solves this by having
      // the server being the SSL/TLS server in both modes.
      use_ssl = SSL_ACTIVE;
    }
    // NB: AUTH SSL-C is "Don't encrypt data channel".

    busy = 0;
    next_cmd();
  }

  void ftp_CCC(string args)
  {
    if (!fd->renegotiate) {
      // Not AUTH TLS
      send(533, ({ "Command connection not protected." }));
      return;
    }
    if (master_session->my_fd->renegotiate) {
      // ftps
      send(534, ({ "Not allowed for ftps." }));
      return;
    }

    low_send(200, ({ "TLS disabled." }));
    to_send->put(2);	// Disable TLS marker.

    busy = 0;
    next_cmd();
  }

  void ftp_USER(string args)
  {
    logout();

    auth_user = 0;
    user = args;
    password = 0;
    logged_in = 0;
    cwd = "/";
    master_session->method = "LOGIN";
    if ((< 0, "", "ftp", "anonymous" >)[user]) {
      master_session->not_query = "Anonymous";
      user = 0;
      if (port_obj->query_option("anonymous_ftp")) {
	if (check_login()) {
#if 0
	  send(200, ({ "Anonymous ftp, at your service" }));
#else /* !0 */
	  // ncftp doesn't like the above answer -- stupid program!
	  send(331, ({ "Anonymous ftp accepted, send "
		       "your complete e-mail address as password." }));
#endif /* 0 */
	  conf->log(([ "error":200 ]), master_session);
	} else {
	  send(530, ({
	    sprintf("Too many anonymous users (%d).",
		    port_obj->query_option("ftp_user_session_limit"))
	  }));
	  conf->log(([ "error":403 ]), master_session);
	}
      } else {
	send(530, ({ "Anonymous ftp disabled" }));
	conf->log(([ "error":403 ]), master_session);
      }
    } else {
      if (port_obj->ctx && !fd->renegotiate &&
	  (port_obj->query_option("require_starttls") == 1)) {
	conf->log(([ "error":403 ]), master_session);
	send(530, ({ "You need to AUTH TLS first." }));

	return;
      }
      if (check_login()) {
	send(331, ({ sprintf("Password required for %s.", user) }));
	master_session->not_query = user;
	conf->log(([ "error":407 ]), master_session);
      } else {
	// Session limit exceeded.
	send(530, ({
	  sprintf("Concurrent session limit (%d) exceeded for user \"%s\".",
		  port_obj->query_option("ftp_user_session_limit"), user)
	}));
	conf->log(([ "error":403 ]), master_session);
	user = 0;
	return;
      }
    }
  }

  void ftp_PASS(string args)
  {
    if (!user) {
      if (port_obj->query_option("anonymous_ftp")) {
	if (login()) {
	  send(230, ({ "Guest login ok, access restrictions apply." }));
	  master_session->method = "LOGIN";
	  master_session->not_query = "Anonymous User:"+args;
	  conf->log(([ "error":200 ]), master_session);
	  logged_in = -1;
	} else {
	  send(530, ({
	    sprintf("Too many anonymous users (%d).",
		    port_obj->query_option("ftp_user_session_limit"))
	  }));
	  conf->log(([ "error":403 ]), master_session);
	}
      } else {
	send(503, ({ "Login with USER first." }));
      }
      return;
    }

    if (port_obj->ctx && !fd->renegotiate &&
	(port_obj->query_option("require_starttls") == 1)) {
      // NB: Reachable through the following exotic command sequence:
      //
      //     AUTH TLS, USER, PASS, CCC, PASS
      conf->log(([ "error":403 ]), master_session);
      send(530, ({ "You need to AUTH TLS first." }));

      return;
    }

    logout();

    password = args||"";
    args = "CENSORED_PASSWORD";	// Censored in case of backtrace.
    master_session->method = "LOGIN";
    master_session->realauth = user + ":" + password;
    master_session->not_query = user;

    master_session->misc->user = user;           // Loophole for new API
    master_session->misc->password = password;  // Otherwise we have to emulate
                                               // the Authentication header
    // Compatibility...
    m_delete(master_session->misc, "home");

    RequestID2 session = RequestID2 (master_session);

    auth_user = session->conf->authenticate(session);

    if (!auth_user) {
      if (!port_obj->query_option("guest_ftp")) {
	send(530, ({ sprintf("User %s access denied.", user) }));
	conf->log(([ "error":401 ]), session);
      } else {
	// Guest user.
	string u = user;
	user = 0;
	if (login()) {
	  send(230, ({ sprintf("Guest user %s logged in.", u) }));
	  logged_in = -1;
	  conf->log(([ "error":200 ]), session);
	  DWRITE("FTP: Guest-user: %O\n", session->realauth);
	} else {
	  send(530, ({
	    sprintf("Too many anonymous/guest users (%d).",
		    port_obj->query_option("ftp_user_session_limit"))
	  }));
	  conf->log(([ "error":403 ]), session);
	}
      }
      destruct (session);
      return;
    }

    // Authentication successful

    // Transfer entries traditionally set by auth modules in id->misc
    // so that they get propagated to id->misc in all subsequent
    // subrequests.
    //
    // We can't copy the whole misc mapping to the master RequestID;
    // that can cause various stuff set during the auth check to be
    // around for too long - the lifespan of id->misc must generally
    // not be longer than a single (http style) request.
    {
      mapping ses_misc = session->misc, mses_misc = master_session->misc;
      foreach (({"authenticated_user", "user", "password", "uid", "gid",
		 "gecos", "home", "shell"}), string field) {
	mixed val = ses_misc[field];
	if (zero_type (val))
	  m_delete (mses_misc, field);
	else
	  mses_misc[field] = val;
      }
    }

    if (!port_obj->query_option("named_ftp") ||
	!check_shell(auth_user->shell())) {
      send(530, ({ "You are not allowed to use named-ftp.",
		   "Try using anonymous, or check /etc/shells" }));
      conf->log(([ "error":402 ]), session);
      auth_user = 0;
      destruct (session);
      return;
    }

    if (!login()) {
      send(530, ({
	sprintf("Too many concurrent sessions (limit is %d).",
		port_obj->query_option("ftp_user_session_limit"))
      }));
      conf->log(([ "error":403 ]), session);
      destruct (session);
      return;
    }

    if (stringp(auth_user->homedir())) {
      // Check if it is possible to cd to the users home-directory.
      string home = auth_user->homedir();
      if ((home == "") || (home[-1] != '/')) {
	home += "/";
      }

      // Compatibility...
      master_session->misc->home = home;

      RequestID2 stat_session = RequestID2(master_session);
      stat_session->method = "STAT";
      array(int)|object st = conf->stat_file(home, stat_session);
      destruct(stat_session);

      if (st && (st[1] < 0)) {
	cwd = home;
      }
    }

    logged_in = 1;
    send(230, ({ sprintf("User %s logged in.", user) }));
    conf->log(([ "error":202 ]), session);
    destruct (session);
  }

  void ftp_CWD(string args)
  {
    if (!expect_argument("CWD", args)) {
      return;
    }

    string ncwd = fix_path(args);

    if ((ncwd == "") || (ncwd[-1] != '/')) {
      ncwd += "/";
    }

    object session = RequestID2(master_session);
    session->method = "CWD";
    session->not_query = ncwd;

    array|object st = conf->stat_file(ncwd, session);
    ncwd = session->not_query; // Makes internal redirects to work.
    if (!st) {
      send(550, ({ sprintf("%s: No such file or directory, or access denied.",
			   ncwd) }));
      session->conf->log(session->file || ([ "error":404 ]), session);
      destruct(session);
      return;
    }

    if (!(< -2, -3 >)[st[1]]) {
      send(504, ({ sprintf("%s: Not a directory.", ncwd) }));
      session->conf->log(([ "error":400 ]), session);
      destruct(session);
      return;
    }

    // CWD Successfull
    cwd = ncwd;

    array(string) reply = ({ sprintf("Current directory is now %s.", cwd) });

    // Check for .messages etc
    session->method = "GET";	// Important
    array(string) files = conf->find_dir(cwd, session);

    if (files) {
      files = reverse(sort(Array.filter(files, lambda(string s) {
						 return(s[..5] == "README");
					       })));
      foreach(files, string f) {
	array|object st = conf->stat_file(replace(cwd + f, "//", "/"),
					  session);

	if (st && (st[1] >= 0)) {
	  reply = ({ sprintf("Please read the file %s.", f),
		     sprintf("It was last modified %s - %d days ago.",
			     ctime(st[3]) - "\n",
			     (time(1) - st[3])/86400),
		     "" }) + reply;
	}
      }
    }
    string message;
    catch {
      message = conf->try_get_file(cwd + ".message", session);
    };
    if (message) {
      reply = (message/"\n")+({ "" })+reply;
    }

    session->method = "CWD";	// Restore it again.
    send(250, reply);
    session->conf->log(([ "error":200, "len":sizeof(reply*"\n") ]), session);
    destruct(session);
  }

  void ftp_XCWD(string args)
  {
    ftp_CWD(args);
  }

  void ftp_CDUP(string args)
  {
    ftp_CWD("../");
  }

  void ftp_XCUP(string args)
  {
    ftp_CWD("../");
  }

  void ftp_QUIT(string args)
  {
    send(221, ({ "Bye! It was nice talking to you!" }));
    send(0, 0);		// EOF marker.

    master_session->method = "QUIT";
    master_session->not_query = user || "Anonymous";
    conf->log(([ "error":200 ]), master_session);

    // Reinitialize the connection.
    ftp_REIN(1);
  }

  void ftp_BYE(string args)
  {
    ftp_QUIT(args);
  }

  void ftp_PBSZ(string args)
  {
    if (!expect_argument("PBSZ", args)) return;

    if (!fd->renegotiate) {
      send(536, ({ "Only allowed for authenticated command connections." }));
      return;
    }

    send(200, ({ "PBSZ=0" }));
  }

  void ftp_PROT(string args)
  {
    if (!expect_argument("PROT", args)) return;

    args = upper_case(replace(args, ({ " ", "\t" }), ({ "", "" })));

    SSLMode wanted;
    switch(args) {
    case "C": // Clear.
      wanted = SSL_NONE;
      break;
    case "S": // Safe.
    case "E": // Confidential.
    case "P": // Private.
      wanted = SSL_ALL;
      break;
    default:
      send(504, ({ sprintf("Unknown protection level: %s", args) }));
      return;
    }

    if (!fd->renegotiate) {
      send(536, ({ sprintf("Only supported over TLS.") }));
      return;
    }

    use_ssl = wanted;
    send(200, ({ "OK" }));
  }

  void ftp_PORT(string args)
  {
    if (epsv_only) {
      send(530, ({ "'PORT': Method not allowed in EPSV ALL mode." }));
      return;
    }

    int a, b, c, d, e, f;

    if (sscanf(args||"", "%d,%d,%d,%d,%d,%d", a, b, c, d, e, f)<6)
      send(501, ({ "I don't understand your parameters." }));
    else {
      dataport_addr = sprintf("%d.%d.%d.%d", a, b, c, d);
      dataport_port = e*256 + f;

      if (pasv_port) {
	destruct(pasv_port);
      }
      send(200, ({ "PORT command ok ("+dataport_addr+
		   " port "+dataport_port+")" }));
    }
  }

  void ftp_EPRT(string args)
  {
    // Specified by RFC 2428:
    // Extensions for IPv6 and NATs.
    if (epsv_only) {
      send(530, ({ "'EPRT': Method not allowed in EPSV ALL mode." }));
      return;
    }

    if (sizeof(args) < 3) {
      send(501, ({ "I don't understand your parameters." }));
      return;
    }

    string delimiter = args[0..0];
    if ((delimiter[0] <= 32) || (delimiter[0] >= 127)) {
      send(501, ({ "Invalid delimiter." }));
    }
    array(string) segments = args/delimiter;

    if (sizeof(segments) != 5) {
      send(501, ({ "I don't understand your parameters." }));
      return;
    }
    if (!(<"1","2">)[segments[1]]) {
      send(522, ({ "Network protocol not supported, use (1 or 2)" }));
      return;
    }
    if (segments[1] == "1") {
      // IPv4.
      if ((sizeof(segments[2]/".") != 4) ||
	  sizeof(replace(segments[2], ".0123456789"/"", allocate(11, "")))) {
	send(501, ({ sprintf("Bad IPv4 address: '%s'", segments[2]) }));
	return;
      }
    } else {
      // IPv6.
      // FIXME: Improve the validation?
      if (sizeof(replace(lower_case(segments[2]), ".:0123456789abcdef"/"",
			 allocate(18, "")))) {
	send(501, ({ sprintf("Bad IPv6 address: '%s'", segments[2]) }));
	return;
      }
    }
    if ((((int)segments[3]) <= 0) || (((int)segments[3]) > 65535)) {
      send(501, ({ sprintf("Bad port number: '%s'", segments[3]) }));
      return;
    }
    dataport_addr = segments[2];
    dataport_port = (int)segments[3];

    if (pasv_port) {
      destruct(pasv_port);
    }
    send(200, ({ "EPRT command ok ("+dataport_addr+
		 " port "+dataport_port+")" }));
  }

  void ftp_PASV(string args)
  {
    // Required by RFC 1123 4.1.2.6
    int min;
    int max;

    if (epsv_only) {
      send(530, ({ "'PASV': Method not allowed in EPSV ALL mode." }));
      return;
    }

    if (e_mode != "1") {
      send(530, ({ "'PASV': Method not allowed on IPv6 connections." }));
      return;
    }

    if(pasv_port)
      destruct(pasv_port);

    pasv_port = Stdio.Port(0, pasv_accept_callback, local_addr);
    /* FIXME: Hmm, getting the address from an anonymous port seems not
     * to work on NT...
     */
    int port=(int)((pasv_port->query_address()/" ")[1]);

    min = port_obj->query_option("passive_port_min");
    max = port_obj->query_option("passive_port_max");
    if ((port < min) || (port > max)) {
      if (max > 65535) max = 65535;
      if (min < 0) min = 0;
      for (port = min; port <= max; port++) {
	if (pasv_port->bind(port, pasv_accept_callback, local_addr)) {
	  break;
	}
      }
      if (port > max) {
	destruct(pasv_port);
	pasv_port = 0;
	send(452, ({ "Requested action aborted: Out of ports." }));
	return;
      }
    }
    send(227, ({ sprintf("Entering Passive Mode. (%s,%d,%d)",
			 replace(local_addr, ".", ","),
			 (port>>8), (port&0xff)) }));
  }

  void ftp_EPSV(string args)
  {
    // Specified by RFC 2428:
    // Extensions for IPv6 and NATs.
    int min;
    int max;

    if (!(< 0, e_mode >)[args]) {
      if (lower_case(args) == "all") {
	epsv_only = 1;
	send(200, ({ "Entering EPSV ALL mode." }));
      } else {
	send(522, ({ "Network protocol not supported, use " + e_mode + "." }));
      }
      return;
    }
    if (pasv_port)
      destruct(pasv_port);

    pasv_port = Stdio.Port(0, pasv_accept_callback, local_addr);
    /* FIXME: Hmm, getting the address from an anonymous port seems not
     * to work on NT...
     */
    int port=(int)((pasv_port->query_address()/" ")[1]);

    min = port_obj->query_option("passive_port_min");
    max = port_obj->query_option("passive_port_max");
    if ((port < min) || (port > max)) {
      if (max > 65535) max = 65535;
      if (min < 1) min = 1;
      for (port = min; port <= max; port++) {
	if (pasv_port->bind(port, pasv_accept_callback, local_addr)) {
	  break;
	}
      }
      if (port > max) {
	destruct(pasv_port);
	pasv_port = 0;
	send(452, ({ "Requested action aborted: Out of ports." }));
	return;
      }
    }
    send(229, ({ sprintf("Entering Extended Passive Mode (|||%d|)",
			 /* "1", local_addr,*/ port) }));
  }

  void ftp_TYPE(string args)
  {
    if (!expect_argument("TYPE", args)) {
      return;
    }

    args = upper_case(replace(args, ({ " ", "\t" }), ({ "", "" })));

    // I and L8 are required by RFC 1123 4.1.2.1
    switch(args) {
    case "L8":
    case "L":
    case "I":
      mode = "I";
      break;
    case "A":
      mode = "A";
      break;
    case "E":
      mode = "E";
      break;
    default:
      send(504, ({ "'TYPE': Unknown type:"+args }));
      return;
    }

    send(200, ({ sprintf("Using %s mode for transferring files.",
			 modes[mode]) }));
  }

  void ftp_RETR(string args)
  {
    if (!expect_argument("RETR", args)) {
      return;
    }

    args = fix_path(args);

    RequestID session = RequestID2(master_session);

    session->method = "GET";
    session->not_query = args;

    mapping file;
    if (file = open_file(args, session, "RETR")) {
      if (restart_point) {
	if (file->data) {
	  if (sizeof(file->data) >= restart_point) {
	    file->data = file->data[restart_point..];
	    restart_point = 0;
	  } else {
	    restart_point -= sizeof(file->data);
	    m_delete(file, "data");
	  }
	}
	if (restart_point) {
	  if (!(file->file && file->file->seek &&
		(file->file->seek(restart_point) != -1))) {
	    restart_point = 0;
	    send(550, ({ "'RETR': Error restoring restart point." }));
	    discard_data_connection();
	    destruct(session);
	    return;
	  }
	  restart_point = 0;
	}
      }

      connect_and_send(file, session);
    }
    else {
      discard_data_connection();
      destruct(session);
    }
  }

  void ftp_STOR(string args)
  {
    if (!expect_argument("STOR", args)) {
      return;
    }

    args = fix_path(args);

    connect_and_receive(args);
  }

  void ftp_REST(string args)
  {
    if (!expect_argument("REST", args)) {
      return;
    }
    restart_point = (int)args;
    send(350, ({ "'REST' ok" }));
  }

  void ftp_ABOR(string args)
  {
    if (curr_pipe) {
      catch {
	destruct(curr_pipe);
      };
      curr_pipe = 0;
      send(426, ({ "Data transmission terminated." }));
    }
    send(226, ({ "'ABOR' Completed." }));
  }

  void ftp_PWD(string args)
  {
    send(257, ({ sprintf("\"%s\" is current directory.", cwd) }));
  }

  void ftp_XPWD(string args)
  {
    ftp_PWD(args);
  }

  /*
   * Handling of file moving
   */

  private string rename_from; // rename from

  void ftp_RNFR(string args)
  {
    if (!expect_argument("RNFR", args)) {
      return;
    }
    args = fix_path(args);

    if (stat_file(args)) {
      send(350, ({ sprintf("%s ok, waiting for destination name.", args) }) );
      rename_from = args;
    } else {
      send(550, ({ sprintf("%s: no such file or permission denied.",args) }) );
    }
  }

  void ftp_RNTO(string args)
  {
    if(!rename_from) {
      send(503, ({ "RNFR needed before RNTO." }));
      return;
    }
    if (!expect_argument("RNTO", args)) {
      return;
    }
    args = fix_path(args);

    RequestID session = RequestID2(master_session);

    session->method = "MV";
    session->misc->move_from = rename_from;
    session->not_query = args;
    if (open_file(args, session, "MOVE")) {
      send(250, ({ sprintf("%s moved to %s.", rename_from, args) }));
      session->conf->log(([ "error":200 ]), session);
    }
    rename_from = 0;
    destruct(session);
  }


  void ftp_NLST(string args)
  {
    // ftp_MLST(args); return;

    array(string) argv = glob_expand_command_line("/usr/bin/ls " + (args||""));

    call_ls(argv);
  }

  void ftp_LIST(string args)
  {
    // ftp_MLSD(args); return;

    ftp_NLST("-l " + (args||""));
  }

  void ftp_MLST(string args)
  {
    string long = fix_path(args || ".");

    RequestID session = RequestID2(master_session);

    session->method = "DIR";

    array|object st = stat_file(long, session);

    if (st) {
      session->file = ([]);
      session->file->full_path = long;
      send_MLST_response(([ args||".": st ]), session);
    } else {
      send_error("MLST", args, session->file, session);
    }
    destruct(session);
  }

  void ftp_MLSD(string args)
  {
    args = fix_path(args || ".");

    RequestID session = RequestID2(master_session);

    session->method = "DIR";

    array|object st = stat_file(args, session);

    if (st && (st[1] < 0)) {
      if (args[-1] != '/') {
	args += "/";
      }

      session->file = ([]);
      session->file->full_path = args;

      mapping(string:array(mixed)) dir =
	session->conf->find_dir_stat(args, session) || ([]);
      if (args != "/") {
	dir[".."] = stat_file(combine_path(args,"../"));
      }
      dir["."] = stat_file(combine_path(args));

      send_MLSD_response(dir, session);
      // NOTE: send_MLSD_response is asynchronous!
    } else {
      if (st) {
	session->file->error = 405;
      }
      send_error("MLSD", args, session->file, session);
      discard_data_connection();
      destruct(session);
    }
  }

  void ftp_OPTS(string args)
  {
    if ((< 0, "" >)[args]) {
      ftp_HELP("OPTS");
      return;
    }

    array a = (args/" ") - ({ "" });

    if (!sizeof(a)) {
      ftp_HELP("OPTS");
      return;
    }
    a[0] = upper_case(a[0]);
    if (!opts_help[a[0]]) {
      send(502, ({ sprintf("Bad OPTS command: '%s'", a[0]) }));
    } else if (this_object()["ftp_OPTS_"+a[0]]) {
      this_object()["ftp_OPTS_"+a[0]](a[1..]);
    } else {
      send(502, ({ sprintf("OPTS command '%s' is not currently supported.",
			   a[0]) }));
    }
  }

  void ftp_OPTS_MLST(array(string) args)
  {
    if (sizeof(args) != 1) {
      send(501, ({ sprintf("'OPTS MLST %s': incorrect arguments",
			   args*" ") }));
      return;
    }

    multiset(string) new_mlst_facts = (<>);
    foreach(args[0]/";", string fact) {
      fact = lower_case(fact);
      if (!supported_mlst_facts[fact]) continue;
      new_mlst_facts[fact] = 1;
    }
    current_mlst_facts = new_mlst_facts;

    send(200, ({ sprintf("MLST OPTS %s",
			 format_factlist(new_mlst_facts)) }));
  }

  void ftp_DELE(string args)
  {
    if (!expect_argument("DELE", args)) {
      return;
    }

    args = fix_path(args);

    RequestID session = RequestID2(master_session);

    session->data = "";
    session->misc->len = 0;
    session->method = "DELETE";

    if (open_file(args, session, "DELE")) {
      send(250, ({ sprintf("%s deleted.", args) }));
      session->conf->log(([ "error":200 ]), session);
    }
    destruct(session);
  }

  void ftp_RMD(string args)
  {
    if (!expect_argument("RMD", args)) {
      return;
    }

    args = fix_path(args);

    RequestID session = RequestID2(master_session);

    session->data = "";
    session->misc->len = 0;
    session->method = "DELETE";

    array|object st = stat_file(args, session);

    if (!st) {
      send_error("RMD", args, session->file, session);
      destruct(session);
      return;
    } else if (st[1] != -2) {
      if (st[1] == -3) {
	send(504, ({ sprintf("%s is a module mountpoint.", args) }));
	session->conf->log(([ "error":405 ]), session);
      } else {
	send(504, ({ sprintf("%s is not a directory.", args) }));
	session->conf->log(([ "error":405 ]), session);
      }
      destruct(session);
      return;
    }

    if (open_file(args, session, "RMD")) {
      send(250, ({ sprintf("%s deleted.", args) }));
      session->conf->log(([ "error":200 ]), session);
    }
    destruct(session);
  }

  void ftp_XRMD(string args)
  {
    ftp_RMD(args);
  }

  void ftp_MKD(string args)
  {
    if (!expect_argument("MKD", args)) {
      return;
    }

    args = fix_path(args);

    RequestID session = RequestID2(master_session);

    session->method = "MKDIR";
    session->data = "";
    session->misc->len = 0;

    if (open_file(args, session, "MKD")) {
      send(257, ({ sprintf("\"%s\" created.", args) }));
      session->conf->log(([ "error":200 ]), session);
    }
    destruct(session);
  }

  void ftp_XMKD(string args)
  {
    ftp_MKD(args);
  }

  void ftp_SYST(string args)
  {
    send(215, ({ "UNIX Type: L8: Roxen Information Server"}));
  }

  void ftp_CLNT(string args)
  {
    if (!expect_argument("CLNT", args)) {
      return;
    }

    send(200, ({ "Ok, gottcha!"}));
    master_session->client = args/" " - ({ "" });
  }

  void ftp_FEAT(string args)
  {
    array a = sort(Array.filter(indices(cmd_help),
				lambda(string s) {
				  return(this_object()["ftp_"+s]);
				}));
    if (!port_obj->ctx) {
      a -= ({ "AUTH" });
    }
    if (master_session->my_fd->renegotiate) {
      // ftps.
      a -= ({ "CCC" });
    }
    a = Array.map(a,
		  lambda(string s) {
		    return(([ "REST":"REST STREAM",
			      "MLST":sprintf("MLST %s",
					     format_factlist(supported_mlst_facts,
							     current_mlst_facts)),
			      "MLSD":"",
			      "AUTH":"AUTH TLS",
		    ])[s] || s);
		  }) - ({ "" });

    send(211, ({ "The following features are supported:" }) + a +
	 ({ "END" }));
  }

  void ftp_MDTM(string args)
  {
    if (!expect_argument("MDTM", args)) {
      return;
    }
    args = fix_path(args);
    mapping|array|object st = stat_file(args);

    if (!arrayp(st) && !objectp(st)) {
      send_error("MDTM", args, st, master_session);
    } else {
      send(213, ({ make_MDTM(st[3]) }));
    }
  }

  void ftp_SIZE(string args)
  {
    if (!expect_argument("SIZE", args)) {
      return;
    }
    args = fix_path(args);

    mapping|array|object st = stat_file(args);

    if (!arrayp(st) && !objectp(st)) {
      send_error("SIZE", args, st, master_session);
      return;
    }
    int size = st[1];
    if (size < 0) {
      send_error("SIZE", args, ([ "error":405, ]), master_session);
      // size = 512;
    } else {
      send(213, ({ (string)size }));
    }
  }

  void ftp_STAT(string args)
  {
    // According to RFC 1123 4.1.3.3, this command can be sent during
    // a file-transfer.
    // RFC 959 4.1.3:
    // The command may be sent during a file transfer (along with the
    // Telnet IP and Synch signals--see the Section on FTP Commands)
    // in which case the server will respond with the status of the
    // operation in progress, [...]
    // FIXME: This is not supported yet.

    if ((< "", 0 >)[args]) {
      /* RFC 959 4.1.3:
       * If no argument is given, the server should return general
       * status information about the server FTP process.  This
       * should include current values of all transfer parameters and
       * the status of connections.
       */
      string local_addr = fd->query_address(1);
      if (has_value(local_addr, ":")) {
	// IPv6.
	local_addr = "[" + replace(local_addr, " ", "]:");
      } else {
	local_addr = replace(local_addr, " ", ":");
      }
      string remote_addr = fd->query_address();
      if (has_value(remote_addr, ":")) {
	// IPv6.
	remote_addr = "[" + replace(remote_addr, " ", "]:");
      } else {
	remote_addr = replace(remote_addr, " ", ":");
      }
      send(211,
	   sprintf("%s FTP server status:\n"
		   "Version %s\n"
		   "Listening on %s\n"
		   "Connected to %s\n"
		   "Logged in %s\n"
		   "TYPE: %s, FORM: %s; STRUcture: %s; transfer MODE: %s\n"
		   "End of status",
		   local_addr,
		   roxen.version(),
		   port_obj->sorted_urls * "\nListening on ",
		   remote_addr,
		   user?sprintf("as %s", user):"anonymously",
		   (["A":"ASCII", "E":"EBCDIC", "I":"IMAGE", "L":"LOCAL"])
		   [mode],
		   "Non-Print",
		   "File",
		   "Stream"
		   )/"\n");
      return;
    }
    string long = fix_path(args);
    mapping|array|object st = stat_file(long);

    if (!arrayp(st) && !objectp(st)) {
      send_error("STAT", long, st, master_session);
    } else {
      string s = LS_L(master_session)->ls_l(args, st);

      send(213, sprintf("status of \"%s\":\n"
			"%s"
			"End of Status", args, s)/"\n");
    }
  }

  void ftp_NOOP(string args)
  {
    send(200, ({ "Nothing done ok" }));
  }

  void ftp_HELP(string args)
  {
    if ((< "", 0 >)[args]) {
      send(214, ({
	"The following commands are recognized (* =>'s unimplemented):",
	@(sprintf(" %#70s", sort(Array.map(indices(cmd_help),
					   lambda(string s) {
					     return(upper_case(s)+
						    (this_object()["ftp_"+s]?
						     "   ":"*  "));
					   }))*"\n")/"\n"),
	@(FTP2_XTRA_HELP),
      }));
    } else {
      args = upper_case(args);
      if ((args/" ")[0] == "SITE") {
	array(string) a = (args/" ")-({""});
	if (sizeof(a) == 1) {
	  send(214, ({ "The following SITE commands are recognized:",
		       @(sprintf(" %#70s", sort(indices(site_help))*"\n")/"\n")
	       }));
	} else if (site_help[a[1]]) {
	  send(214, ({ sprintf("Syntax: SITE %s %s", a[1], site_help[a[1]]) }));
	} else {
	  send(504, ({ sprintf("Unknown SITE command %s.", a[1]) }));
	}
      } else if ((args/" ")[0] == "OPTS") {
	array(string) a = (args/" ")-({""});
	if (sizeof(a) == 1) {
	  send(214, ({ "The following OPTS commands are recognized:",
		       @(sprintf(" %#70s", sort(indices(opts_help))*"\n")/"\n")
	       }));
	} else if (opts_help[a[1]]) {
	  send(214, ({ sprintf("Syntax: OPTS %s %s", a[1], opts_help[a[1]]) }));
	} else {
	  send(504, ({ sprintf("Unknown OPTS command %s.", a[1]) }));
	}
      } else {
	if (cmd_help[args]) {
	  send(214, ({ sprintf("Syntax: %s %s%s", args,
			       cmd_help[args],
			       (this_object()["ftp_"+args]?
				"":"; unimplemented")) }));
	} else {
	  send(504, ({ sprintf("Unknown command %s.", args) }));
	}
      }
    }
  }

  void ftp_SITE(string args)
  {
    // Extended commands.
    // Site specific commands are required to be part of the site command
    // by RFC 1123 4.1.2.8

    if ((< 0, "" >)[args]) {
      ftp_HELP("SITE");
      return;
    }

    array a = (args/" ") - ({ "" });

    if (!sizeof(a)) {
      ftp_HELP("SITE");
      return;
    }
    a[0] = upper_case(a[0]);
    if (!site_help[a[0]]) {
      send(502, ({ sprintf("Bad SITE command: '%s'", a[0]) }));
    } else if (this_object()["ftp_SITE_"+a[0]]) {
      this_object()["ftp_SITE_"+a[0]](a[1..]);
    } else {
      send(502, ({ sprintf("SITE command '%s' is not currently supported.",
			   a[0]) }));
    }
  }

  void ftp_SITE_CHMOD(array(string) args)
  {
    if (sizeof(args) < 2) {
      send(501, ({ sprintf("'SITE CHMOD %s': incorrect arguments",
			   args*" ") }));
      return;
    }

    int mode;
    foreach(args[0] / "", string m)
      // We do this loop, instead of using a sscanf or cast to be able
      // to catch arguments which aren't an octal number like 0891.
    {
      mode *= 010;
      if(m[0] < '0' || m[0] > '7')
      {
	// This is not an octal number...
	mode = -1;
	break;
      }
      mode += (int)("0"+m);
    }
    if(mode == -1 || mode > 0777)
    {
      send(501, ({ "SITE CHMOD: mode should be between 0 and 0777" }));
      return;
    }

    string fname = fix_path(args[1..]*" ");
    RequestID session = RequestID2(master_session);

    session->method = "CHMOD";
    session->misc->mode = mode;
    session->not_query = fname;
    if (open_file(fname, session, "CHMOD")) {
      send(250, ({ sprintf("Changed permissions of %s to 0%o.",
			   fname, mode) }));
      session->conf->log(([ "error":200 ]), session);
    }
    destruct(session);
  }

  void ftp_SITE_UMASK(array(string) args)
  {
    if (sizeof(args) < 1) {
      send(501, ({ sprintf("'SITE UMASK %s': incorrect arguments",
			   args*" ") }));
      return;
    }

    int mode;
    foreach(args[0] / "", string m)
      // We do this loop, instead of using a sscanf or cast to be able
      // to catch arguments which aren't an octal number like 0891.
    {
      mode *= 010;
      if(m[0] < '0' || m[0] > '7')
      {
	// This is not an octal number...
	mode = -1;
	break;
      }
      mode += (int)("0"+m);
    }
    if(mode == -1 || mode > 0777)
    {
      send(501, ({ "SITE UMASK: mode should be between 0 and 0777" }));
      return;
    }

    master_session->misc->umask = mode;
    send(250, ({ sprintf("Umask set to 0%o.", mode) }));
  }

  void ftp_SITE_PRESTATE(array(string) args)
  {
    if (!sizeof(args)) {
      master_session->prestate = (<>);
      send(200, ({ "Prestate cleared" }));
    } else {
      master_session->prestate = aggregate_multiset(@((args*" ")/","-({""})));
      send(200, ({ "Prestate set" }));
    }
  }

  private void timeout()
  {
    if (fd) {
      int t = (time() - time_touch);
      if (t > FTP2_TIMEOUT) {
	// Recomended by RFC 1123 4.1.3.2
	send(421, ({ "Connection timed out." }));
	send(0,0);
	if (master_session->file) {
	  if (objectp(master_session->file->file)) {
	    destruct(master_session->file->file);
	  }
	  if (objectp(master_session->file->pipe)) {
	    destruct(master_session->file->pipe);
	  }
	}
	if (objectp(pasv_port)) {
	  destruct(pasv_port);
	}
	master_session->method = "QUIT";
	master_session->not_query = user || "Anonymous";
	master_session->conf->log(([ "error":408 ]), master_session);
      } else {
	// Not time yet to sever the connection.
	call_out(timeout, FTP2_TIMEOUT + 30 - t);
      }
    } else {
      // We ought to be dead already...
      DWRITE("FTP2: Timeout on dead connection.\n");
      destruct();
    }
  }

#ifdef FTP_USE_HANDLER_THREADS
  // Minimal layer for API compatibility with ADT.Queue.
  protected class CommandQueue
  {
    inherit Thread.Queue;

    protected int _sizeof()
    {
      return size();
    }

    void put(mixed value)
    {
      write(value);
    }

    mixed get()
    {
      return try_read();
    }
  }
  private CommandQueue cmd_queue = CommandQueue();
#else
  private ADT.Queue cmd_queue = ADT.Queue();
#endif

  private void got_command(mixed ignored, string line)
  {
    DWRITE("FTP2: got_command(X, \"%s\")\n", line);

    touch_me();

    string cmd = line;
    string args;
    int i;

    if (line == "") {
      // The empty command.
      // Some stupid ftp-proxies send this.
      return;	// Even less than a NOOP.
    }

    if ((i = search(line, " ")) != -1) {
      cmd = line[..i-1];
      args = line[i+1..] - "\0";
    }
    cmd = upper_case(cmd);

    if ((< "PASS" >)[cmd]) {
      // Censor line, so that the password doesn't show
      // in backtraces.
      line = cmd + " CENSORED_PASSWORD";
    }

    cmd_queue->put(({ line, cmd, args }));
    if (!busy)
      next_cmd();
  }

  private void low_next_cmd()
  {
    // Protect against multiple call_outs.
    if (busy || !sizeof(cmd_queue)) return;
    busy = 1;

    array(string|array(string)) cmd_entry = cmd_queue->get();
    if (!cmd_entry) {
      // Race?
      busy = 0;
      return;
    }

    string line = cmd_entry[0];
    string cmd = cmd_entry[1];
    array(string) args = cmd_entry[2];

    if (!line) {
      // Command queue terminator.
      terminate_connection();
      return;
    }

#if 0
    if (!conf->extra_statistics) {
      conf->extra_statistics = ([ "ftp": (["commands":([ cmd:1 ])])]);
    } else if (!conf->extra_statistics->ftp) {
      conf->extra_statistics->ftp = (["commands":([ cmd:1 ])]);
    } else if (!conf->extra_statistics->ftp->commands) {
      conf->extra_statistics->ftp->commands = ([ cmd:1 ]);
    } else {
      conf->extra_statistics->ftp->commands[cmd]++;
    }
#endif /* 0 */

    if (cmd_help[cmd]) {
      if (!logged_in) {
	if (!(< "REIN", "USER", "PASS", "SYST", "AUTH",
		"ACCT", "QUIT", "ABOR", "HELP", "FEAT" >)[cmd]) {
	  send(530, ({ "You need to login first." }));

	  return;
	}
      }
      if (!port_obj->query_option("rfc2428_support") &&
	  (< "EPRT", "EPSV" >)[cmd]) {
	send(502, ({ sprintf("support for '%s' is disabled.", cmd) }));
	return;
      }
      if (this_object()["ftp_"+cmd]) {
	conf->requests++;
#ifndef FTP_USE_HANDLER_THREADS
	mixed err;
	if (err = catch {
	  this_object()["ftp_"+cmd](args);
	}) {
	  report_error("Internal server error in FTP2\n"
		       "Handling command %O\n%s\n",
		       line, describe_backtrace(err));
	}
#else
	roxen->handle(lambda(function f, string cmd, string args, string line) {
			//  For e.g. PASS the args string may contain
			//  cleartext password.
			string args_copy = args;
			if (cmd == "PASS")
			  args = "CENSORED";

			mixed err;
			if (err = catch {
			  f(args_copy);
			}) {
			  report_error("Internal server error in FTP2\n"
				       "Handling command %O\n%s\n",
				       line, describe_backtrace(err));
			}
		      }, this_object()["ftp_"+cmd], cmd, args, line);
#endif
      } else {
	send(502, ({ sprintf("'%s' is not currently supported.", cmd) }));
      }
    } else {
      send(502, ({ sprintf("Unknown command '%s'.", cmd) }));
    }

    touch_me();
  }

  private void terminate_connection()
  {
    DWRITE("FTP2: terminate_connection()\n");

    if (fd) {
      // Close the command connection.
      // Note that we have delayed the closing to reduce the risk of races.
      fd->close();
      destruct(fd);
      fd = 0;
    }

    logout();

    if (pasv_port) {
      destruct(pasv_port);
      pasv_port = 0;
    }

    master_session->method = "QUIT";
    master_session->not_query = user || "Anonymous";
    conf->log(([ "error":204, "request_time":(time(1)-master_session->time) ]),
	      master_session);
    // Make sure we disappear...
    destruct();
  }

  void con_closed()
  {
    DWRITE("FTP2: con_closed()\n");

    if (fd) {
      // Clear the read-side callbacks.
      fd->set_close_callback(0);
      fd->set_read_callback(0);
    }

    // Make sure that the TelnetSession level doesn't restore
    // the above callbacks.
    read_cb = 0;
    close_cb = 0;

    send(0, 0);		// EOF marker.

    // Queue a command queue terminator.
    // This will terminate the connection as soon as all pending commands
    // have finished. There apparently exists ftp clients that shut down
    // the command connection before their uploads etc have finished.
    cmd_queue->put(({ 0, 0, 0 }));
    if (!busy)
      next_cmd();
  }

  void destroy()
  {
    DWRITE("FTP2: destroy()\n");

    logout();

    port_obj->sessions--;
    if (master_session) {
      destruct(master_session);
    }
  }

  void create(object fd, object c)
  {
    port_obj = c;

    // FIXME: Only supports one configuration!
    conf = port_obj->urls[port_obj->sorted_urls[0]]->conf;

    // Support delayed loading.
    if (!conf->inited) {
      conf->enable_all_modules();
    }

#if 0
    werror("FTP: conf:%O\n"
	   "FTP:urls:%O\n",
	   mkmapping(indices(conf), values(conf)), port_obj->urls);
#endif /* 0 */

    if (fd->renegotiate) {
      // Default to PROT P for ftps (aka implicit ftp/ssl).
      use_ssl = SSL_ALL;
    }

    master_session = RequestID2();
    master_session->remoteaddr = (fd->query_address()/" ")[0];
    master_session->conf = conf;
    master_session->port_obj = c;
    master_session->my_fd = fd;
    master_session->misc->defaulted = 1;
    ::create(fd, got_command, 0, con_closed, ([]));

    array a = fd->query_address(1)/" ";
    local_addr = a[0];
    local_port = (int)a[1];
    e_mode = has_value(local_addr, ":")?"2":"1";

    call_out(timeout, FTP2_TIMEOUT);

    string s = c->query_option("FTPWelcome");

    s = replace(s,
		({ "$roxen_version", "$roxen_build", "$full_version",
		   "$pike_version", "$ident", }),
		({ roxen->roxen_ver, roxen->roxen_build,
		   roxen->real_version, version(), roxen->version() }));

    send(220, s/"\n", 1);
  }
};

void create(object f, object c)
{
  if (f)
  {
    c->sessions++;
    c->ftp_users++;
    if (f->set_keepalive) {
      // Try to keep stupid firewalls from killing
      // the connection during long uploads.
      f->set_keepalive(1);
    }
    FTPSession(f, c);
  }
}
