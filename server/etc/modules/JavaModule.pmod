
static constant jvm = Java.machine;

#define FINDCLASS(X) (jvm->find_class(X)||(jvm->exception_describe(),jvm->exception_clear(),error("Failed to load class " X ".\n"),0))

/* Class loading */
static object class_class = FINDCLASS("java/lang/Class");
static object classloader_class = FINDCLASS("java/lang/ClassLoader");
static object classloader2_class = FINDCLASS("se/idonex/servlet/ClassLoader");
static object load_class = classloader_class->get_method("loadClass", "(Ljava/lang/String;)Ljava/lang/Class;");
static object cl_init = classloader2_class->get_method("<init>", "(Ljava/lang/String;)V");
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
static object query_type = module_class->get_method("queryType", "()I");
static object query_name = module_class->get_method("queryName", "()Ljava/lang/String;");
static object query_desc = module_class->get_method("queryDescription", "()Ljava/lang/String;");
static object _status = module_class->get_method("status", "()Ljava/lang/String;");


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
    cl = classloader2_class->alloc();
    check_exception();
    cl_init->call_nonvirtual(cl, dir);
    check_exception();
  }
}

class ModuleWrapper
{
  static object modobj;
  static int modtype;
  static string modname, moddesc;

  static string stringify(object o)
  {
    return o && (string)o;
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
