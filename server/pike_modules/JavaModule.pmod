static constant jvm = Java.machine;

static private inherit "roxenlib";

#include <module.h>

#define FINDCLASS(X) (jvm->find_class(X)||(jvm->exception_describe(),jvm->exception_clear(),error("Failed to load class " X ".\n"),0))

/* Marshalling */
static object object_class = FINDCLASS("java/lang/Object");
static object int_class = FINDCLASS("java/lang/Integer");
static object map_class = FINDCLASS("java/util/HashMap");
static object set_class = FINDCLASS("java/util/HashSet");
static object map_ifc = FINDCLASS("java/util/Map");
static object map_entry_ifc = FINDCLASS("java/util/Map$Entry");
static object set_ifc = FINDCLASS("java/util/Set");
static object int_value = int_class->get_method("intValue", "()I");
static object int_init = int_class->get_method("<init>", "(I)V");
static object map_init = map_class->get_method("<init>", "(I)V");
static object map_put = map_class->get_method("put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
static object set_init = set_class->get_method("<init>", "(I)V");
static object set_add = set_class->get_method("add", "(Ljava/lang/Object;)Z");
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
static object chilimoonclassloader_class = FINDCLASS("com/chilimoon/chilimoon/ChiliMoonClassLoader");
static object file_class = FINDCLASS("java/io/File");
static object url_class = FINDCLASS("java/net/URL");
static object load_class = chilimoonclassloader_class->get_method("loadClass", "(Ljava/lang/String;)Ljava/lang/Class;");
static object cl_init = chilimoonclassloader_class->get_method("<init>", "([Ljava/net/URL;)V");
static object file_init = file_class->get_method("<init>", "(Ljava/lang/String;)V");
static object file_tourl = file_class->get_method("toURL", "()Ljava/net/URL;");
static object get_module_name = chilimoonclassloader_class->get_static_method("getModuleClassName", "(Ljava/lang/String;)Ljava/lang/String;");
static object add_jar = chilimoonclassloader_class->get_method("addJarFile", "(Ljava/lang/String;)V");
static object new_instance = class_class->get_method("newInstance", "()Ljava/lang/Object;");
static object filenotfound_class = FINDCLASS("java/io/FileNotFoundException");
static object ioexception_class = FINDCLASS("java/io/IOException");

/* Error messages */
static object throwable_class = FINDCLASS("java/lang/Throwable");
static object stringwriter_class = FINDCLASS("java/io/StringWriter");
static object printwriter_class = FINDCLASS("java/io/PrintWriter");
static object throwable_printstacktrace = throwable_class->get_method("printStackTrace", "(Ljava/io/PrintWriter;)V");
static object throwable_get_message = throwable_class->get_method("getMessage", "()Ljava/lang/String;");
static object stringwriter_init = stringwriter_class->get_method("<init>", "()V");
static object printwriter_init = printwriter_class->get_method("<init>", "(Ljava/io/Writer;)V");
static object printwriter_flush = printwriter_class->get_method("flush", "()V");

/* Module interface */
static object reqid_class = FINDCLASS("com/chilimoon/chilimoon/ChiliMoonRequest");
static object conf_class = FINDCLASS("com/chilimoon/chilimoon/ChiliMoonConfiguration");
static object module_class = FINDCLASS("com/chilimoon/chilimoon/Module");
static object defvar_class = FINDCLASS("com/chilimoon/chilimoon/Defvar");
static object location_ifc = FINDCLASS("com/chilimoon/chilimoon/LocationModule");
static object parser_ifc = FINDCLASS("com/chilimoon/chilimoon/ParserModule");
static object fileext_ifc = FINDCLASS("com/chilimoon/chilimoon/FileExtensionModule");
static object provider_ifc = FINDCLASS("com/chilimoon/chilimoon/ProviderModule");
static object simpletagcaller_ifc = FINDCLASS("com/chilimoon/chilimoon/SimpleTagCaller");
static object lastresort_ifc = FINDCLASS("com/chilimoon/chilimoon/LastResortModule");
static object frame_class = FINDCLASS("com/chilimoon/chilimoon/Frame");
static object response_class = FINDCLASS("com/chilimoon/chilimoon/ChiliMoonResponse");
static object response2_class = FINDCLASS("com/chilimoon/chilimoon/ChiliMoonStringResponse");
static object response3_class = FINDCLASS("com/chilimoon/chilimoon/ChiliMoonFileResponse");
static object response4_class = FINDCLASS("com/chilimoon/chilimoon/ChiliMoonRXMLResponse");
static object rxml_class = FINDCLASS("com/chilimoon/chilimoon/RXML");
static object backtrace_class = FINDCLASS("com/chilimoon/chilimoon/RXML$Backtrace");
static object reqid_init = reqid_class->get_method("<init>", "(Lcom/chilimoon/chilimoon/ChiliMoonConfiguration;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;I)V");
static object conf_init = conf_class->get_method("<init>", "()V");
static object frame_init = frame_class->get_method("<init>", "()V");
static object _configuration = module_class->get_field("configuration", "Lcom/chilimoon/chilimoon/ChiliMoonConfiguration;");
static object query_type = module_class->get_method("queryType", "()I");
static object query_unique = module_class->get_method("queryUnique", "()Z");
static object _query_name = module_class->get_method("queryName", "()Ljava/lang/String;");
static object query_desc = module_class->get_method("info", "()Ljava/lang/String;");
static object _status = module_class->get_method("status", "()Ljava/lang/String;");
static object _start = module_class->get_method("start", "()V");
static object _stop = module_class->get_method("stop", "()V");
static object _query_provides = provider_ifc->get_method("queryProvides", "()Ljava/lang/String;");
static object _check_variable = module_class->get_method("checkVariable", "(Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/String;");
static object _getdefvars = module_class->get_method("getDefvars", "()[Lcom/chilimoon/chilimoon/Defvar;");
static object _find_internal = module_class->get_method("findInternal", "(Ljava/lang/String;Lcom/chilimoon/chilimoon/ChiliMoonRequest;)Lcom/chilimoon/chilimoon/ChiliMoonResponse;");
static object _query_location = location_ifc->get_method("queryLocation", "()Ljava/lang/String;");
static object _find_file = location_ifc->get_method("findFile", "(Ljava/lang/String;Lcom/chilimoon/chilimoon/ChiliMoonRequest;)Lcom/chilimoon/chilimoon/ChiliMoonResponse;");
static object _find_dir = location_ifc->get_method("findDir", "(Ljava/lang/String;Lcom/chilimoon/chilimoon/ChiliMoonRequest;)[Ljava/lang/String;");
static object _real_file = location_ifc->get_method("realFile", "(Ljava/lang/String;Lcom/chilimoon/chilimoon/ChiliMoonRequest;)Ljava/lang/String;");
static object _stat_file = location_ifc->get_method("statFile", "(Ljava/lang/String;Lcom/chilimoon/chilimoon/ChiliMoonRequest;)[I");
static object _query_file_extensions = fileext_ifc->get_method("queryFileExtensions", "()[Ljava/lang/String;");
static object _handle_file_extension = fileext_ifc->get_method("handleFileExtension", "(Ljava/io/File;Ljava/lang/String;Lcom/chilimoon/chilimoon/ChiliMoonRequest;)Lcom/chilimoon/chilimoon/ChiliMoonResponse;");
static object _query_tag_callers = parser_ifc->get_method("querySimpleTagCallers", "()[Lcom/chilimoon/chilimoon/SimpleTagCaller;");
static object _last_resort = lastresort_ifc->get_method("last_resort", "(Lcom/chilimoon/chilimoon/ChiliMoonRequest;)Lcom/chilimoon/chilimoon/ChiliMoonResponse;");
static object simpletagcaller_query_name = simpletagcaller_ifc->get_method("queryTagName", "()Ljava/lang/String;");
static object simpletagcaller_query_flags = simpletagcaller_ifc->get_method("queryTagFlags", "()I");
static object _tag_called = simpletagcaller_ifc->get_method("tagCalled", "(Ljava/lang/String;Ljava/util/Map;Ljava/lang/String;Lcom/chilimoon/chilimoon/ChiliMoonRequest;Lcom/chilimoon/chilimoon/Frame;)Ljava/lang/String;");
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
static object bt_get_type = backtrace_class->get_method("getType", "()Ljava/lang/String;");

static object natives_bind1, natives_bind2, natives_bind3,
  natives_bind4, natives_bind5;

static mapping(object:object) jotomod = set_weak_flag( ([]), 1 );
static mapping(object:object) jotoconf = set_weak_flag( ([]), 1 );
static mapping(object:object) conftojo = set_weak_flag( ([]), 1 );
static mapping(object:object) jotoid = set_weak_flag( ([]), 1 );

#if constant(thread_create)
#define LOCK() object _key=mutex->lock()
#define UNLOCK() destruct(_key)
static object mutex=Thread.Mutex();
#else
#define LOCK() 0
#define UNLOCK() 0
#endif


static void check_exception(object|void e)
{
  if(!e) {
    if(!(e = jvm->exception_occurred()))
      return;
    jvm->exception_clear();
  }
  array bt = backtrace();
  if(e->is_instance_of(backtrace_class)) {
    object btto = bt_get_type(e);
    object msgo = throwable_get_message(e);
    throw(RXML.Backtrace(btto && (string)btto, msgo && (string)msgo,
			 0, bt[..sizeof(bt)-2]));
  } else {
    object sw = stringwriter_class->alloc();
    stringwriter_init->call_nonvirtual(sw);
    object pw = printwriter_class->alloc();
    printwriter_init->call_nonvirtual(pw, sw);
    throwable_printstacktrace(e, pw);
    printwriter_flush(pw);
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
  
  void add_to_classpath(string file)
  {
    add_jar(cl, file);
    check_exception();    
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
    cl = chilimoonclassloader_class->alloc();
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
  else if(stringp(v))
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
  } else if(mappingp(v)) {
    object m = map_class->alloc();
    map_init->call_nonvirtual(m, sizeof(v));
    check_exception();
    foreach(indices(v), mixed key)
      map_put(m, objify(key), objify(v[key]));
    check_exception();
    return m;
  } else if(multisetp(v)) {
    object s = set_class->alloc();
    set_init->call_nonvirtual(s, sizeof(v));
    check_exception();
    foreach(indices(v), mixed val)
      set_add(s, objify(val));
    check_exception();
    return s;
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

static object make_module(RoxenModule m)
{
  // Should perhaps handle Pike modules as well?
  return functionp(m->_java_object) && m->_java_object();
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

  Stat stat()
  {
    return 0;
  }

  void create(object r)
  {
    _reader = r;
  }
}

class ModuleWrapper
{
  int thread_safe=1;

  class JavaSimpleTag
  {
    static object caller;

    string call(string tag, mapping args, string contents, RequestID id,
		RXML.Frame frame)
    {
      object res = _tag_called(caller, tag, objify(args),
			       stringp(contents)&&contents, make_reqid(id),
			       make_frame(frame));
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

  object _java_object() { return modobj; }

  static object make_conf(object conf)
  {
    if(!conf)
      return 0;
    if(conftojo[conf])
      return conftojo[conf];

    LOCK();
    object ob = conftojo[conf];
    if(!ob) {
      ob = conf_class->alloc();
      conf_init->call_nonvirtual(ob);
      check_exception();
      jotoconf[ob] = conf;
      conftojo[conf] = ob;
    }
    UNLOCK();

    return ob;
  }

  static object make_reqid(RequestID id)
  {
    object r = reqid_class->alloc();
    reqid_init->call_nonvirtual(r, make_conf(id->conf), id->raw_url, id->prot,
				id->clientprot, id->method, id->realfile,
				id->virtfile, id->raw, id->query,
				id->not_query, id->remoteaddr, id->time);
    check_exception();
    jotoid[r] = id;
    return r;
  }

  static object make_frame(RXML.Frame frame)
  {
    object f = frame_class->alloc();
    frame_init->call_nonvirtual(f);
    check_exception();
    return f;
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

  string get_inherit_tree()
  {
    object c;
    array(string) tree = ({});
    for(c=modobj->get_object_class(); c; c=c->super_class())
      tree += ({ (string)c });
    string res = "";
    foreach(reverse(tree), string n)
      res = "<dl><dt>"+replace(n, " ", "&nbsp;")+"</dt><dd>"+res+"</dd></dl>";
    return res;
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
    object r = _check_variable(modobj, s, objify(value));
    check_exception();
    return r && (string)r;
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

  mapping query_simpletag_callers()
  {
    mapping res = ([ ]);
    object callers = _query_tag_callers(modobj);
    check_exception();
    if(callers)
      foreach(values(callers), object c)
	if(c) {
	  object name = simpletagcaller_query_name(c);
	  int flags = simpletagcaller_query_flags(c);
	  check_exception();
	  res[(string)name] = ({ flags, JavaSimpleTag(c)->call });
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
  mixed last_resort(RequestID id)
  {
    object r = _last_resort(modobj, make_reqid(id));
    check_exception();
    return make_response(r, id);
  }

  string extension( string from )
  {
    string ext;
    sscanf(reverse(from), "%[^.].", ext);
    return ext ? reverse(ext) : "";
  }

  static void load(string filename)
  {
    string path = combine_path(getcwd(), filename);
    array(string) dcomp = path/"/";
    string dir = dcomp[..sizeof(dcomp)-2]*"/";
    filename = dcomp[-1];
    object modcls;
    ClassLoader myLoader = ClassLoader(dir);
    string ext = extension(filename);
    switch (ext) {
      case "class":
        modcls = myLoader->load(filename-".class");
        check_exception();
        break;
      case "jar":
        // Get the module name from the JAR
        string modname = get_module_name(path);
        object e = jvm->exception_occurred();
        if (e) {
	  jvm->exception_clear();
          if (e->is_instance_of(filenotfound_class)) {
            error("Unable to find JAR file");
          } else if (e->is_instance_of(ioexception_class)) {
            error("Unable to read JAR file");
          } else {
            check_exception(e);
          }
        } else if (!modname) {
          error("Unable to find class name within JAR");
        } else {
          // Add the JAR to the class path and load the class
          myLoader->add_to_classpath(path);
          check_exception();
          modcls = myLoader->load(modname);
          check_exception();
        }
        break;
      default:
        error("Unknown extension: " + ext);
        break;
    }

    if(!modcls)
      return;
    modobj = new_instance(modcls);
    check_exception();
    if(!modobj->is_instance_of(module_class))
      error("class does not implement com.chilimoon.chilimoon.Module\n");
    else
      jotomod[modobj] = this;
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

static string native_parse_rxml(object what, object id)
{
  return parse_rxml( what && (string)what, jotoid[id] );
}

static object native_get_variables(object id)
{
  id = jotoid[id];
  return id && objify((mapping)id->variables);
}

static object native_get_request_headers(object id)
{
  id = jotoid[id];
  return id && objify(id->request_headers);
}

static object native_get_cookies(object id)
{
  id = jotoid[id];
  return id && objify(id->cookies);
}

static object native_get_supports(object id)
{
  id = jotoid[id];
  return id && objify(id->supports);
}

static object native_get_pragma(object id)
{
  id = jotoid[id];
  return id && objify(id->pragma);
}

static object native_get_prestate(object id)
{
  id = jotoid[id];
  return id && objify(id->prestate);
}

static void native_cache(object id, int n)
{
  id = jotoid[id];
  CACHE(n);
}

static string native_real_file(object conf, object filename, object id)
{
  conf = jotoconf[conf];
  return filename && conf && conf->real_file((string)filename, jotoid[id]);
}

static string native_try_get_file(object conf, object filename, object id)
{
  conf = jotoconf[conf];
  return filename && conf && conf->try_get_file((string)filename, jotoid[id]);
}

static string native_type_from_filename(object conf, object filename)
{
  conf = jotoconf[conf];
  return filename && conf && conf->type_from_filename((string)filename);
}

static object native_get_providers(object conf, object provides)
{
  array p;
  conf = jotoconf[conf];
  if(provides && conf && (p = conf->get_providers((string)provides))) {
    p = map(p, make_module)-({0});
    object a = module_class->new_array(sizeof(p), 0);
    check_exception();
    foreach(indices(p), int i)
      a[i] = p[i];
    check_exception();
    return a;
  } else
    return 0;
}

static object native_get_var(object var, object scope)
{
  mixed x;
  if(zero_type(x = RXML.get_var((string)var, scope&&(string)scope)))
    return 0;
  else if(intp(x)) {
    object z = int_class->alloc();
    int_init->call_nonvirtual(z, x);
    check_exception();
    return z;
  } else
    return objify(x);
}

static object native_set_var(object var, object val, object scope)
{
  RXML.set_var((string)var, valify(val), scope&&(string)scope);
  return val;
}

static object native_delete_var(object var, object scope)
{
  RXML.delete_var((string)var, scope&&(string)scope);
}

static object native_user_get_var(object var, object scope)
{
  mixed x;
  if(zero_type(x = RXML.user_get_var((string)var, scope&&(string)scope)))
    return 0;
  else if(intp(x)) {
    object z = int_class->alloc();
    int_init->call_nonvirtual(z, x);
    check_exception();
    return z;
  } else
    return objify(x);
}

static object native_user_set_var(object var, object val, object scope)
{
  RXML.user_set_var((string)var, valify(val), scope&&(string)scope);
  return val;
}

static object native_user_delete_var(object var, object scope)
{
  RXML.user_delete_var((string)var, scope&&(string)scope);
}

static void native_tag_debug(object msg)
{
  RXML.tag_debug((string)msg);
}

void create()
{
  natives_bind1 = module_class->register_natives(({
    ({"query", "(Ljava/lang/String;)Ljava/lang/Object;", native_query}),
    ({"set", "(Ljava/lang/String;Ljava/lang/Object;)V", native_set}),
  }));
  natives_bind2 = conf_class->register_natives(({
    ({"query", "(Ljava/lang/String;)Ljava/lang/Object;", native_queryconf}),
    ({"queryInternalLocation", "(Lcom/chilimoon/chilimoon/Module;)Ljava/lang/String;", native_queryconfinternal}),
    ({"getRealPath", "(Ljava/lang/String;Lcom/chilimoon/chilimoon/ChiliMoonRequest;)Ljava/lang/String;", native_real_file}),
    ({"getFileContents", "(Ljava/lang/String;Lcom/chilimoon/chilimoon/ChiliMoonRequest;)Ljava/lang/String;", native_try_get_file}),
    ({"getMimeType", "(Ljava/lang/String;)Ljava/lang/String;", native_type_from_filename}),
    ({"getProviders", "(Ljava/lang/String;)[Lcom/chilimoon/chilimoon/Module;", native_get_providers}),
  }));
  natives_bind3 = FINDCLASS("com/chilimoon/chilimoon/ChiliMoonLib")->register_natives(({
    ({"parseRXML", "(Ljava/lang/String;Lcom/chilimoon/chilimoon/ChiliMoonRequest;)Ljava/lang/String;", native_parse_rxml}),
  }));
  natives_bind4 = reqid_class->register_natives(({
    ({"getVariables", "()Ljava/util/Map;", native_get_variables}),
    ({"getRequestHeaders", "()Ljava/util/Map;", native_get_request_headers}),
    ({"getCookies", "()Ljava/util/Map;", native_get_cookies}),
    ({"getSupports", "()Ljava/util/Set;", native_get_supports}),
    ({"getPragma", "()Ljava/util/Set;", native_get_pragma}),
    ({"getPrestate", "()Ljava/util/Set;", native_get_prestate}),
    ({"cache", "(I)V", native_cache}),
  }));
  natives_bind5 = rxml_class->register_natives(({
    ({"getVar", "(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/Object;", native_get_var}),
    ({"setVar", "(Ljava/lang/String;Ljava/lang/Object;Ljava/lang/String;)Ljava/lang/Object;", native_set_var}),
    ({"deleteVar", "(Ljava/lang/String;Ljava/lang/String;)V", native_delete_var}),
    ({"userGetVar", "(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/Object;", native_user_get_var}),
    ({"userSetVar", "(Ljava/lang/String;Ljava/lang/Object;Ljava/lang/String;)Ljava/lang/Object;", native_user_set_var}),
    ({"userDeleteVar", "(Ljava/lang/String;Ljava/lang/String;)V", native_user_delete_var}),
    ({"tagDebug", "(Ljava/lang/String;)V", native_tag_debug}),
  }));
}
