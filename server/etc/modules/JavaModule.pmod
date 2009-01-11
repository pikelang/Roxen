#if constant(Java.machine)
protected object jvm = Java.machine;

private inherit "roxenlib";

#include <module.h>

#define FIND_CLASS(X) (jvm && (jvm->find_class(X)||(jvm->exception_describe(),jvm->exception_clear(),error("Failed to load class " X ".\n"),0)))
#define FIND_METHOD(C, M...) ((C) && (C)->get_method (M))
#define FIND_STATIC_METHOD(C, M...) ((C) && (C)->get_static_method (M))
#define FIND_FIELD(C, F...) ((C) && (C)->get_field (F))

/* Marshalling */
protected object object_class = FIND_CLASS("java/lang/Object");
protected object int_class = FIND_CLASS("java/lang/Integer");
protected object map_class = FIND_CLASS("java/util/HashMap");
protected object set_class = FIND_CLASS("java/util/HashSet");
protected object map_ifc = FIND_CLASS("java/util/Map");
protected object map_entry_ifc = FIND_CLASS("java/util/Map$Entry");
protected object set_ifc = FIND_CLASS("java/util/Set");
protected object int_value = FIND_METHOD (int_class, "intValue", "()I");
protected object int_init = FIND_METHOD (int_class, "<init>", "(I)V");
protected object map_init = FIND_METHOD (map_class, "<init>", "(I)V");
protected object map_put = FIND_METHOD (map_class, "put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
protected object set_init = FIND_METHOD (set_class, "<init>", "(I)V");
protected object set_add = FIND_METHOD (set_class, "add", "(Ljava/lang/Object;)Z");
protected object map_entry_set = FIND_METHOD (map_ifc, "entrySet", "()Ljava/util/Set;");
protected object set_to_array = FIND_METHOD (set_ifc, "toArray", "()[Ljava/lang/Object;");
protected object map_entry_getkey = FIND_METHOD (map_entry_ifc, "getKey", "()Ljava/lang/Object;");
protected object map_entry_getvalue = FIND_METHOD (map_entry_ifc, "getValue", "()Ljava/lang/Object;");

/* File I/O */
protected object reader_class = FIND_CLASS("java/io/Reader");
protected object string_class = FIND_CLASS("java/lang/String");
protected object _read = FIND_METHOD (reader_class, "read", "([C)I");
protected object string_init = FIND_METHOD (string_class, "<init>", "([CII)V");

/* Class loading */
protected object class_class = FIND_CLASS("java/lang/Class");
protected object classloader_class = FIND_CLASS("java/lang/ClassLoader");
protected object roxenclassloader_class = FIND_CLASS("com/roxen/roxen/RoxenClassLoader");
protected object file_class = FIND_CLASS("java/io/File");
protected object url_class = FIND_CLASS("java/net/URL");
protected object load_class = FIND_METHOD (roxenclassloader_class, "loadClass", "(Ljava/lang/String;)Ljava/lang/Class;");
protected object cl_init = FIND_METHOD (roxenclassloader_class, "<init>", "([Ljava/net/URL;)V");
protected object file_init = FIND_METHOD (file_class, "<init>", "(Ljava/lang/String;)V");
protected object file_tourl = FIND_METHOD (file_class, "toURL", "()Ljava/net/URL;");
protected object get_module_name = FIND_STATIC_METHOD (roxenclassloader_class, "getModuleClassName", "(Ljava/lang/String;)Ljava/lang/String;");
protected object add_jar = FIND_METHOD (roxenclassloader_class, "addJarFile", "(Ljava/lang/String;)V");
protected object new_instance = FIND_METHOD (class_class, "newInstance", "()Ljava/lang/Object;");
protected object filenotfound_class = FIND_CLASS("java/io/FileNotFoundException");
protected object ioexception_class = FIND_CLASS("java/io/IOException");

/* Error messages */
protected object throwable_class = FIND_CLASS("java/lang/Throwable");
protected object stringwriter_class = FIND_CLASS("java/io/StringWriter");
protected object printwriter_class = FIND_CLASS("java/io/PrintWriter");
protected object throwable_printstacktrace = FIND_METHOD (throwable_class, "printStackTrace", "(Ljava/io/PrintWriter;)V");
protected object throwable_get_message = FIND_METHOD (throwable_class, "getMessage", "()Ljava/lang/String;");
protected object stringwriter_init = FIND_METHOD (stringwriter_class, "<init>", "()V");
protected object printwriter_init = FIND_METHOD (printwriter_class, "<init>", "(Ljava/io/Writer;)V");
protected object printwriter_flush = FIND_METHOD (printwriter_class, "flush", "()V");

/* Module interface */
protected object reqid_class = FIND_CLASS("com/roxen/roxen/RoxenRequest");
protected object conf_class = FIND_CLASS("com/roxen/roxen/RoxenConfiguration");
protected object module_class = FIND_CLASS("com/roxen/roxen/Module");
protected object defvar_class = FIND_CLASS("com/roxen/roxen/Defvar");
protected object location_ifc = FIND_CLASS("com/roxen/roxen/LocationModule");
protected object parser_ifc = FIND_CLASS("com/roxen/roxen/ParserModule");
protected object fileext_ifc = FIND_CLASS("com/roxen/roxen/FileExtensionModule");
protected object provider_ifc = FIND_CLASS("com/roxen/roxen/ProviderModule");
protected object simpletagcaller_ifc = FIND_CLASS("com/roxen/roxen/SimpleTagCaller");
protected object lastresort_ifc = FIND_CLASS("com/roxen/roxen/LastResortModule");
protected object frame_class = FIND_CLASS("com/roxen/roxen/Frame");
protected object response_class = FIND_CLASS("com/roxen/roxen/RoxenResponse");
protected object response2_class = FIND_CLASS("com/roxen/roxen/RoxenStringResponse");
protected object response3_class = FIND_CLASS("com/roxen/roxen/RoxenFileResponse");
protected object response4_class = FIND_CLASS("com/roxen/roxen/RoxenRXMLResponse");
protected object rxml_class = FIND_CLASS("com/roxen/roxen/RXML");
protected object backtrace_class = FIND_CLASS("com/roxen/roxen/RXML$Backtrace");
protected object reqid_init = FIND_METHOD (reqid_class, "<init>", "(Lcom/roxen/roxen/RoxenConfiguration;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;I)V");
protected object conf_init = FIND_METHOD (conf_class, "<init>", "()V");
protected object frame_init = FIND_METHOD (frame_class, "<init>", "()V");
protected object _configuration = FIND_FIELD (module_class, "configuration", "Lcom/roxen/roxen/RoxenConfiguration;");
protected object query_type = FIND_METHOD (module_class, "queryType", "()I");
protected object query_unique = FIND_METHOD (module_class, "queryUnique", "()Z");
protected object _query_name = FIND_METHOD (module_class, "queryName", "()Ljava/lang/String;");
protected object query_desc = FIND_METHOD (module_class, "info", "()Ljava/lang/String;");
protected object _status = FIND_METHOD (module_class, "status", "()Ljava/lang/String;");
protected object _start = FIND_METHOD (module_class, "start", "()V");
protected object _stop = FIND_METHOD (module_class, "stop", "()V");
protected object _query_provides = FIND_METHOD (provider_ifc, "queryProvides", "()Ljava/lang/String;");
protected object _check_variable = FIND_METHOD (module_class, "checkVariable", "(Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/String;");
protected object _getdefvars = FIND_METHOD (module_class, "getDefvars", "()[Lcom/roxen/roxen/Defvar;");
protected object _find_internal = FIND_METHOD (module_class, "findInternal", "(Ljava/lang/String;Lcom/roxen/roxen/RoxenRequest;)Lcom/roxen/roxen/RoxenResponse;");
protected object _query_location = FIND_METHOD (location_ifc, "queryLocation", "()Ljava/lang/String;");
protected object _find_file = FIND_METHOD (location_ifc, "findFile", "(Ljava/lang/String;Lcom/roxen/roxen/RoxenRequest;)Lcom/roxen/roxen/RoxenResponse;");
protected object _find_dir = FIND_METHOD (location_ifc, "findDir", "(Ljava/lang/String;Lcom/roxen/roxen/RoxenRequest;)[Ljava/lang/String;");
protected object _real_file = FIND_METHOD (location_ifc, "realFile", "(Ljava/lang/String;Lcom/roxen/roxen/RoxenRequest;)Ljava/lang/String;");
protected object _stat_file = FIND_METHOD (location_ifc, "statFile", "(Ljava/lang/String;Lcom/roxen/roxen/RoxenRequest;)[I");
protected object _query_file_extensions = FIND_METHOD (fileext_ifc, "queryFileExtensions", "()[Ljava/lang/String;");
protected object _handle_file_extension = FIND_METHOD (fileext_ifc, "handleFileExtension", "(Ljava/io/File;Ljava/lang/String;Lcom/roxen/roxen/RoxenRequest;)Lcom/roxen/roxen/RoxenResponse;");
protected object _query_tag_callers = FIND_METHOD (parser_ifc, "querySimpleTagCallers", "()[Lcom/roxen/roxen/SimpleTagCaller;");
protected object _last_resort = FIND_METHOD (lastresort_ifc, "last_resort", "(Lcom/roxen/roxen/RoxenRequest;)Lcom/roxen/roxen/RoxenResponse;");
protected object simpletagcaller_query_name = FIND_METHOD (simpletagcaller_ifc, "queryTagName", "()Ljava/lang/String;");
protected object simpletagcaller_query_flags = FIND_METHOD (simpletagcaller_ifc, "queryTagFlags", "()I");
protected object _tag_called = FIND_METHOD (simpletagcaller_ifc, "tagCalled", "(Ljava/lang/String;Ljava/util/Map;Ljava/lang/String;Lcom/roxen/roxen/RoxenRequest;Lcom/roxen/roxen/Frame;)Ljava/lang/String;");
protected object dv_var = FIND_FIELD (defvar_class, "var", "Ljava/lang/String;");
protected object dv_name = FIND_FIELD (defvar_class, "name", "Ljava/lang/String;");
protected object dv_doc = FIND_FIELD (defvar_class, "doc", "Ljava/lang/String;");
protected object dv_value = FIND_FIELD (defvar_class, "value", "Ljava/lang/Object;");
protected object dv_type = FIND_FIELD (defvar_class, "type", "I");
protected object _errno = FIND_FIELD (response_class, "errno", "I");
protected object _len = FIND_FIELD (response_class, "len", "J");
protected object _type = FIND_FIELD (response_class, "type", "Ljava/lang/String;");
protected object _extra_heads = FIND_FIELD (response_class, "extraHeads", "Ljava/util/Map;");
protected object _data = FIND_FIELD (response2_class, "data", "Ljava/lang/String;");
protected object _file = FIND_FIELD (response3_class, "file", "Ljava/io/Reader;");
protected object bt_get_type = FIND_METHOD (backtrace_class, "getType", "()Ljava/lang/String;");

protected object natives_bind1, natives_bind2, natives_bind3,
  natives_bind4, natives_bind5;

protected mapping(object:object) jotomod = set_weak_flag( ([]), 1 );
protected mapping(object:object) jotoconf = set_weak_flag( ([]), 1 );
protected mapping(object:object) conftojo = set_weak_flag( ([]), 1 );
protected mapping(object:object) jotoid = set_weak_flag( ([]), 1 );

#if constant(thread_create)
#define LOCK() object _key=mutex->lock()
#define UNLOCK() destruct(_key)
protected object mutex=Thread.Mutex();
#else
#define LOCK() 0
#define UNLOCK() 0
#endif


protected void check_exception(object|void e)
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
  private object cl;
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
    cl = roxenclassloader_class->alloc();
    check_exception();
    cl_init->call_nonvirtual(cl, urls);
    check_exception();
  }
}

