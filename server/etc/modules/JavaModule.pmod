
static constant jvm = Java.machine;

#define FINDCLASS(X) (jvm->find_class(X)||(jvm->exception_describe(),jvm->exception_clear(),error("Failed to load class " X ".\n"),0))

/* Marshalling */
static object int_class = FINDCLASS("java/lang/Integer");
static object map_class = FINDCLASS("java/util/HashMap");
static object int_value = int_class->get_method("intValue", "()I");
static object map_init = map_class->get_method("<init>", "(I)V");
static object map_put = map_class->get_method("put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");

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
static object module_class = FINDCLASS("se/idonex/roxen/Module");
static object defvar_class = FINDCLASS("se/idonex/roxen/Defvar");
static object location_ifc = FINDCLASS("se/idonex/roxen/LocationModule");
static object parser_ifc = FINDCLASS("se/idonex/roxen/ParserModule");
static object tagcaller_ifc = FINDCLASS("se/idonex/roxen/TagCaller");
static object containercaller_ifc = FINDCLASS("se/idonex/roxen/ContainerCaller");
static object response_class = FINDCLASS("se/idonex/roxen/RoxenResponse");
static object response2_class = FINDCLASS("se/idonex/roxen/RoxenStringResponse");
static object query_type = module_class->get_method("queryType", "()I");
static object query_name = module_class->get_method("queryName", "()Ljava/lang/String;");
static object query_desc = module_class->get_method("queryDescription", "()Ljava/lang/String;");
static object _status = module_class->get_method("status", "()Ljava/lang/String;");
static object _getdefvars = module_class->get_method("getDefvars", "()[Lse/idonex/roxen/Defvar;");
static object _query_location = location_ifc->get_method("queryLocation", "()Ljava/lang/String;");
static object _find_file = location_ifc->get_method("findFile", "(Ljava/lang/String;Lse/idonex/roxen/RoxenRequest;)Lse/idonex/roxen/RoxenResponse;");
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
static object _len = response_class->get_field("len", "I");
static object _type = response_class->get_field("type", "Ljava/lang/String;");
static object _data = response2_class->get_field("data", "Ljava/lang/String;");

static object natives_bind1;

static mapping(object:object) jotomod = set_weak_flag( ([]), 1 );


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


  static object modobj;
  static int modtype;
  static string modname, moddesc;

  static string stringify(object o)
  {
    return o && (string)o;
  }

  static mixed valify(mixed o)
  {
    if(!objectp(o))
      return o;
    else if(o->_values)
      return map(values(o), valify);
    else if(o->is_instance_of(int_class))
      return int_value(o);
    else
      return (string)o;
  }
    
  static object make_reqid(RequestID id)
  {
    /* FIXME */
    return 0;
  }

  static object make_args(mapping args)
  {
    object m = map_class->alloc();
    map_init(m, sizeof(args));
    check_exception();
    foreach(indices(args), string key)
      map_put(m, key, args[key]);
    check_exception();
    return m;
  }

  static mapping make_response(object r)
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
    if(r->is_instance_of(response2_class) &&
       (s = _data->get(r)))
      rr->data = (string)s;
    check_exception();
    return rr;
  }

  array register_module()
  {
    return ({ modtype, modname, moddesc, 0, 1 });
  }

  string status()
  {
    object s = _status(modobj);
    check_exception();
    return s && (string)s;
  }

  string query_location()
  {
    object l = _query_location(modobj);
    check_exception();
    return l && (string)l;
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
    return make_response(r);
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
      /* FIXME */
    }
    modtype = query_type(modobj);
    check_exception();
    modname = stringify(query_name(modobj));
    check_exception();
    moddesc = stringify(query_desc(modobj));
    check_exception();
  }
}

static object native_query(object mod, object var)
{
  mod = jotomod[mod];
  return mod && mod->query((string)var);
}

void create()
{
  natives_bind1 = module_class->register_natives(({
    ({"query", "(Ljava/lang/String;)Ljava/lang/Object;", native_query}),
  }));
}
