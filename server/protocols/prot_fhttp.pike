inherit Protocol;
//   inherit Stdio.Port : port;
constant supports_ipless=1;
constant name = "fhttp";
constant default_port = 80;

#include <roxen.h>
//<locale-token project="roxen_message"> LOC_M </locale-token>
#define LOC_M(X,Y)	_STR_LOCALE("roxen_message",X,Y)

int dolog;
int requests, received, sent;

HTTPLoop.Loop l;
Stdio.Port portobj;

mapping flatten_headers( mapping from )
{
  mapping res = ([]);
  foreach(indices(from), string f)
    res[f] = from[f]*", ";
  return res;
}

void setup_fake(object o)
{
  mapping vars = ([]);
  o->extra_extension = "";
  o->misc = flatten_headers(o->headers);

  o->cmf = 100*1024;
  o->cmp = 100*1024;

  if(o->method == "POST" && strlen(o->data))
  {
    mapping variabels = ([]);
    switch((o->misc["content-type"]/";")[0])
    {
      default: // Normal form data, handled in the C part.
	break;

      case "multipart/form-data":
	object messg = MIME.Message(o->data, o->misc);
	mapping misc = o->misc;
	foreach(messg->body_parts, object part)
	{
	  if(part->disp_params->filename)
	  {
	    vars[part->disp_params->name]=part->getdata();
	    vars[part->disp_params->name+".filename"]=
	      part->disp_params->filename;
	    if(!misc->files)
	      misc->files = ({ part->disp_params->name });
	    else
	      misc->files += ({ part->disp_params->name });
	  } else {
	    vars[part->disp_params->name]=part->getdata();
	  }
	}
	break;
    }
    o->variables = vars|o->variables;
  }

  string contents;
  if(contents = o->misc["cookie"])
  {
    string c;
    mapping cookies = ([]);
    multiset config = (<>);
    o->misc->cookies = contents;
    foreach(((contents/";") - ({""})), c)
    {
      string name, value;
      while(sizeof(c) && c[0]==' ') c=c[1..];
      if(sscanf(c, "%s=%s", name, value) == 2)
      {
	value=http_decode_string(value);
	name=http_decode_string(name);
	cookies[ name ]=value;
	if(name == "RoxenConfig" && strlen(value))
	  config = aggregate_multiset(@(value/"," + ({ })));
      }
    }


    o->cookies = cookies;
    o->config = config;
  } else {
    o->cookies = ([]);
    o->config = (<>);
  }

  if(contents = o->misc->accept)
    o->misc->accept = contents/",";

  if(contents = o->misc["accept-charset"])
    o->misc["accept-charset"] = ({ contents/"," });

  if(contents = o->misc["accept-language"])
    o->misc["accept-language"] = ({ contents/"," });

  if(contents = o->misc["session-id"])
    o->misc["session-id"] = ({ contents/"," });
}


void handle_request(object o)
{
  setup_fake( o ); // Equivalent to parse_got in http.pike
  roxen.handle( o->handle_request, this_object() );
}

int cdel=10;
void do_log()
{
  if(l->logp())
  {
    //     werror("log..\n");
    switch(query("log"))
    {
      case "None":
	l->log_as_array();
	break;
      case "CommonLog":
	object f = Stdio.File( query("log_file"), "wca" );
	l->log_as_commonlog_to_file( f );
	destruct(f);
	break;
      default:
	report_notice( "It is not yet possible to log using the "+
		       query("log")+" method. Sorry. Out of time...");
	break;
    }
    cdel--;
    if(cdel < 1) cdel=1;
  } else {
    cdel++;
    //     werror("nolog..\n");
  }
  call_out(do_log, cdel);
}

string status( )
{
  mapping m = l->cache_status();
  string res;
  low_adjust_stats( m );
#define PCT(X) ((int)(((X)/(float)(m->total+0.1))*100))
  res = ("\nCache statistics\n<pre>\n");
  m->total = m->hits + m->misses + m->stale;
  res += sprintf(" %d elements in cache, size is %1.1fMb max is %1.1fMb\n"
		 " %d cache lookups, %d%% hits, %d%% misses and %d%% stale.\n",
		 m->entries, m->size/(1024.0*1024.0), m->max_size/(1024*1024.0),
		 m->total, PCT(m->hits), PCT(m->misses), PCT(m->stale));
  return res+"\n</pre>\n";
}