protected string stringify(object o)
{
  return o && (string)o;
}

protected mixed objify(mixed v)
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

protected mixed valify(mixed o)
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

protected object make_module(RoxenModule m)
{
  // Should perhaps handle Pike modules as well?
  return functionp(m->_java_object) && m->_java_object();
}

class ReaderFile
{
  private object _reader;

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
    protected object caller;

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

  protected object modobj, confobj;
  protected int modtype;
  protected string modname, moddesc;
  protected int modunique;

  object _java_object() { return modobj; }

  protected object make_conf(object conf)
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

  protected object make_reqid(RequestID id)
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

  protected object make_frame(RXML.Frame frame)
  {
    object f = frame_class->alloc();
    frame_init->call_nonvirtual(f);
    check_exception();
    return f;
  }

  protected mapping make_response(object r, RequestID id)
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

  protected void load(string filename)
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
      error("class does not implement com.roxen.roxen.Module\n");
    else
      jotomod[modobj] = this_object();
  }

  protected array(array) getdefvars()
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

  protected void init(object conf)
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

protected mixed native_query(object mod, object var)
{
  mod = jotomod[mod];
  return mod && objify(mod->query((string)var));
}

protected void native_set(object mod, object var, object val)
{
  if(mod = jotomod[mod])
    mod->set((string)var, valify(val));
}

