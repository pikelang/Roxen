
static constant jvm = Java.machine;

static private inherit "roxenlib";

#define FINDCLASS(X) (jvm->find_class(X)||(jvm->exception_describe(),jvm->exception_clear(),error("Failed to load class " X ".\n"),0))

/* Marshalling */
static object object_class = FINDCLASS("java/lang/Object");
static object int_class = FINDCLASS("java/lang/Integer");
static object map_class = FINDCLASS("java/util/HashMap");
static object map_ifc = FINDCLASS("java/util/Map");
static object map_entry_ifc = FINDCLASS("java/util/Map$Entry");
static object set_ifc = FINDCLASS("java/util/Set");
static object int_value = int_class->get_method("intValue", "()I");
static object int_init = int_class->get_method("<init>", "(I)V");
static object map_init = map_class->get_method("<init>", "(I)V");
static object map_put = map_class->get_method("put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
static object map_entry_set = map_ifc->get_method("entrySet", "()Ljava/util/Set;");
static object set_to_array = set_ifc->get_method("toArray", "()[Ljava/lang/Object;");
static object map_entry_getkey = map_entry_ifc->get_method("getKey", "()Ljava/lang/Object;");
static object map_entry_getvalue = map_entry_ifc->get_method("getValue", "()Ljava/lang/Object;");

/* File I/O */
static object reader_class = FINDCLASS("java/io/Reader");
static object string_class = FINDCLASS("java/lang/String");
static object _read = reader_class->get_method("read", "([C)I");
static object string_init = string_class->get_method("<init>", "([CII)V");

/* Class loading */
static object class_class = FINDCLASS("java/lang/Class");
static object classloader_class = FINDCLASS("java/lang/ClassLoader");
static object classloader2_class = FINDCLASS("java/net/URLClassLoader");
static object file_class = FINDCLASS("java/io/File");
static object url_class = FINDCLASS("java/net/URL");
static object load_class = classloader_class->get_method("loadClass", "(Ljava/lang/String;)Ljava/lang/Class;");
static object cl_init = classloader2_class->get_method("<init>", "([Ljava/net/URL;)V");
static object file_init = file_class->get_method("<init>", "(Ljava/lang/String;)V");
static object file_tourl = file_class->get_method("toURL", "()Ljava/net/URL;");
static object new_instance = class_class->get_method("newInstance",
						     "()Ljava/lang/Object;");

/* Error messages */
static object throwable_class = FINDCLASS("java/lang/Throwable");
static object stringwriter_class = FINDCLASS("java/io/StringWriter");
static object printwriter_class = FINDCLASS("java/io/PrintWriter");
static object throwable_printstacktrace = throwable_class->get_method("printStackTrace", "(Ljava/io/PrintWriter;)V");
static object stringwriter_init = stringwriter_class->get_method("<init>", "()V");
static object printwriter_init = printwriter_class->get_method("<init>", "(Ljava/io/Writer;)V");
static object printwriter_flush = printwriter_class->get_method("flush", "()V");

/* Module interface */
static object reqid_class = FINDCLASS("se/idonex/roxen/RoxenRequest");
static object conf_class = FINDCLASS("se/idonex/roxen/RoxenConfiguration");
static object module_class = FINDCLASS("se/idonex/roxen/Module");
static object defvar_class = FINDCLASS("se/idonex/roxen/Defvar");
static object location_ifc = FINDCLASS("se/idonex/roxen/LocationModule");
static object parser_ifc = FINDCLASS("se/idonex/roxen/ParserModule");
static object fileext_ifc = FINDCLASS("se/idonex/roxen/FileExtensionModule");
static object tagcaller_ifc = FINDCLASS("se/idonex/roxen/TagCaller");
static object containercaller_ifc = FINDCLASS("se/idonex/roxen/ContainerCaller");
static object response_class = FINDCLASS("se/idonex/roxen/RoxenResponse");
static object response2_class = FINDCLASS("se/idonex/roxen/RoxenStringResponse");
static object response3_class = FINDCLASS("se/idonex/roxen/RoxenFileResponse");
static object response4_class = FINDCLASS("se/idonex/roxen/RoxenRXMLResponse");
static object reqid_init = reqid_class->get_method("<init>", "(Lse/idonex/roxen/RoxenConfiguration;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V");
static object conf_init = conf_class->get_method("<init>", "()V");
static object _configuration = module_class->get_field("configuration", "Lse/idonex/roxen/RoxenConfiguration;");
static object query_type = module_class->get_method("queryType", "()I");
static object query_unique = module_class->get_method("queryUnique", "()Z");
static object _query_name = module_class->get_method("queryName", "()Ljava/lang/String;");
static object query_desc = module_class->get_method("info", "()Ljava/lang/String;");
static object _status = module_class->get_method("status", "()Ljava/lang/String;");
static object _start = module_class->get_method("start", "()V");
static object _stop = module_class->get_method("stop", "()V");
static object _query_provides = module_class->get_method("queryProvides", "()Ljava/lang/String;");
static object _check_variable = module_class->get_method("checkVariable", "(Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/String;");
static object _getdefvars = module_class->get_method("getDefvars", "()[Lse/idonex/roxen/Defvar;");
static object _find_internal = module_class->get_method("findInternal", "(Ljava/lang/String;Lse/idonex/roxen/RoxenRequest;)Lse/idonex/roxen/RoxenResponse;");
static object _query_location = location_ifc->get_method("queryLocation", "()Ljava/lang/String;");
static object _find_file = location_ifc->get_method("findFile", "(Ljava/lang/String;Lse/idonex/roxen/RoxenRequest;)Lse/idonex/roxen/RoxenResponse;");
static object _find_dir = location_ifc->get_method("findDir", "(Ljava/lang/String;Lse/idonex/roxen/RoxenRequest;)[Ljava/lang/String;");
static object _real_file = location_ifc->get_method("realFile", "(Ljava/lang/String;Lse/idonex/roxen/RoxenRequest;)Ljava/lang/String;");
static object _stat_file = location_ifc->get_method("statFile", "(Ljava/lang/String;Lse/idonex/roxen/RoxenRequest;)[I");
static object _query_file_extensions = fileext_ifc->get_method("queryFileExtensions", "()[Ljava/lang/String;");
static object _handle_file_extension = fileext_ifc->get_method("handleFileExtension", "(Ljava/io/File;Ljava/lang/String;Lse/idonex/roxen/RoxenRequest;)Lse/idonex/roxen/RoxenResponse;");
static object _query_tag_callers = parser_ifc->get_method("queryTagCallers", "()[Lse/idonex/roxen/TagCaller;");
static object _query_container_callers = parser_ifc->get_method("queryContainerCallers", "()[Lse/idonex/roxen/ContainerCaller;");
static object tagcaller_query_name = tagcaller_ifc->get_method("queryName", "()Ljava/lang/String;");
static object _tag_called = tagcaller_ifc->get_method("tagCalled", "(Ljava/lang/String;Ljava/util/Map;Lse/idonex/roxen/RoxenRequest;)Ljava/lang/String;");
static object containercaller_query_name = containercaller_ifc->get_method("queryName", "()Ljava/lang/String;");
static object _container_called = containercaller_ifc->get_method("containerCalled", "(Ljava/lang/String;Ljava/util/Map;Ljava/lang/String;Lse/idonex/roxen/RoxenRequest;)Ljava/lang/String;");
static object dv_var = defvar_class->get_field("var", "Ljava/lang/String;");
static object dv_name = defvar_class->get_field("name", "Ljava/lang/String;");
static object dv_doc = defvar_class->get_field("doc", "Ljava/lang/String;");
static object dv_value = defvar_class->get_field("value", "Ljava/lang/Object;");
static object dv_type = defvar_class->get_field("type", "I");
static object _errno = response_class->get_field("errno", "I");
static object _len = response_class->get_field("len", "J");
static object _type = response_class->get_field("type", "Ljava/lang/String;");
static object _extra_heads = response_class->get_field("extraHeads", "Ljava/util/Map;");
static object _data = response2_class->get_field("data", "Ljava/lang/String;");
static object _file = response3_class->get_field("file", "Ljava/io/Reader;");

static object natives_bind1, natives_bind2, natives_bind3;

static mapping(object:object) jotomod = set_weak_flag( ([]), 1 );
static mapping(object:object) jotoconf = set_weak_flag( ([]), 1 );
static mapping(object:object) conftojo = set_weak_flag( ([]), 1 );
static mapping(object:object) jotoid = set_weak_flag( ([]), 1 );


static void check_exception()
{
  object e = jvm->exception_occurred();
  if(e) {
    object sw = stringwriter_class->alloc();
    stringwriter_init->call_nonvirtual(sw);
    object pw = printwriter_class->alloc();
    printwriter_init->call_nonvirtual(pw, sw);
    throwable_printstacktrace(e, pw);
    printwriter_flush(pw);
    jvm->exception_clear();
    array bt = backtrace();
    throw(({(string)sw, bt[..sizeof(bt)-2]}));
  }
}

class ClassLoader
{
  static private object cl;

  object load(string name)
  {
    object c = load_class(cl, name);
    check_exception();
    return c;
  }

  void create(string dir)
  {
    object f = file_class->alloc();
    check_exception();
    file_init->call_nonvirtual(f, dir);
    check_exception();
    object url = file_tourl(f);
    check_exception();
    object urls = url_class->new_array(1);
    check_exception();
    urls[0] = url;
    check_exception();
    cl = classloader2_class->alloc();
    check_exception();
    cl_init->call_nonvirtual(cl, urls);
    check_exception();
  }
}

static string stringify(object o)
{
  return o && (string)o;
}

static mixed objify(mixed v)
{
  if(!v)
    return v;
  else if(intp(v)) {
    object z = int_class->alloc();
    int_init->call_nonvirtual(z, v);
    check_exception();
    return z;
  } else if(arrayp(v)) {
    object a = object_class->new_array(sizeof(v), 0);
    check_exception();
    foreach(indices(v), int i)
      a[i] = v[i];
    check_exception();
    return a;
  } else
    return (string)v;
}

static mixed valify(mixed o)
{
  if(!objectp(o))
    return o;
  else if(o->_values)
    return map(values(o), valify);
  else if(o->is_instance_of(int_class))
    return int_value(o);
  else if(o->is_instance_of(map_ifc)) {
    mapping r = ([]);
    foreach(values(set_to_array(map_entry_set(o))||({})), object e)
      r[valify(map_entry_getkey(e))] = valify(map_entry_getvalue(e));
    check_exception();
    return r;
  } else
    return (string)o;
}

class ReaderFile
{
  static private object _reader;

  string read(int|void n)
  {
    if(zero_type(n))
      n = 65536;
    if(n<=0)
      return "";
    object a = jvm->new_char_array(n);
    check_exception();
    int r = _read(_reader, a);
    check_exception();
    if(r<=0)
      return "";
    object s = string_class->alloc();
    string_init->call_nonvirtual(s, a, 0, r);
    check_exception();
    return (string)s;
  }

  void create(object r)
  {
    _reader = r;
  }
}

class ModuleWrapper
{
  class JavaTag
  {
    static object caller;

    string call(string tag, mapping args, RequestID id)
    {
      object res = _tag_called(caller, tag, make_args(args), make_reqid(id));
      check_exception();
      return res && (string)res;
    }
    
    void create(object o)
    {
      caller = o;
    }
  }

  class JavaContainer
  {
    static object caller;

    string call(string tag, mapping args, string contents, RequestID id)
    {
      object res = _container_called(caller, tag, make_args(args),
				     contents, make_reqid(id));
      check_exception();
      return res && (string)res;
    }
    
    void create(object o)
    {
      caller = o;
    }
  }


  static object modobj, confobj;
  static int modtype;
  static string modname, moddesc;
  static int modunique;

  static object make_conf(object conf)
  {
    if(!conf)
      return 0;
    if(conftojo[conf])
      return conftojo[conf];
    object ob = conf_class->alloc();
    conf_init->call_nonvirtual(ob);
    check_exception();
    jotoconf[ob] = conf;
    conftojo[conf] = ob;
    return ob;
  }

  static object make_reqid(RequestID id)
  {
    object r = reqid_class->alloc();
    reqid_init->call_nonvirtual(r, make_conf(id->conf), id->raw_url, id->prot,
				id->clientprot, id->method, id->realfile,
				id->virtfile, id->raw, id->query,
				id->not_query, id->remoteaddr);
    check_exception();
    jotoid[r] = id;
    return r;
  }

  static object make_args(mapping args)
  {
    object m = map_class->alloc();
    map_init->call_nonvirtual(m, sizeof(args));
    check_exception();
    foreach(indices(args), string key)
      map_put(m, key, args[key]);
    check_exception();
    return m;
  }

  static mapping make_response(object r, RequestID id)
  {
    if(!r)
      return 0;
    mapping rr = ([]);
    int n;
    object s;
    if((n = _errno->get(r)))
      rr->error = n;
    check_exception();
    if((s = _type->get(r)))
      rr->type = (string)s;
    check_exception();
    if((n = _len->get(r)))
      rr->len = n;
    check_exception();
    if((s = _extra_heads->get(r)))
      rr->extra_heads = valify(s);
    check_exception();
    if(r->is_instance_of(response2_class) &&
       (s = _data->get(r))) {
      rr->data = (string)s;
      if(r->is_instance_of(response4_class)) {
	rr->data = id->conf->parse_rxml(rr->data, id, 0);
	rr->stat = id->misc->defines[" _stat"];
	rr->error = id->misc->defines[" _error"] || rr->error;
	rr->rettext = id->misc->defines[" _rettext"];
	if(id->misc->defines[" _extra_heads"])
	  if(rr->extra_heads)
	    rr->extra_heads |= id->misc->defines[" _extra_heads"];	
	  else
	    rr->extra_heads = id->misc->defines[" _extra_heads"];	
	m_delete(rr, "len");
      }
    } else if(r->is_instance_of(response3_class) &&
	    (s = _file->get(r)))
      rr->file = ReaderFile(s);
    check_exception();
    return rr;
  }

  array register_module()
  {
    return ({ modtype, modname, moddesc, 0, modunique });
  }

  void start()
  {
    _start(modobj);
    check_exception();
  }

  void stop()
  {
    _stop(modobj);
    check_exception();
  }

  string query_name()
  {
    object s = _query_name(modobj);
    check_exception();
    return s && (string)s;
  }

  string info()
  {
    object s = query_desc(modobj);
    check_exception();
    return s && (string)s;
  }

  string status()
  {
    object s = _status(modobj);
    check_exception();
    return s && (string)s;
  }

  string query_provides()
  {
    object s = _query_provides(modobj);
    check_exception();
    return s && (string)s;
  }

  string check_variable(string s, mixed value)
  {
    object s = _check_variable(modobj, s, objify(value));
    check_exception();
    return s && (string)s;
  }

  string query_location()
  {
    object l = _query_location(modobj);
    check_exception();
    return l && (string)l;
  }

  array(string) query_file_extensions()
  {
    object l = _query_file_extensions(modobj);
    check_exception();
    return l && valify(l);
  }

  mapping query_tag_callers()
  {
    mapping res = ([ ]);
    object callers = _query_tag_callers(modobj);
    check_exception();
    if(callers)
      foreach(values(callers), object c)
	if(c) {
	  object name = tagcaller_query_name(c);
	  check_exception();
	  res[(string)name] = JavaTag(c)->call;
	}
    return res;
  }

  mapping query_container_callers()
  {
    mapping res = ([ ]);
    object callers = _query_container_callers(modobj);
    check_exception();
    if(callers)
      foreach(values(callers), object c)
	if(c) {
	  object name = containercaller_query_name(c);
	  check_exception();
	  res[(string)name] = JavaContainer(c)->call;
	}
    return res;
  }

  mixed find_file(string f, RequestID id)
  {
    object r = _find_file(modobj, f, make_reqid(id));
    check_exception();
    return make_response(r, id);
  }

  array(string) find_dir(string f, RequestID id)
  {
    object r = _find_dir(modobj, f, make_reqid(id));
    check_exception();
    return valify(r);
  }

  string real_file(string f, RequestID id)
  {
    object r = _real_file(modobj, f, make_reqid(id));
    check_exception();
    return r && (string)r;
  }

  string stat_file(string f, RequestID id)
  {
    object r = _stat_file(modobj, f, make_reqid(id));
    check_exception();
    return valify(r);
  }

  mixed handle_file_extension(object file, string ext, object id)
  {
    if(!id->realfile)
      return 0;
    object f = file_class->alloc();
    check_exception();
    file_init->call_nonvirtual(f, id->realfile);
    check_exception();
    object r = _handle_file_extension(modobj, f, ext, make_reqid(id));
    check_exception();
    return make_response(r, id);
  }

  mixed find_internal(string f, RequestID id)
  {
    object r = _find_internal(modobj, f, make_reqid(id));
    check_exception();
    return make_response(r, id);
  }

  static void load(string filename)
  {
    array(string) dcomp = filename/"/";
    string dir = dcomp[..sizeof(dcomp)-2]*"/";
    filename = dcomp[-1];
    object modcls = ClassLoader(dir)->load(filename-".class");
    if(!modcls)
      return;
    modobj = new_instance(modcls);
    check_exception();
    if(!modobj->is_instance_of(module_class))
      error("class does not implement se.idonex.roxen.Module\n");
    else
      jotomod[modobj] = this_object();
  }

  static array(array) getdefvars()
  {
    object a = _getdefvars(modobj);
    check_exception();
    return map(values(a), lambda(object dv) {
			    array v = allocate(5);
			    v[0] = stringify(dv_var->get(dv));
			    check_exception();
			    v[1] = valify(dv_value->get(dv));
			    check_exception();
			    v[2] = stringify(dv_name->get(dv));
			    check_exception();
			    v[3] = dv_type->get(dv);
			    check_exception();
			    v[4] = stringify(dv_doc->get(dv));
			    check_exception();
			    return v;
			  });
  }

  static void init(object conf)
  {
    if(conf) {
      _configuration->set(modobj, confobj = make_conf(conf));
     check_exception();
    }
    modtype = query_type(modobj);
    check_exception();
    modname = stringify(_query_name(modobj));
    check_exception();
    moddesc = stringify(query_desc(modobj));
    check_exception();
    modunique = query_unique(modobj);
    check_exception();
  }
}

static mixed native_query(object mod, object var)
{
  mod = jotomod[mod];
  return mod && objify(mod->query((string)var));
}

static void native_set(object mod, object var, object val)
{
  if(mod = jotomod[mod])
    mod->set((string)var, valify(val));
}

static object native_queryconf(object conf, object var)
{
  conf = jotoconf[conf];
  return conf && conf->query((string)var);
}

static object native_queryconfinternal(object conf, object mod)
{
  conf = jotoconf[conf];
  return conf && conf->query_internal_location(mod && jotomod[mod]);
}

static string native_do_output_tag(object args, object var_arr,
				   object contents, object id)
{
  return do_output_tag(valify(args), valify(var_arr),
		       contents && (string)contents, jotoid[id]);
}

static string native_parse_rxml(object what, object id)
{
  return parse_rxml( what && (string)what, jotoid[id] );
}

void create()
{
  natives_bind1 = module_class->register_natives(({
    ({"query", "(Ljava/lang/String;)Ljava/lang/Object;", native_query}),
    ({"set", "(Ljava/lang/String;Ljava/lang/Object;)V", native_set}),
  }));
  natives_bind2 = conf_class->register_natives(({
    ({"query", "(Ljava/lang/String;)Ljava/lang/Object;", native_queryconf}),
    ({"queryInternalLocation", "(Lse/idonex/roxen/Module;)Ljava/lang/String;", native_queryconfinternal}),
  }));
  natives_bind3 = FINDCLASS("se/idonex/roxen/RoxenLib")->register_natives(({
    ({"doOutputTag", "(Ljava/util/Map;[Ljava/util/Map;Ljava/lang/String;Lse/idonex/roxen/RoxenRequest;)Ljava/lang/String;", native_do_output_tag}),
    ({"parseRXML", "(Ljava/lang/String;Lse/idonex/roxen/RoxenRequest;)Ljava/lang/String;", native_parse_rxml}),
  }));
}
