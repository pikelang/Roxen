
static constant jvm = Java.machine;

#define FINDCLASS(X) (jvm->find_class(X)||(jvm->exception_describe(),jvm->exception_clear(),error("Failed to load class " X ".\n"),0))

static object servlet_ifc = FINDCLASS("javax/servlet/Servlet");
static object singlethread_ifc = FINDCLASS("javax/servlet/SingleThreadModel");
static object class_class = FINDCLASS("java/lang/Class");
static object classloader_class = FINDCLASS("java/lang/ClassLoader");
static object classloader2_class = FINDCLASS("se/idonex/servlet/ClassLoader");
static object config_class = FINDCLASS("se/idonex/servlet/ServletConfig");
static object context_class = FINDCLASS("se/idonex/servlet/RoxenServletContext");
static object request_class = FINDCLASS("se/idonex/servlet/ServletRequest");
static object response_class = FINDCLASS("se/idonex/servlet/ServletResponse");
static object stream_class = FINDCLASS("se/idonex/servlet/HTTPOutputStream");
static object dictionary_class = FINDCLASS("java/util/Dictionary");
static object throwable_class = FINDCLASS("java/lang/Throwable");
static object stringwriter_class = FINDCLASS("java/io/StringWriter");
static object printwriter_class = FINDCLASS("java/io/PrintWriter");
static object new_instance = class_class->get_method("newInstance",
						     "()Ljava/lang/Object;");