protected object native_queryconf(object conf, object var)
{
  conf = jotoconf[conf];
  return conf && conf->query((string)var);
}

protected object native_queryconfinternal(object conf, object mod)
{
  conf = jotoconf[conf];
  return conf && conf->query_internal_location(mod && jotomod[mod]);
}

protected string native_do_output_tag(object args, object var_arr,
				   object contents, object id)
{
  return do_output_tag(valify(args), valify(var_arr),
		       contents && (string)contents, jotoid[id]);
}

protected string native_parse_rxml(object what, object id)
{
  return parse_rxml( what && (string)what, jotoid[id] );
}

protected object native_get_variables(object id)
{
  id = jotoid[id];
  return id && objify((mapping)id->variables);
}

protected object native_get_request_headers(object id)
{
  id = jotoid[id];
  return id && objify(id->request_headers);
}

protected object native_get_cookies(object id)
{
  id = jotoid[id];
  return id && objify(id->cookies);
}

protected object native_get_supports(object id)
{
  id = jotoid[id];
  return id && objify(id->supports);
}

protected object native_get_pragma(object id)
{
  id = jotoid[id];
  return id && objify(id->pragma);
}

protected object native_get_prestate(object id)
{
  id = jotoid[id];
  return id && objify(id->prestate);
}