void low_adjust_stats(mapping m)
{
  array q = values( urls )->conf;
  if( sizeof( q ) ) /* This is not exactly correct if sizeof(q)>1 */
  {
    q[0]->requests += m->num_request;
    q[0]->received += m->received_bytes;
    q[0]->sent     += m->sent_bytes;
  }
  requests += m->num_requests;
  received += m->received_bytes;
  sent     += m->sent_bytes;
}


void adjust_stats()
{
  call_out(adjust_stats, 2);
  // werror( status() );
  low_adjust_stats( l->cache_status() );
}

#include <variables.h>
#ifdef FWWW_DEBUG
# define FWWW_WERR(X) werror("FWWW: "+X+"\n");
#else
# define FWWW_WERR(X)
#endif

class Connection
{
  inherit HTTPLoop.prog : orig;
  inherit "protocols/http.pike";
  inherit "roxenlib";

  static mapping _modified = ([]);

  int _nono=0;

  mixed `->=(string a, mixed b)
  {
    switch(a)
    {
      case "file": return file = b;
      case "conf": return conf = b;
      case "misc": return misc = b;
      case "_nono": return _nono = b;
      default: return _modified[a] = b;
    }
  }

  mixed `[]=(string a, string b)
  {
    return `->=(a,b);
  }

  mixed `->(string a)
  {
    switch(a)
    {
      case "end": return lambda(){ destruct(); };
      case "file": return file;
      case "conf": return conf;
      case "misc": return misc;
      case "clone_me": return clone_me;
      case "send_result": return send_result;
      case "my_fd":
	return connection();
      case "_nono": return _nono;
      default:
	if(_modified[a]) return _modified[a];
	if(!_nono) return orig::`->(a);
    }
  }

  private Stdio.File fdo;
  Stdio.File connection( )
  {
    if( fdo )  return fdo;
    object fdo = Stdio.File();
    fdo->_fd = orig::`->("my_fd");
    return fdo;
  }


  mixed `[](string a)
  {
    return `->(a);
  }

  // Send the result.
  void send_result(mapping|void result)
  {
    array err;
    int tmp;
    mapping heads;
    string head_string;
    object thiso = this_object();


    if (result)
      file = result;

    FWWW_WERR(sprintf("send_result(%O)", file));

    if(!mappingp(file))
    {
      if(misc->error_code)
	file = http_low_answer( misc->error_code, errors[misc->erorr_code] );
      else if(this_object()->method != "GET" &&
	      this_object()->method != "HEAD" &&
	      this_object()->method != "POST")
	file = http_low_answer(501, "Not implemented.");
      else if(err = catch {
	file=http_low_answer(404,
			     parse_rxml(conf->query("ZNoSuchFile"),thiso));
      }) {
      internal_error(err);
    }
  } else {
    if((file->file == -1) || file->leave_me)
    {
      FWWW_WERR("file->file == -1 or file->leave_me.");
      if(_modified->do_not_disconnect) {
	FWWW_WERR("do_not_disconnect.");
        file = 0;
        return;
      }
      // 	destruct(this_object());
      return;
    }
    if(!file->type)     file->type="text/plain";
  }

  if(!file->raw)
  {
    string h;
    heads=
      (["MIME-Version":(file["mime-version"] || "1.0"),
        "Content-type":file["type"],
        "Server":replace(version(), " ", "·"),
        // 	"Date":http_date(this_object()->time)
      ]);

    if(file->encoding)
      heads["Content-Encoding"] = file->encoding;

    if(!file->error)
      file->error=200;

    if(file->expires)
      heads->Expires = http_date(file->expires);

    if(!file->len)
    {
      if(objectp(file->file))
        if(!file->stat && !(file->stat=misc->stat))
          file->stat = (array(int))file->file->stat();
      array fstat;
      if(arrayp(fstat = file->stat))
      {
        if(file->file && !file->len)
          file->len = fstat[1];

        heads["Last-Modified"] = http_date(fstat[3]);

//         if(this_object()->since)
//         {
//           if(is_modified(this_object()->since, fstat[3], fstat[1]))
//           {
//             file->error = 304;
//             file->file = 0;
//             file->data="";
//             misc->cacheable=0;
//           }
//         }

      }
      if(stringp(file->data))
        file->len += strlen(file->data);
    }

    if(mappingp(file->extra_heads))
      heads |= file->extra_heads;

    if(mappingp(misc->moreheads))
      heads |= misc->moreheads;

    array myheads = ({this_object()->prot+" "+
                      (file->rettext||errors[file->error])});
    foreach(indices(heads), h)
      if(arrayp(heads[h]))
        foreach(heads[h], tmp)
          myheads += ({ `+(h,": ", tmp)});
      else
        myheads +=  ({ `+(h, ": ", heads[h])});


    if(file->len > -1)
      myheads += ({"Content-length: " + file->len });
    myheads += ({ "Connection: Keep-Alive" });
    head_string = (myheads+({"",""}))*"\r\n";
  } else {
    misc->cacheable=0;
  }

  if(this_object()->method == "HEAD")
  {
    file->file = 0;
    file->data="";
    misc->cacheable=0;
  }

  if(misc->cacheable)
  {
    if(file->data)
    {
      if(_modified->cmp < file->len/1024)
      {
        misc->cacheable=0;
      }
    } else if(_modified->cmf < file->len/1024) {
      misc->cacheable=0;
    }
  }

  if(head_string && misc->cacheable)
  {
    string data=head_string + (file->data||"");
    if(file->file)
      data += file->file->read();
    reply_with_cache( data, misc->cacheable );
    destruct();
  } else {
    //       werror("reply: '%s' %s<%d>\n",
    // 	     head_string, (file->file?"file":"nofile"), file->len);
    if(file->file)
      reply( head_string, file->file, file->len );
    else
      reply( head_string+file->data );
    destruct();
  }
}


// Execute the request
void handle_request( object port_obj )
{
  _modified->port_obj = port_obj;
  mixed err;

  misc->cacheable = 120;

  //  werror("Handle request, got conf.\n");

  function funp;
  object thiso=this_object();

  if (misc->host)
  {
    conf =
         port_obj->find_configuration_for_url(port_obj->name + "://" +
                                              misc->host +
                                              (search(misc->host, ":")<0?
                                               (":"+port_obj->default_port)
                                               :"") +
                                              this_object()->not_query,
                                              this_object());

  } else {
    // No host header.
    // Fallback to using the first configuration bound to this port.
    conf = port_obj->urls[port_obj->sorted_urls[0]]->conf;
  }
  _modified->conf = conf;

  string contents;
  if(contents = misc->authorization)
  {
    array(string) y;
    y = contents / " ";
    `->=("rawauth",y[1]);
    if(sizeof(y) >= 2)
    {
      y[1] = MIME.decode_base64(y[1]);
      `->=("realauth",y[1]);
      if(conf && conf->auth_module)
        y = conf->auth_module->auth( y, thiso );
      `->=("auth",y);
    }
  }

  if(contents = misc["proxy-authorization"])
  {
    array(string) y;
    y = contents / " ";
    if(sizeof(y) > 2)
    {
      y[1] = MIME.decode_base64(y[1]);
      if(conf && conf->auth_module)
        y = conf->auth_module->auth( y, thiso );
      `->=("proxyauth",y);
    }
  }

  if(prestate->old_error)
  {
    array err = get_error(variables->error);
    if(err)
    {
      if(prestate->plain)
      {
        file = ([
          "type":"text/html",
          "data":generate_bugreport( @err ),
        ]);
        send_result();
        return;
      } else {
//   if(prestate->find_file)
//   {
//     if(!realauth)
//       file = http_auth_required("admin");
//     else
//     {
//       array auth = (realauth+":")/":";
//       if((auth[0] != roxen.query("ConfigurationUser"))
//          || !crypt(auth[1], roxen.query("ConfigurationPassword")))
//         file = http_auth_required("admin");
//       else
//         file = ([
//           "type":"text/html",
//           "data":handle_error_file_request( err[0],
//                                             (int)variables->error ),
//         ]);
//     }
//     send_result();
//     return;
//   }
      }
    }
  }

  mixed e ;
  if( e = catch(file = conf->handle_request( this_object() )) )
    internal_error( e );
//   if( _modified->file )
//     file = _modified->file;
  send_result();
}
}


void create( int pn, string i )
{
  requesthandler = Connection;

  port = pn;
  ip = i;
  roxen.set_up_fhttp_variables( this_object() );
  restore();

  dolog = (query_option( "log" ) && (query_option( "log" )!="None"));
  portobj = Stdio.Port(); /* No way to use ::create easily */
  if( !portobj->bind( port, 0, ip ) )
  {
    report_error(LOC_M(6,"Failed to bind %s://%s:%d/ (%s)")+"\n",
		 name,ip||"*",(int)port, strerror(errno()));
    destruct(portobj);
    return;
  }

  l = HTTPLoop.Loop( portobj, requesthandler,
		     handle_request, 0,
		     ((int)query_option("ram_cache")||20)*1024*1024,
		     dolog, (query_option("read_timeout")||120) );

  call_out(adjust_stats, 10);
  if(dolog)
    call_out(do_log, 5);
}
