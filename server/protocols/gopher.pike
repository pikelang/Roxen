// This is a roxen module. Copyright © 1996 - 1998, Idonex AB.
constant cvs_version = "$Id: gopher.pike,v 1.8 1998/05/20 15:41:44 grubba Exp $";
// Gopher protocol module

inherit "protocols/http"; /* For the variables and such.. */
#include <config.h>
#include <module.h>

import Array;

inline static private string extract_title(string from)
{
  if(!from) return "-- Error: No file --";
  if(!((sscanf(from, "%*s<title>%s</title>", from)==2)
       || (sscanf(from, "%*s<h1>%s</h1>", from)==2)
       || (sscanf(from, "%*s<h2>%s</h2>", from)==2)
       || (sscanf(from, "%*s<h3>%s</h3>", from)==2)
       || (sscanf(from, "%*s<font size=+3>%s</font>", from)==2)))
    return 0;
  while(sscanf(from, "<%*s>%s</%*s>", from));
  return from;
}

static private string encode_direntry(string file, string host, int port)
{
  string title;
  if(!file) return 0;
  string type = conf->type_from_filename(file) || "text/plain";

  /* 0 == file
     1 == dir
     (7== search)
     9 == binary
     g == gif
     I == other image
     */

  /* Format: <type><title>[tab]<filename>[tab]<server>[tab]<port> */

  if(file[-1] == '/') { 
    type="1";
    title = (file/"/")[-2];
  } else  if(type == "text/html") {
    title = extract_title(conf->try_get_file(file, this_object())) ||
      (file/"/")[-1];
    type = "0";
  } else if(!search(type, "text/")) {
    type = "0";
    title = (file/"/")[-1];
  } else if(!search(type, "image/gif")) {
    type = "g";
    title = (file/"/")[-1];
  } else if(!search(type, "image/")) {
    type = "I";
    title = (file/"/")[-1];
  } else {
    type = "9";
    title = (file/"/")[-1];
  }

  return type+title+"\t"+file+"\t"+host+"\t"+port;
}

mapping generate_directory()
{
  array mydir;
  string res;

  if(res=cache_lookup(conf->name+":gopherdir", not_query))
    return ([ "type":"text/gopherdir", "data":res ]);

  mydir = conf->find_dir(not_query, this_object());

  if(!mydir)
    return ([ "type":"text/gopherdir", "data":"0No such dir.\n" ]);

  res = sort(map(map(mydir, lambda(string s, string f) {
    array st;
    f += s;
    if(st = conf->stat_file(f, this_object()))
    {
      if(st[1] < 0) return f + "/";
      return f;
    }
    return 0;
  }, not_query), encode_direntry,
  (my_fd->query_address(1)/" ")[0], (my_fd->query_address(1)/" ")[1]))*"\r\n";
  res += "\r\n";

  cache_set(conf->name+":gopherdir", not_query, res);

  return ([ "type":"text/gopherdir", "data":res ]);
}

void got_data(mixed fooid, string s)
{
  array err;
  mapping file;
  time = _time();

  remove_call_out(do_timeout);

  not_query = (s-"\r")-"\n";
  if(!strlen(not_query))
    not_query = "/";

#ifdef GOPHER_DEBUG
  roxen_perror(sprintf("GOPHER: got_data(X, %O) => %O\n", s, not_query));
#endif /* GOPHER_DEBUG */

  remoteaddr = my_fd->query_address();
  supports = (< "gopher", "images", "tables", >);
  prot = "GOPHER";
  method = "GET";

  conf->received += strlen(s);
  
  if(not_query[-1] == '/')
    file = generate_directory();
  else if(err = catch(file = conf->get_file(this_object()))) {
    internal_error(err);
    file = this_object()->file;
  }

  if(!file)
  {
    end("0No such file, bugger.\r\n");
    return 0;
  }

  if(!file->error)
    file->error=200;

  if(!file->len)
  {
    if(file->data)   file->len = strlen(file->data);
    if(file->file)   file->len += file->file->stat()[1];
  }
  if(file->len > 0) conf->sent+=file->len;
  
  conf->log(file, this_object());

  if(file->data) send(file->data);
  if(file->file) send(file->file);
  if(stringp(file->type) && file->type[0..3] == "text")
  {
    send(".\r\n");
  }
  pipe->set_done_callback(end);
  pipe->output(my_fd);
  return;
}

void gopher_trace_enter(string s, mixed foo)
{
  roxen_perror("GOPHER ENTER:"+s+"\n");
}

void gopher_trace_leave(string s)
{
  roxen_perror("GOPHER LEAVE:"+s+"\n");
}

void create(object f, object c)
{
  if(f)
  {
    ::create(f, c);
    my_fd->set_nonblocking(got_data, lambda(){}, end);

    misc->trace_enter = gopher_trace_enter;
    misc->trace_leave = gopher_trace_leave;
  }
}

