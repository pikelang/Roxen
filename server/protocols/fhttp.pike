// This is a roxen protocol module.
// Copyright © 1996 - 1999, Idonex AB.
#include <variables.h>

#ifdef FWWW_DEBUG
# define FWWW_WERR(X) werror("FWWW: "+X+"\n");
#else
# define FWWW_WERR(X)
#endif

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
                           replace(parse_rxml(conf->query("ZNoSuchFile"),
                                              thiso),
                                   ({"$File", "$Me"}),
                                   ({this_object()->not_query,
                                     conf->query("MyWorldLocation")})));
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
    string *y;
    `->=("rawauth",y[1]);
    y = contents / " ";
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