protected void native_cache(object id, int n)
{
  id = jotoid[id];
  CACHE(n);
}

protected string native_real_file(object conf, object filename, object id)
{
  conf = jotoconf[conf];
  return filename && conf && conf->real_file((string)filename, jotoid[id]);
}

protected string native_try_get_file(object conf, object filename, object id)
{
  conf = jotoconf[conf];
  return filename && conf && conf->try_get_file((string)filename, jotoid[id]);
}

protected string native_type_from_filename(object conf, object filename)
{
  conf = jotoconf[conf];
  return filename && conf && conf->type_from_filename((string)filename);
}

protected object native_get_providers(object conf, object provides)
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

protected object native_get_var(object var, object scope)
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

protected object native_set_var(object var, object val, object scope)
{
  RXML.set_var((string)var, valify(val), scope&&(string)scope);
  return val;
}

protected object native_delete_var(object var, object scope)
{
  RXML.delete_var((string)var, scope&&(string)scope);
}

protected object native_user_get_var(object var, object scope)
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

protected object native_user_set_var(object var, object val, object scope)
{
  RXML.user_set_var((string)var, valify(val), scope&&(string)scope);
  return val;
}

protected object native_user_delete_var(object var, object scope)
{
  RXML.user_delete_var((string)var, scope&&(string)scope);
}

protected void native_tag_debug(object msg)
{
  RXML.tag_debug((string)msg);
}

void create()
{
  if (!jvm) return;

  if (!module_class->register_natives)
    error ("No support for native methods in the Java module.\n");

  natives_bind1 = module_class->register_natives(({
    ({"query", "(Ljava/lang/String;)Ljava/lang/Object;", native_query}),
    ({"set", "(Ljava/lang/String;Ljava/lang/Object;)V", native_set}),
  }));
  natives_bind2 = conf_class->register_natives(({
    ({"query", "(Ljava/lang/String;)Ljava/lang/Object;", native_queryconf}),
    ({"queryInternalLocation", "(Lcom/roxen/roxen/Module;)Ljava/lang/String;", native_queryconfinternal}),
    ({"getRealPath", "(Ljava/lang/String;Lcom/roxen/roxen/RoxenRequest;)Ljava/lang/String;", native_real_file}),
    ({"getFileContents", "(Ljava/lang/String;Lcom/roxen/roxen/RoxenRequest;)Ljava/lang/String;", native_try_get_file}),
    ({"getMimeType", "(Ljava/lang/String;)Ljava/lang/String;", native_type_from_filename}),
    ({"getProviders", "(Ljava/lang/String;)[Lcom/roxen/roxen/Module;", native_get_providers}),
  }));
  natives_bind3 = FIND_CLASS("com/roxen/roxen/RoxenLib")->register_natives(({
    ({"doOutputTag", "(Ljava/util/Map;[Ljava/util/Map;Ljava/lang/String;Lcom/roxen/roxen/RoxenRequest;)Ljava/lang/String;", native_do_output_tag}),
    ({"parseRXML", "(Ljava/lang/String;Lcom/roxen/roxen/RoxenRequest;)Ljava/lang/String;", native_parse_rxml}),
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
#endif
