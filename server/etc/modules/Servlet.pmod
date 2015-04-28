
#if constant(Java.jvm)

protected object jvm = Java.machine;

#define FINDCLASS(X) (jvm && (jvm->find_class(X)||(jvm->exception_describe(),jvm->exception_clear(),error("Failed to load class " X ".\n"),0)))
#define FIND_METHOD(C, M...) ((C) && (C)->get_method (M))
#define FIND_STATIC_METHOD(C, M...) ((C) && (C)->get_static_method (M))
#define FIND_FIELD(C, F...) ((C) && (C)->get_field (F))

protected object servlet_ifc = FINDCLASS("javax/servlet/Servlet");
protected object singlethread_ifc = FINDCLASS("javax/servlet/SingleThreadModel");
protected object class_class = FINDCLASS("java/lang/Class");
protected object classloader_class = FINDCLASS("java/lang/ClassLoader");
protected object classloader2_class = FINDCLASS("java/net/URLClassLoader");
protected object config_class = FINDCLASS("com/roxen/servlet/ServletConfig");
protected object context_class = FINDCLASS("com/roxen/servlet/RoxenServletContext");
protected object request_class = FINDCLASS("com/roxen/servlet/ServletRequest");
protected object response_class = FINDCLASS("com/roxen/servlet/ServletResponse");
protected object stream_class = FINDCLASS("com/roxen/servlet/HTTPOutputStream");
protected object session_context_class = FINDCLASS("com/roxen/servlet/RoxenSessionContext");
protected object dictionary_class = FINDCLASS("java/util/Dictionary");
protected object hashtable_class = FINDCLASS("java/util/Hashtable");
protected object throwable_class = FINDCLASS("java/lang/Throwable");
protected object unavailable_class = FINDCLASS("javax/servlet/UnavailableException");
protected object servlet_exc_class = FINDCLASS("javax/servlet/ServletException");
protected object stringwriter_class = FINDCLASS("java/io/StringWriter");
protected object printwriter_class = FINDCLASS("java/io/PrintWriter");
protected object vector_class = FINDCLASS("java/util/Vector");
protected object file_class = FINDCLASS("java/io/File");
protected object url_class = FINDCLASS("java/net/URL");
protected object string_class = FINDCLASS("java/lang/String");
protected object jarutil_class = FINDCLASS("com/roxen/roxen/JarUtil");