static object load_class = classloader_class->get_method("loadClass", "(Ljava/lang/String;)Ljava/lang/Class;");
static object cl_init = classloader2_class->get_method("<init>", "(Ljava/lang/String;)V");
static object servlet_init = servlet_ifc->get_method("init", "(Ljavax/servlet/ServletConfig;)V");
static object servlet_destroy = servlet_ifc->get_method("destroy", "()V");
static object servlet_getservletinfo = servlet_ifc->get_method("getServletInfo", "()Ljava/lang/String;");
static object servlet_service = servlet_ifc->get_method("service", "(Ljavax/servlet/ServletRequest;Ljavax/servlet/ServletResponse;)V");
static object cfg_init = config_class->get_method("<init>", "(Ljavax/servlet/ServletContext;)V");
static object context_init = context_class->get_method("<init>", "(I)V");
static object context_id_field = context_class->get_field("id", "I");
static object request_init = request_class->get_method("<init>", "(Ljavax/servlet/ServletContext;ILjava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;ILjava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V");
static object response_init = response_class->get_method("<init>", "(Ljavax/servlet/ServletOutputStream;)V");
static object dic_field = config_class->get_field("dic", "Ljava/util/Dictionary;");
static object params_field = request_class->get_field("parameters", "Ljava/util/Dictionary;");
static object attrs_field = request_class->get_field("attributes", "Ljava/util/Dictionary;");
static object headers_field = request_class->get_field("headers", "Ljava/util/Dictionary;");
static object dic_put = dictionary_class->get_method("put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
static object stream_id_field = stream_class->get_field("id", "I");
static object stream_init = stream_class->get_method("<init>", "(I)V");
static object throwable_printstacktrace = throwable_class->get_method("printStackTrace", "(Ljava/io/PrintWriter;)V");
static object stringwriter_init = stringwriter_class->get_method("<init>", "()V");
static object printwriter_init = printwriter_class->get_method("<init>", "(Ljava/io/Writer;)V");
static object printwriter_flush = printwriter_class->get_method("flush", "()V");
static object wrapup_method = response_class->get_method("wrapUp", "()V");

static object natives_bind1, natives_bind2, natives_bind3;

#define error(X) throw(({(X), backtrace()}))

static void check_exception()
{
  object e = jvm->exception_occurred();
  if(e) {
    object sw = stringwriter_class->alloc();
    stringwriter_init(sw);
    object pw = printwriter_class->alloc();
    printwriter_init(pw, sw);
    throwable_printstacktrace(e, pw);
    printwriter_flush(pw);
    jvm->exception_clear();
    array bt = backtrace();
    throw(({(string)sw, bt[..sizeof(bt)-2]}));
  }
}

class servlet {

  static object s, d;
  int singlethreaded = 0;
#if constant(thread_create)
  static object lock;
#endif

  void destroy()
  {
    if(s) {
      d(s);
      s = 0;
    }
  }

  void service(object req, object|void res)
  {
    if(!res) {
      res = response(req->my_fd);
      req = request(0, req);
    }
#if constant(thread_create)
    if(singlethreaded) {
      object key = lock->lock();
      servlet_service(s, req, res);
      key = 0;
    } else
#endif
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

  void init(object cfgctx, mapping(string:string)|void params)
  {
    if(params)
      cfgctx = config(cfgctx, params);
    servlet_init(s, cfgctx->cfg);
    check_exception();
  }

  void create(string|object name, string|object|void dir)
  {
    if(stringp(name)) {
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
#if constant(thread_create)
      lock = Thread.Mutex();
#endif
      singlethreaded = 1;
    }
    d = servlet_destroy;
  }

};

class loader {

  static object cl;

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

  void create(string codedir)
  {
    cl = classloader2_class->alloc();
    check_exception();
    cl_init->call_nonvirtual(cl, codedir);
    check_exception();
  }

};

class config {

  object cfg;

  void create(object context, mapping(string:string)|void params)
  {
    cfg = config_class->alloc();
    check_exception();
    cfg_init(cfg, context->ctx);
    check_exception();
    if(params) {
      object dic = dic_field->get(cfg);
      foreach(indices(params), string key)
	dic_put(dic, key, params[key]);
    }
  }

};

static int context_id = 1;
static mapping(int:object) contexts = ([]);
static mapping(object:object) context_for_conf = ([]);

static object ctx_object(object ctx)
{
  return contexts[context_id_field->get(ctx)];
}

class context {

  object ctx, conf;
  static int id;

  void create(object|void c)
  {
    id = context_id++;
    conf = c;
    ctx = context_class->alloc();
    check_exception();
    context_init(ctx, id);
    check_exception();
    contexts[id] = this_object();
    if(conf) {
      if(context_for_conf[conf])
	destruct(context_for_conf[conf]);
      context_for_conf[conf] = this_object();
    }
  }

  void destroy()
  {
    m_delete(contexts, id);
    if(conf)
      m_delete(context_for_conf, conf);
    ctx=0;
  }


  object get_servlet(string name)
  {
    return 0;
  }

  array(string) get_servlet_list()
  {
    return ({});
  }

  void log(string msg)
  {
    werror(msg+"\n");
  }

  string get_real_path(string path)
  {
    return 0;
  }

  string get_mime_type(string file)
  {
    return 0;
  }

  string get_server_info()
  {
    return roxen->version();
  }

  object get_attribute(string name)
  {
    return 0;
  }

};

object conf_context(object conf)
{
  return context_for_conf[conf]||context(conf);
}

object request(object context, mapping(string:string)|object id,
	       mapping(string:string|object)|void attrs,
	       mapping(string:string)|void headers, mixed ... rest)
{
  if(objectp(id)) {
    string tmp = id->conf->query("MyWorldLocation");
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
    }

    if(id->misc->path_info && strlen(id->misc->path_info)) {
      string t, t2, path_info;
      array(string) tmp;

      if((path_info = id->misc->path_info)[0] != '/')
	path_info = "/" + path_info;
    
      t = t2 = "";

      while(1) {
	t2 = roxen->real_file(path_info, id);
	if(t2) {
	  pathtrans = t2 + t;
	  break;
	}
	tmp = path_info/"/" - ({""});
	if(!sizeof(tmp))
	  break;
	path_info = "/" + (tmp[0..sizeof(tmp)-2]) * "/";
	t = tmp[-1] +"/" + t;
      }
    }

    return request(context||conf_context(id->conf), id->variables, attrs,
		   id->raw && MIME.parse_headers(id->raw)[0],
		   (zero_type(id->misc->len)? -1:id->misc->len),
		   id->misc["content-type"], id->prot,
		   lower_case((id->prot/"/")[0]), tmp,		   
		   (id->my_fd&&(int)((id->my_fd->query_address(1)||"0 0")/" ")[1]),
		   addr, (host != addr)&&host, id->data,
		   id->misc->mountpoint, id->misc->path_info, id->method,
		   id->auth && id->realauth && (id->realauth/":")[0],
		   uri, query, pathtrans);
  }
  object r = request_class->alloc();
  check_exception();
  request_init(r, context->ctx, @rest);
  check_exception();
  object pa = params_field->get(r);
  foreach(indices(id), string v)
    dic_put(pa, v, id[v]);
  if(attrs) {
    object at = attrs_field->get(r);
    foreach(indices(attrs), string a)
      dic_put(at, a, attrs[a]);
  }
  object hh = headers_field->get(r);
  if(headers)
    foreach(indices(headers), string h)
      dic_put(hh, h, headers[h]);
  else
    headers_field->put(r, 0);
  check_exception();
  return r;
}

static int stream_id = 0;
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

static object native_getServlet(object ctx, object name)
{
  return ctx_object(ctx)->get_servlet((string)name);
}

static array(string) native_getServletList(object ctx)
{
  return ctx_object(ctx)->get_servlet_list();
}

static void native_log(object ctx, object msg)
{
  ctx_object(ctx)->log((string)msg);
}

static string native_getRealPath(object ctx, object path)
{
  return ctx_object(ctx)->get_real_path((string)path);
}

static string native_getMimeType(object ctx, object file)
{
  return ctx_object(ctx)->get_mime_type((string)file);
}

static string native_getServerInfo(object ctx)
{
  return ctx_object(ctx)->get_server_info();
}

static object native_getAttribute(object ctx, object name)
{
  return ctx_object(ctx)->get_attribute((string)name);
}

static void native_forgetfd(object str)
{
  int id = stream_id_field->get(str);
  object f = streams[id];
  m_delete(streams, id);
  if(f)
    destruct(f);
}

static void native_close(object str)
{
  int id = stream_id_field->get(str);
  object f = streams[id];
  if(f) {
    m_delete(streams, id);
    f->close();
  }
}

static void native_writei(object str, int n)
{
  object f = streams[stream_id_field->get(str)];
  if(f)
    f->write(sprintf("%c", n));
}

static void native_writeba(object str, object b, int off, int len)
{
  object f = streams[stream_id_field->get(str)];
  if(f)
    f->write(sprintf("%@c", values(b[off..off+len-1])));
}

static string native_blockingIPToHost(object n)
{
  return roxen->blocking_ip_to_host((string)n);
}

void create()
{
  natives_bind1 = context_class->register_natives(({
    ({"getServlet", "(Ljava/lang/String;)Ljavax/servlet/Servlet;",
      native_getServlet}),
    ({"getServletList", "()[Ljava/lang/String;", native_getServletList}),
    ({"log", "(Ljava/lang/String;)V", native_log}),
    ({"getRealPath", "(Ljava/lang/String;)Ljava/lang/String;",
      native_getRealPath}),
    ({"getMimeType", "(Ljava/lang/String;)Ljava/lang/String;",
      native_getMimeType}),
    ({"getServerInfo", "()Ljava/lang/String;", native_getServerInfo}),
    ({"getAttribute", "(Ljava/lang/String;)Ljava/lang/Object;",
      native_getAttribute})}));

  natives_bind2 = stream_class->register_natives(({
    ({"close", "()V", native_close}),
    ({"write", "(I)V", native_writei}),
    ({"write", "([BII)V", native_writeba}),
    ({"forgetfd", "()V", native_forgetfd})}));

  natives_bind3 = request_class->register_natives(({
    ({"blockingIPToHost", "(Ljava/lang/String;)Ljava/lang/String;",
      native_blockingIPToHost})}));
}