protected object new_instance = FIND_METHOD (class_class, "newInstance", "()Ljava/lang/Object;");
protected object file_init = FIND_METHOD (file_class, "<init>", "(Ljava/lang/String;)V");
protected object file_tourl = FIND_METHOD (file_class, "toURL", "()Ljava/net/URL;");
protected object load_class = FIND_METHOD (classloader_class, "loadClass", "(Ljava/lang/String;)Ljava/lang/Class;");
protected object cl_init = FIND_METHOD (classloader2_class, "<init>", "([Ljava/net/URL;)V");
protected object servlet_init = FIND_METHOD (servlet_ifc, "init", "(Ljavax/servlet/ServletConfig;)V");
protected object servlet_destroy = FIND_METHOD (servlet_ifc, "destroy", "()V");
protected object servlet_getservletinfo = FIND_METHOD (servlet_ifc, "getServletInfo", "()Ljava/lang/String;");
protected object servlet_service = FIND_METHOD (servlet_ifc, "service", "(Ljavax/servlet/ServletRequest;Ljavax/servlet/ServletResponse;)V");
protected object cfg_init = FIND_METHOD (config_class, "<init>", "(Ljavax/servlet/ServletContext;Ljava/lang/String;)V");
protected object context_init = FIND_METHOD (context_class, "<init>", "(ILjava/lang/String;)V");
protected object context_id_field = FIND_FIELD (context_class, "id", "I");
protected object context_initpars_field = FIND_FIELD (context_class, "initparameters", "Ljava/util/Hashtable;");
protected object context_set_attribute = FIND_METHOD (context_class, "setAttribute", "(Ljava/lang/String;Ljava/lang/Object;)V");
protected object request_init = FIND_METHOD (request_class, "<init>", "(Lcom/roxen/servlet/RoxenServletContext;Lcom/roxen/servlet/RoxenSessionContext;ILjava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;ILjava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V");
protected object response_init = FIND_METHOD (response_class, "<init>", "(Lcom/roxen/servlet/HTTPOutputStream;)V");
protected object dic_field = FIND_FIELD (config_class, "dic", "Ljava/util/Dictionary;");
protected object params_field = FIND_FIELD (request_class, "parameters", "Ljava/util/Dictionary;");
protected object attrs_field = FIND_FIELD (request_class, "attributes", "Ljava/util/Dictionary;");
protected object headers_field = FIND_FIELD (request_class, "headers", "Ljava/util/Dictionary;");
protected object set_response_method = FIND_METHOD (request_class, "setResponse", "(Lcom/roxen/servlet/ServletResponse;)V");
protected object dic_put = FIND_METHOD (dictionary_class, "put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
protected object hash_clear = FIND_METHOD (hashtable_class, "clear", "()V");
protected object stream_id_field = FIND_FIELD (stream_class, "id", "I");
protected object stream_init = FIND_METHOD (stream_class, "<init>", "(I)V");
protected object throwable_printstacktrace = FIND_METHOD (throwable_class, "printStackTrace", "(Ljava/io/PrintWriter;)V");
protected object throwable_getmessage = FIND_METHOD (throwable_class, "getMessage", "()Ljava/lang/String;");
protected object unavailable_ispermanent = FIND_METHOD (unavailable_class, "isPermanent", "()Z");
protected object unavailable_getunavailableseconds = FIND_METHOD (unavailable_class, "getUnavailableSeconds", "()I");
protected object servlet_exc_getrootcause = FIND_METHOD (servlet_exc_class, "getRootCause", "()Ljava/lang/Throwable;");
protected object stringwriter_init = FIND_METHOD (stringwriter_class, "<init>", "()V");
protected object printwriter_init = FIND_METHOD (printwriter_class, "<init>", "(Ljava/io/Writer;)V");
protected object printwriter_flush = FIND_METHOD (printwriter_class, "flush", "()V");
protected object wrapup_method = FIND_METHOD (response_class, "wrapUp", "()V");
protected object session_context_init = FIND_METHOD (session_context_class, "<init>", "()V");
protected object vector_init = FIND_METHOD (vector_class, "<init>", "()V");
protected object vector_add = FIND_METHOD (vector_class, "add", "(Ljava/lang/Object;)Z");
protected object jarutil_expand = FIND_STATIC_METHOD (jarutil_class, "expand", "(Ljava/lang/String;Ljava/lang/String;)V");


protected object natives_bind1, natives_bind2, natives_bind3;

#define error(X) throw(({(X), backtrace()}))

protected void check_exception()
{
  object e = jvm->exception_occurred();
  if(e) {
    jvm->exception_clear();
    object sw = stringwriter_class->alloc();
    stringwriter_init(sw);
    object pw = printwriter_class->alloc();
    printwriter_init(pw, sw);
    if (e->is_instance_of(servlet_exc_class))
      {
        object re = servlet_exc_getrootcause(e);
        if (re)
          throwable_printstacktrace(re, pw);
      }
    throwable_printstacktrace(e, pw);
    printwriter_flush(pw);
    array bt = backtrace();
    // FIXME: KLUDGE: Sometimes the cast fails for some reason.
    string s = "Unknown Java exception (StringWriter failed)";
    catch {
      s = (string)sw;
    };
    throw(({s, bt[..sizeof(bt)-2]}));
  }
}

protected void check_unavailable_exception()
{
  object e = jvm->exception_occurred();
  if(e) {
    if (e->is_instance_of(unavailable_class))
      {
        jvm->exception_clear();
        array bt = backtrace();
        throw(
              ({ "UnavailableException\n",
                 (string)throwable_getmessage(e),
                 (int)unavailable_ispermanent(e),
                 (int)unavailable_getunavailableseconds(e)
              })
              );
      }
    else
      check_exception();
  }
}

class jarutil {

  void expand(string dir, string jar)
  {
    jarutil_expand(dir, jar);
    check_exception();
  }

}

class servlet {

  protected object s, d;
  protected object context;
  protected string classname;
  int singlethreaded = 0;
  protected object lock;

  void destroy()
  {
    if(s && d) {
      d(s);
      s = 0;
    }
  }

  void service(object req, object|void res)
  {
    if(!res) {
      res = response(req->my_fd);
      req = request(context, req);
    }
    set_response_method(req, res);
    if(singlethreaded) {
      object key = lock->lock();
      servlet_service(s, req, res);
      key = 0;
    } else
      servlet_service(s, req, res);
    check_exception();
    wrapup_method(res);
    check_exception();
  }

  string info()
  {
    object i = servlet_getservletinfo(s);
    check_exception();
    return i && (string)i;
  }

  void init(object cfgctx, mapping(string:string)|void params, string|void nam)
  {
    context = cfgctx;
    if(params)
      cfgctx = config(cfgctx, params, nam||classname);
    servlet_init(s, cfgctx->cfg);
    check_unavailable_exception();
    d = servlet_destroy;
  }

  void create(string|object name, string|array(string)|object|void dir)
  {
    if(stringp(name)) {
      classname = name;
      if(!objectp(dir))
	dir = loader(dir||".");
      name = dir->low_load(name);
    }

    if(!name) {
      destruct(this_object());
      return;
    }
    s = new_instance(name);
    check_exception();
    if(!s->is_instance_of(servlet_ifc))
      error("class does not implement javax.servlet.Servlet\n");
    if(s->is_instance_of(singlethread_ifc)) {
      lock = Thread.Mutex();
      singlethreaded = 1;
    }
  }

};

class loader {

  protected object cl;

  object low_load(string name)
  {
    object c = load_class(cl, name);
    check_exception();
    return c;
  }

  object load(string name)
  {
    return servlet(name, this_object());
  }

  void create(string|array(string) codedirs)
  {
    if(stringp(codedirs))
      codedirs = ({ codedirs });
    object urls = url_class->new_array(sizeof(codedirs));
    check_exception();
    int i=0;
    foreach(codedirs, string codedir) {
      object f = file_class->alloc();
      check_exception();
      file_init->call_nonvirtual(f, combine_path(getcwd(), codedir));
      check_exception();
      object url = file_tourl(f);
      check_exception();
      urls[i++] = url;
      check_exception();
    }
    cl = classloader2_class->alloc();
    check_exception();
    cl_init->call_nonvirtual(cl, urls);
    check_exception();
  }

};

class config {

  object cfg;

  void create(object context, mapping(string:string)|void params,
	      string|void name)
  {
    cfg = config_class->alloc();
    check_exception();
    cfg_init(cfg, context->ctx, name);
    check_exception();
    if(params) {
      object dic = dic_field->get(cfg);
      foreach(indices(params), string key)
	dic_put(dic, key, params[key]);
    }
  }

};

protected int context_id = 1;
protected mapping(int:object) contexts = ([]);
protected mapping(object:object) context_for_conf = ([]);

protected object ctx_object(object ctx)
{
  return contexts[context_id_field->get(ctx)];
}


class context {

  object ctx, sctx, conf;
  RoxenModule parent_module;
  protected int id;
  protected string dir;

  string gettempdir()
  {
    if (parent_module)
      dir += "conf_mod/" + parent_module->module_identifier() + "/";
    else if(conf)
      dir += "conf/" + conf->name + "/";
    else
      dir += "unbound/";
    if(!file_stat(dir))
      mkdirhier(dir);
    return dir;
  }

  void create(object|void c, RoxenModule|void mod, string|void _tmpdir)
  {
    dir = _tmpdir || "servlettmp/";
    parent_module = mod;
    id = context_id++;
    conf = c;
    ctx = context_class->alloc();
    check_exception();
    context_init(ctx, id, gettempdir());
    check_exception();
    sctx = session_context_class->alloc();
    check_exception();
    session_context_init(sctx);
    contexts[id] = this_object();
    if(conf && !parent_module) {
      if(context_for_conf[conf])
	destruct(context_for_conf[conf]);
      context_for_conf[conf] = this_object();
    }
    if(c)
    {
      set_attribute("roxen_configuration", c->name);
      check_exception();
    }
  }

  void destroy()
  {
    m_delete(contexts, id);
    if(conf)
      m_delete(context_for_conf, conf);
    ctx=0;
  }

  RequestID make_dummy_id()
  {
    RequestID req = roxen->InternalRequestID();
    req->conf = conf;
    return req;
  }

  void log(string msg)
  {
    werror(msg+"\n");
  }

  string get_real_path(string path)
  {
    string loc;
    string real_loc;
    if (parent_module) {
      loc = parent_module->query_location();
      real_loc = conf->real_file(loc, make_dummy_id());
    }
    else if (conf) {
      foreach(conf->location_modules(), array tmp) {
        loc = tmp[0];
        if (has_prefix(path, loc)) {
          real_loc = conf->real_file(loc, make_dummy_id());
        }
      }
    } 

    if (real_loc) {
      if (real_loc[-1] != '/')
        real_loc += "/";
      if (path[0] == '/')
        path = path[1..];
      real_loc = combine_path(real_loc + path);
#ifdef __NT__
      real_loc = replace(real_loc, "/", "\\");
#endif
      return real_loc;
    }

    return 0;
  }
  
  string get_mime_type(string file)
  {
    return conf && conf->type_from_filename(file);
  }

  string get_server_info()
  {
    return roxen->version();
  }

  object get_request_dispatcher(string path)
  {
    // FIXME
    return 0;
  }

  string get_resource(string path)
  {
    string rp;
#ifdef __NT__
    path = replace(path, "\\", "/");
#endif
    rp = get_real_path(path);
    return rp && ("file:"+rp);
  }

  void set_init_parameters(mapping(string:string) pars)
  {
    object f = context_initpars_field->get(ctx);
    hash_clear(f);
    foreach(indices(pars), string key)
      dic_put(f, key, pars[key]);
    check_exception();
  }

  void set_attribute(string name, mixed attribute)
  {
    context_set_attribute(ctx, name, attribute);
  }
};

object conf_context(object conf)
{
  return context_for_conf[conf]||context(conf);
}

object request(object context, mapping(string:array(string))|object id,
	       mapping(string:string|object)|void attrs,
	       mapping(string:array(string)|string)|void headers, mixed ... rest)
{
  if(objectp(id)) {
    string tmp = id->url_base();
    sscanf(tmp, "%*s//%s", tmp);
    sscanf(tmp, "%s:", tmp);
    sscanf(tmp, "%s/", tmp);
    string addr = id->remoteaddr || "Internal";
    string host = roxen->quick_ip_to_host(addr);
    string uri, query, pathtrans;
    if(id->raw) {
      if(sscanf(id->raw, "%[^?\r\n]?%s%*[ \t\n]", uri, query)>1)
	sscanf(query, "%[^\r\n]", query);
      else {
	query="";
	sscanf(uri, "%[^\r\n]", uri);
      }
      uri = (uri/" "+({"",""}))[1];
      if(!strlen(query))
	query = 0;
    } else {
      uri = id->not_query;
      query = id->query;
    }

    if(id->misc->path_info && strlen(id->misc->path_info) && context) {
      pathtrans = context->get_real_path(id->misc->path_info);
    }

    return request(context||conf_context(id->conf), id->real_variables, attrs,
		   (id->raw && MIME.parse_headers(id->raw)[0])||id->request_headers,
		   (zero_type(id->misc->len)? -1:id->misc->len),
		   id->misc["content-type"], id->prot,
                   (id && id->port_obj && lower_case(id->port_obj->prot_name))||
		   lower_case((id->prot/"/")[0]), tmp,		   
		   (id->my_fd&&id->my_fd->query_address&&
                    (int)((id->my_fd->query_address(1)||"0 0")/" ")[1]),
		   addr, (host != addr)&&host, id->data,
		   id->misc->mountpoint, id->misc->servlet_path,
                   id->misc->path_info, id->method,
                   id->misc->authenticated_user &&
                   id->misc->authenticated_user->name &&
                   id->misc->authenticated_user->name(),
		   uri, query, pathtrans);
  }
  object r = request_class->alloc();
  check_exception();
  request_init(r, context->ctx, context->sctx, @rest);
  check_exception();
  object pa = params_field->get(r);
  foreach(indices(id), string v) {
    array(string) vals = id[v];
    object sa = string_class->new_array(sizeof(vals));
    foreach(indices(vals), int vi)
      sa[vi] = vals[vi];
    dic_put(pa, v, sa);
  }
  if(attrs) {
    object at = attrs_field->get(r);
    foreach(indices(attrs), string a)
      dic_put(at, a, attrs[a]);
  }
  object hh = headers_field->get(r);
  if(headers)
    foreach(indices(headers), string h)
      if(stringp(headers[h]))
	dic_put(hh, h, headers[h]);
      else {
	object v = vector_class->alloc();
	vector_init(v);
	foreach(headers[h], string hx)
	  vector_add(v, hx);
	dic_put(hh, h, v);
      }
  else
    headers_field->put(r, 0);
  check_exception();
  return r;
}

protected int stream_id = 0;
mapping(int:object) streams = ([]);

object response(object file)
{
  int id = stream_id++;
  object s = stream_class->alloc();
  check_exception();
  if(!s) return 0;
  stream_init(s, id);
  check_exception();
  object r = response_class->alloc();
  check_exception();
  if(!r) return 0;
  response_init(r, s);
  destruct(s);
  check_exception();
  streams[id] = file;
  return r;
}


protected void native_log(object ctx, object msg)
{
  if (ctx_object(ctx))
    ctx_object(ctx)->log((string)msg);
  else
    werror((string)msg + "\n");
}

protected string native_getRealPath(object ctx, object path)
{
  return ctx_object(ctx)->get_real_path((string)path);
}

protected string native_getMimeType(object ctx, object file)
{
  return ctx_object(ctx)->get_mime_type((string)file);
}

protected string native_getServerInfo(object ctx)
{
  return ctx_object(ctx)->get_server_info();
}

protected object native_getRequestDispatcher(object ctx, object path1,
					     object path2)
{
  return ctx_object(ctx)->get_request_dispatcher(combine_path((string)path1,
							      (string)path2));
}

protected string native_getResourceURL(object ctx, object path)
{
  return ctx_object(ctx)->get_resource((string)path);
}

protected void native_forgetfd(object str)
{
  int id = stream_id_field->get(str);
  object f = streams[id];
  m_delete(streams, id);
  if(f)
    destruct(f);
}

protected void native_close(object str)
{
  int id = stream_id_field->get(str);
  object f = streams[id];
  if(f) {
    m_delete(streams, id);
    f->close();
  }
}

protected void native_writeba(object str, object b, int off, int len)
{
  object f = streams[stream_id_field->get(str)];
  if(f)
    f->write(((string)values(b[off..off+len-1]))&("\xff"*len));
}

protected string native_blockingIPToHost(object n)
{
  return roxen->blocking_ip_to_host((string)n);
}

void create()
{
  if (!jvm) return;

  if (!context_class->register_natives)
    error ("No support for native methods in the Java module.\n");
  natives_bind1 = context_class->register_natives(({
    ({"log", "(Ljava/lang/String;)V", native_log}),
    ({"getRealPath", "(Ljava/lang/String;)Ljava/lang/String;",
      native_getRealPath}),
    ({"getMimeType", "(Ljava/lang/String;)Ljava/lang/String;",
      native_getMimeType}),
    ({"getServerInfo", "()Ljava/lang/String;", native_getServerInfo}),
    ({"getRequestDispatcher", "(Ljava/lang/String;Ljava/lang/String;)Ljavax/servlet/RequestDispatcher;", native_getRequestDispatcher}),
    ({"getResourceURL", "(Ljava/lang/String;)Ljava/lang/String;", native_getResourceURL})}));
  natives_bind2 = stream_class->register_natives(({
    ({"low_close", "()V", native_close}),
    ({"low_write", "([BII)V", native_writeba}),
    ({"forgetfd", "()V", native_forgetfd})}));

  natives_bind3 = request_class->register_natives(({
    ({"blockingIPToHost", "(Ljava/lang/String;)Ljava/lang/String;",
      native_blockingIPToHost})}));
}

#endif
