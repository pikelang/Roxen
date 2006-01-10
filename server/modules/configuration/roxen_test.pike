// This is a roxen module. Copyright © 2000 - 2004, Roxen IS.

#include <module.h>
inherit "module";

constant cvs_version = "$Id: roxen_test.pike,v 1.63 2006/01/10 23:19:22 mast Exp $";
constant thread_safe = 1;
constant module_type = MODULE_TAG|MODULE_PROVIDER;
constant module_name = "Roxen self test module";
constant module_doc  = "Tests Roxen WebServer.";
constant is_roxen_tester_module = 1;

Configuration conf;
Stdio.File index_file;
Protocol port;

int verbose;
private int running;
private int finished;

int is_running()
{
  return running;
}

int is_not_finished()
{
  return !finished;
}

int is_ready_to_start()
{
  int ready = 1;
  foreach(roxen.configurations, Configuration config)
    if(config->call_provider("roxen_test", "is_running"))
      ready = 0;
  return ready;
}

int is_last_test_configuration()
{
  foreach(roxen.configurations, Configuration config)
    if(config->call_provider("roxen_test", "is_not_finished"))
      return 0;
  return 1;
}

int tests, ltests;
int fails, lfails;

int do_continue(int _tests, int _fails)
{
  if(finished)
    return 0;
  
  tests += _tests;
  fails += _fails;
  call_out( do_tests, 0.5 );
  return 1;
}

string query_provides()
{
  return "roxen_test";
}

void create()
{
  defvar("selftestdir", "etc/test", "Self test directory", 
         TYPE_STRING);
}

void start(int n, Configuration c)
{
  conf=c;
  index_file = Stdio.File();

  if(is_ready_to_start())
  {
    running = 1;
    call_out( do_tests, 0.5 );
  }
}

class FakePrefLang() {

  int decoded=0;
  int sorted=0;
  array(string) subtags=({});
  array(string) languages=({});
  array(float) qualities=({});

  array(string) get_languages() {
    sort_lang();
    return languages;
  }

  string get_language() {
    if(!languages || !sizeof(languages)) return 0;
    sort_lang();
    return languages[0];
  }

  array(float) get_qualities() {
    sort_lang();
    return qualities;
  }

  float get_quality() {
    if(!qualities || !sizeof(qualities)) return 0.0;
    sort_lang();
    return qualities[0];
  }

  void set_sorted(array(string) lang, void|array(float) q) {
    languages=lang;
    if(q && sizeof(q)==sizeof(lang))
      qualities=q;
    else
      qualities=({1.0})*sizeof(lang);
    sorted=1;
    decoded=1;
  }

  void sort_lang() {
    if(sorted && decoded) return;
    array(float) q;
    array(string) s=reverse(languages)-({""}), u=({});

    if(!decoded) {
      q=({});
      s=Array.map(s, lambda(string x) {
		       float n=1.0;
		       string sub="";
		       sscanf(lower_case(x), "%s;q=%f", x, n);
		       if(n==0.0) return "";
		       sscanf(x, "%s-%s", x, sub);
		       q+=({n});
		       u+=({sub});
		       return x;
		     });
      s-=({""});
      decoded=1;
    }
    else
      q=reverse(qualities);

    sort(q,s,u);
    languages=reverse(s);
    qualities=reverse(q);
    subtags=reverse(u);
    sorted=1;
  }
}

RequestID get_id()
{
  object id = roxen.InternalRequestID();
  id->supports = (< "images" >);
  id->client = ({ "RoxenTest" });
  id->set_url("http://localhost:17369/index.html");

  id->realfile = combine_path_unix(query("selftestdir"), "filesystem/index.html");
  id->misc->stat = conf->stat_file("/index.html", id);
  id->misc->pref_languages = FakePrefLang();
  id->misc->pref_languages->set_sorted( ({"sv","en","bräk"}) );
  NOCACHE();

  return id;
}

static string ignore_errors = 0;

string rxml_error(RXML.Backtrace err, RXML.Type type) {
  //  if(verbose)
  //  werror(describe_backtrace(err)+"\n");
  if (ignore_errors && ignore_errors == err->type) return "";
  return sprintf("[Error (%s): %s]", err->type,
		 String.trim_all_whites(replace(err->msg, "\n", "")));
}

string canon_html(string in) {
  return Roxen.get_xml_parser()->_set_tag_callback (
    lambda (Parser.HTML p, string tag) {
      int xml = tag[-2] == '/';
      string ut = p->tag_name();
      mapping args = p->tag_args();
      foreach (sort (map (indices (args), lower_case)), string arg)
	ut += " " + arg + "='" + args[arg] + "'";
      if(xml) ut+="/";
      return ({"<", ut, ">"});
    })->finish (in)->read();
}


// --- XML-based test files -------------------------------

void xml_set_module_var(string t, mapping m, string c) {
  conf->find_module(m->module)->getvar(m->variable)->set(c);
  return;
}

void xml_add_module(string t, mapping m, string c) {
  conf->enable_module(c);
  return;
}

void xml_drop_module(string t, mapping m, string c) {
  conf->disable_module(c);
  return;
}

void xml_dummy(string t, mapping m, string c) {
  return;
}

void xml_use_module(string t, mapping m, string c,
		    mapping ignored, multiset(string) used_modules) {
  conf->enable_module(c);
  used_modules[c] = 1;
  return;
}

string format_multiline_string (string s)
{
  // Used to present failed results: We want proper quoting, but
  // it gets easier to read if newlines remain.
  return replace (sprintf ("%O", s), "\\n", "\n");
}

void xml_test(string t, mapping args, string c, mapping(int:RXML.PCode) p_code_cache) {

  ltests++;
  tests++;

  string rxml="", res;
  RXML.PCode p_code = p_code_cache[ltests];
  int pass = p_code ? 2 : 1;

  string indent( int l, string what )
  {
    array q = what/"\n";
    //   if( q[-1] == "" )  q = q[..sizeof(q)-2];
    string i = (" "*l+"|  ");
    return i+q*("\n"+i)+"\n";
  };

  string test_error( string message, mixed ... args )
  {
    if( sizeof( args ) )
      message = sprintf( message, @args );
    message = (p_code ? "[Pass 2 (p-code)] " : "[Pass 1 (source)] ") + message;
    if( verbose )
      if( strlen( rxml ) )
	report_debug("FAIL\n" );
    if( strlen( rxml ) )
      report_debug( indent(2, rxml ) );
    rxml="";
    report_debug( indent(2, message ) );
  };

  string test_ok(  )
  {
    rxml = "";
    if( verbose )
      report_debug( "PASS\n" );
  };

  string test_test( string test )
  {
    if( verbose && strlen( rxml ) )
      test_ok();
    rxml = test;
    if( verbose )
    {
      report_debug( "%4d %-69s %s  ",
		    ltests, sprintf("%O", test)[..68],
		    p_code ? "(pass 2)" : "(pass 1)");
    }
  };

  RequestID id = get_id();
  int no_canon;
  Parser.HTML parser =
    Roxen.get_xml_parser()->
    add_containers( ([ "rxml" :
		       lambda(object t, mapping m, string c) {
			 test_test( c );
			 mixed err = catch {
			   ignore_errors = m["ignore-errors"];
			   if (!p_code) {
			     RXML.Type type = m->type ?
			       RXML.t_type->encode (m->type) (
				 conf->default_content_type->parser_prog) :
			       conf->default_content_type;
			     if (m->parser)
			       type = type (RXML.t_parser->encode (m->parser));
			     RXML.Parser parser = Roxen.get_rxml_parser (id, type, 1);
			     parser->context->add_scope ("test", (["pass": pass]));
			     parser->write_end (rxml);
			     res = parser->eval();
			     parser->p_code->finish();
			     p_code_cache[ltests] = parser->p_code;
			   }
			   else {
			     RXML.Context ctx = p_code->new_context (id);
			     ctx->add_scope ("test", (["pass": pass]));
			     res = p_code->eval (ctx);
			   }
			 };
			 ignore_errors = 0;
			 if(err && (!m["ignore-errors"] ||
				    !objectp (err) || !err->is_RXML_Backtrace ||
				    err->type != m["ignore-errors"]))
			 {
			   test_error("Failed (backtrace): %s",describe_backtrace(err));
			   throw(1);
			 }
			 if(!args["no-canon"])
			   res = canon_html(res);
			 else
			   no_canon = 1;
		       },
		       "result" :
		       lambda(object t, mapping m, string c) {
			 if (!m->pass || (int) m->pass == pass) {
			   if (m->type || m->parser) {
			     RXML.Type type = m->type ? RXML.t_type->encode (m->type) :
			       conf->default_content_type (RXML.PNone);
			     if (m->parser)
			       type = type (RXML.t_parser->encode (m->parser));
			     RXML.Parser parser = Roxen.get_rxml_parser (id, type, 1);
			     parser->context->add_scope ("test", (["pass": pass]));
			     parser->write_end (c);
			     c = parser->eval();
			   }
			   if( !no_canon )
			     c = canon_html( c );
			   if(res != c) {
			     if(m->not) return;
			     test_error("Failed (got %s, expected %s)\n",
					format_multiline_string (res),
					format_multiline_string (c));
			     throw(1);
			   }
			   test_ok( );
			 }
		       },
		       "glob" :
		       lambda(object t, mapping m, string c) {
			 if( !glob(c, res) ) {
			   if(m->not) return;
			   test_error("Failed (result %s does not match %s)\n",
				      format_multiline_string (res),
				      format_multiline_string (c));
			   throw(1);
			 }
			 test_ok( );
		       },
		       "has-value" :
		       lambda(object t, mapping m, string c) {
			 if( !has_value(res, c) ) {
			   if(m->not) return;
			   test_error("Failed (result %s does not contain %s)\n",
				      format_multiline_string (res),
				      format_multiline_string (c));
			   throw(1);
			 }
			 test_ok( );
		       },
		       "regexp" :
		       lambda(object t, mapping m, string c) {
			 if( !Regexp(c)->match(res) ) {
			   if(m->not) return;
			   test_error("Failed (result %s does not match %s)\n",
				      format_multiline_string (res),
				      format_multiline_string (c));
			   throw(1);
			 }
			 test_ok( );
		       },
		       "pike" :
		       lambda(object t, mapping m, string c) {
			 c = "string test(string res) {\n" + c + "\n}";
			 object test;
			 mixed err = catch {
			   test = compile_string(c)();
			 };
			 if(err) {
			   int i;
			   c = map(c/"\n", lambda(string in) {
					     return sprintf("%3d: %s", ++i, in); }) * "\n";
			   werror("Error while compiling test\n%s\n\nBacktrace\n%s\n",
				  c, describe_backtrace(err));
			   throw(1);
			 }
			 string r = test->test(res);
			 if(r) {
			   test_error("Failed (%s)\n", r);
			   throw(1);
			 }
			 test_ok( );
		       },
    ]) )
    ->add_tags( ([ "add" : lambda(object t, mapping m, string c) {
			     switch(m->what) {
			       default:
				 test_error("Could not <add> %O; "
					    "unknown variable.\n", m->what);
				 break;
			       case "prestate":
				 id->prestate[m->name] = 1;
				 break;
			       case "variable":
				 id->variables[m->name] = m->value || m->name;
				 break;
			       case "rvariable":
				 if(m->split && m->value)
				   id->real_variables[m->name] = m->value / m->split;
				 else
				   id->real_variables[m->name] = ({ m->value || m->name });
				 break;
			       case "cookies":
				 id->cookies[m->name] = m->value || "";
				 break;
			       case "supports":
				 id->supports[m->name] = 1;
				 break;
			       case "config":
				 id->config[m->name] = 1;
				 break;
			       case "client_var":
				 id->client_var[m->name] = m->value || "";
				 break;
			       case "misc":
				 id->misc[m->name] = m->value || "1";
				 break;
//  			       case "define":
//  				 id->misc->defines[m->name] = m->value || 1;
//  				 break;
			       case "not_query":
				 id->not_query = m->value;
				 break;
			       case "query":
				 id->query = m->value;
				 break;
			       case "request_header":
			         id->request_headers[m->name] = m->value;
				 break;
			     }
			   },

		   "login" : lambda(Parser.HTML p, mapping m) {
			       id->request_headers->authorization =
				 "Basic " + MIME.encode_base64(args->user+":"+args->password);
			       id->realauth = args->user+":"+args->password;
			       conf->authenticate(id);
			     },
    ]) );

  if( mixed error = catch(parser->finish(c)) ) {
    if (error != 1)
      test_error ("Failed to parse test: " + describe_backtrace (error));
    fails++;
    lfails++;
  }

  if( verbose && strlen( rxml ) ) test_ok();
  return;
}

string tag_test_data;
class PrefLang {
  array(string) get_languages()
  {
    return ({});
  }

  string get_language()
  {
    return 0;
  }

  void set_sorted(array(string) lang) {}
}

void xml_tag_test(string t, mapping args, string c, mapping(int:RXML.PCode) p_code_cache) {

  ltests++;
  tests++;

  string indent( int l, string what )
  {
    array q = what/"\n";
    //   if( q[-1] == "" )  q = q[..sizeof(q)-2];
    string i = (" "*l+"|  ");
    return i+q*("\n"+i)+"\n";
  };

  string test_error( string message, mixed ... args )
  {
    if( sizeof( args ) )
      message = sprintf( message, @args );
    if( verbose )
      report_debug("FAIL\n" );
    report_debug( indent(2, message ) );
  };

  string test_ok(  )
  {
    if( verbose )
      report_debug( "PASS\n" );
  };

  string test_test( string test )
  {
    if( verbose )
    {
      report_debug( "%4d %-69s  ",
		    ltests, sprintf("%O", test)[..68] );
    }
  };

  string res;
  Parser.HTML parser =
    Roxen.get_xml_parser()->
    add_containers( ([ "rxml":
		       lambda(object t, mapping m, string c) {
			 tag_test_data = c;

			 mapping request_headers = ([]);
			 if(args->admin && args->password)
			   request_headers->authorization =
			     "Basic " + MIME.encode_base64(args->user+":"+args->password);
			 roxen.InternalRequestID id = roxen.InternalRequestID();
			 id->misc->pref_languages = PrefLang();
			 id->conf = conf;
			 id->realauth = args->user+":"+args->password;
			 id->request_headers = request_headers;
			 id->prot = "HTTP";

			 int logerrorsr =
			   conf->find_module("rxmlparse")->query("logerrorsr");
			 int quietr =
			   conf->find_module("rxmlparse")->query("quietr");
			 if(m["ignore-rxml-run-error"]) {
			   conf->find_module("rxmlparse")->getvar("logerrorsr")->set(0);
			   conf->find_module("rxmlparse")->getvar("quietr")->set(1);
			 }
			 res = conf->try_get_file(args->file, id);
			 if(m["ignore-rxml-run-error"]) {
			   conf->find_module("rxmlparse")->getvar("logerrorsr")->
			     set(logerrorsr);
			   conf->find_module("rxmlparse")->getvar("quietr")->
			     set(quietr);
			 }
		       },

		       "result":
		       lambda(object t, mapping m, string c) {
			 res = canon_html( res );
			 c = canon_html( c );

			 test_test(c);
			 if(res != c) {
			   if(m->not) return;
			   test_error("Failed (got %s, expected %s)\n",
				      format_multiline_string (res),
				      format_multiline_string (c));
			   throw(1);
			 }
			 test_ok( );
		       },

		       "glob" :
		       lambda(object t, mapping m, string c) {
			 if( !glob(c, res) ) {
			   if(m->not) return;
			   test_error("Failed (result %s does not match %s)\n",
				      format_multiline_string (res),
				      format_multiline_string (c));
			   throw(1);
			 }
			 test_ok( );
		       },

    ]));

  if( mixed error = catch(parser->finish(c)) ) {
    if (error != 1)
      test_error ("Failed to parse test: " + describe_backtrace (error));
    fails++;
    lfails++;
  }
}

class TagTestData {
  inherit RXML.Tag;
  constant name = "test-data";
  array(RXML.Type) result_types = ({RXML.t_html (RXML.PXml)});
  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      return ({ tag_test_data||"" });
    }
  }
}

void xml_comment(object t, mapping m, string c) {
  if(verbose)
    report_debug(c + (c[-1]=='\n'?"":"\n"));
}

void run_xml_tests(string data) {
  mapping(int:RXML.PCode) p_code_cache = ([]);
  multiset(string) used_modules = (<>);

  ltests=0;
  lfails=0;
  Roxen.get_xml_parser()->add_containers( ([
    "add-module" : xml_add_module,
    "drop-module" : xml_dummy /* xml_drop_module */,
    "use-module": xml_use_module,
    "test" : xml_test,
    "tag-test" : xml_tag_test,
    "comment": xml_comment,
  ]) )->
    set_extra (p_code_cache, used_modules)->
    finish(data);

  int test_tags = 0;

  Roxen.get_xml_parser()->add_quote_tag ("!--", "", "--")
			->add_tags ((["test": lambda () {test_tags++;},
				      "tag-test": lambda () {test_tags++;}]))
			->finish (data);

  if(test_tags != ltests)
    report_warning("Possibly XML error in testsuite - "
		   "got %d test tags but did %d tests.\n",
		   test_tags, ltests);

  // Go through them again, evaluation from the p-code this time.
  ltests=0;
  Roxen.get_xml_parser()->add_containers( ([
    "add-module" : xml_dummy /* xml_add_module */,
    "drop-module" : xml_drop_module,
    "test" : xml_test,
    "tag-test" : xml_tag_test,
    "comment": xml_comment,
  ]) )->
    set_extra (p_code_cache, used_modules)->
    finish(data);

  foreach (indices (used_modules), string modname)
    conf->disable_module (modname);

  report_debug("Did %d tests, failed on %d.\n", ltests * 2, lfails);
  continue_find_tests();
}


// --- Pike test files -----------------------

void run_pike_tests(object test, string path)
{
  void update_num_tests(int tsts, int fail)
  {
    tests+=tsts;
    fails+=fail;
    report_debug("Did %d tests, failed on %d.\n", tsts, fail);
    continue_find_tests();
  };

  if(!test)
    return;
  if( mixed error = catch(test->low_run_tests(conf, update_num_tests)) ) {
    if (error != 1) throw (error);
    update_num_tests( 1, 1 );
  }
}


// --- Mission control ------------------------

array(string) tests_to_run;
ADT.Stack file_stack = ADT.Stack();

void continue_find_tests( )
{
  while( string file = file_stack->pop() )
  {
    if( Stdio.Stat st = file_stat( file ) )
    {
      if( file!="CVS" && st->isdir )
      {
	string dir = file+"/";
	foreach( get_dir( dir ), string f )
	  file_stack->push( dir+f );
      }
      else if( glob("*/RoxenTest_*", file ) && file[-1]!='~')
      {
	report_debug("\nFound test file %s\n",file);
	int done;
	foreach( tests_to_run, string p ) {
	  if( !has_prefix(p, "RoxenTest_") )
	    p = "RoxenTest_" + p;
	  if( glob( "*"+p+"*", file ) )
	  {
	    if(glob("*.xml",file))
	    {
	      call_out( run_xml_tests, 0, Stdio.read_file(file) );
	      return;
	    }
	    else if(glob("*.pike",file))
	    {
	      object test;
	      mixed error;
	      if( error=catch( test=compile_file(file)( verbose ) ) )
		report_error("Failed to compile %s:\n%s", file,
			     describe_backtrace(error));
	      else
	      {
		call_out( run_pike_tests,0,test,file );
		return;
	      }
	    }
	    done++;
	    break;
	  }
	  if( !done )
	    report_debug( "Skipped (not matched by --tests argument)\n" );
	}
      }
    }
  }
  
  running = 0;
  finished = 1;
  if(is_last_test_configuration())
  {
    report_debug("\n\nDid a grand total of %d tests, %d failed.\n",
		 tests, fails);
    roxen.restart(0, fails > 127 ? 127 : fails);
  }
  else
    foreach(roxen.configurations, Configuration config)
      if(config->call_provider("roxen_test", "do_continue", tests, fails))
	return;
}

void do_tests()
{
  remove_call_out( do_tests );
  if(time() - roxen->start_time < 2 ) {
    call_out( do_tests, 0.2 );
    return;
  }
  report_debug("Starting roxen self test in directory %O.\n", query("selftestdir"));

  tests_to_run = Getopt.find_option(roxen.argv, 0,({"tests"}),0,"" )/",";
  verbose = !!Getopt.find_option(roxen.argv, 0,({"tests-verbose"}),0, 0 );

  conf->rxml_tag_set->handle_run_error = rxml_error;
  conf->rxml_tag_set->handle_parse_error = rxml_error;

  file_stack->push( 0 );
  file_stack->push( combine_path(query("selftestdir"), "tests" ));
  call_out( continue_find_tests, 0 );
}

// --- Some tags used in the RXML tests ---------------

class EntityDyn {
  inherit RXML.Value;
  int i;
  mixed rxml_var_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    if(c->current_scope() && RXML.get_var("x"))
      return ENCODE_RXML_INT(i++, type);
    return ENCODE_RXML_INT(0, type);
  }
}

class EntityCVal(string val) {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name) {
    return val;
  }
}

class EntityVVal(string val) {
  inherit RXML.Value;
  mixed rxml_var_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    return ENCODE_RXML_TEXT(val, type);
  }
}

class TagEmitTESTER {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "TESTER";

  array(mapping(string:mixed)) get_dataset(mapping m, RequestID id) {
    switch(m->test) {
    case "6":
      return ({(["integer":  17,
		 "float":    17.0,
		 "string":   "foo",
		 "array":    ({1, 2.0, "3"}),
		 "multiset": (<1, 2.0, "3">),
		 "mapping":  ([1: "one", 2.0: 2, "3": 3]),
		 "object":   class {}(),
		 "program":  class {},
		 "zero_integer":   0,
		 "zero_float":     0.0,
		 "empty_string":   "",
		 "empty_array":    ({}),
		 "empty_multiset": (<>),
		 "empty_mapping":  ([]),
		 "zero_int_array": ({0}),
		 "zero_float_array": ({0.0}),
		 "empty_string_array": ({""}),
		 "empty_array_array": ({({})}),
	       ])});

    case "5":
      return ({(["v": EntityVVal ("<&>"), "c": EntityCVal ("<&>")])});

    case "4":
      return ({
	([ "a":"1", "b":EntityCVal("aa"), "c":EntityVVal("ca") ]),
	([ "a":"2", "b":EntityCVal("ba"), "c":EntityVVal("cb") ]),
	([ "a":"3", "b":EntityCVal("ab"), "c":EntityVVal("ba") ]),
      });

    case "3":
      return ({ (["data":"a"]),
		(["data":RXML.nil]),
		(["data":RXML.empty]),
		(["data":EntityDyn()]) });

    case "2":
      return map( "aa,a,aa,a,bb,b,cc,c,aa,a,dd,d,ee,e,aa,a,a,a,aa"/",",
		  lambda(string in) { return (["data":in]); } );
    case "1":
    default:
      return ({
	([ "a":"kex",  "b":"foo",    "c":1, "d":"12foo",   "e":"-8",  "f": "0" ]),
	([ "a":"kex",  "b":"boo",    "c":2, "d":"foo",     "e":"8",   "f": "-6.4" ]),
	([ "a":"krut", "b":"gazonk", "c":3, "d":"5foo33a", "e":"11",  "f": "1e6" ]),
	([ "a":"kox",                "c":4, "d":"5foo4a",  "e":"-11", "f": "0.23" ])
      });
    }
  }
}

class TagOEmitTESTER {
  inherit TagEmitTESTER;
  inherit "emit_object";
  constant plugin_name = "OTESTER";

  class MyEmit (array(mapping) dataset) {
    inherit EmitObject;
    int pos;

    private mapping(string:mixed) really_get_row() {
      return pos<sizeof(dataset)?dataset[pos++]:0;
    }
  }

  EmitObject get_dataset(mapping m, RequestID id) {
    return MyEmit( ::get_dataset(m,id) );
  }
}

class TagSEmitTESTER {
  inherit TagEmitTESTER;
  constant plugin_name = "STESTER";
  constant skiprows = 1;
  constant maxrows = 1;
  constant sort = 1;
}

class TagTestSleep {
  inherit RXML.Tag;
  constant name = "testsleep";

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      sleep((int)args->time);
    }
  }
}

class TagTestMisc
{
  inherit RXML.Tag;
  constant name = "test-misc";

  class Frame
  {
    inherit RXML.Frame;

    array do_return()
    {
      if (args->set)
	RXML_CONTEXT->set_misc (args->set, content);
      else if (args["set-prog"])
	RXML_CONTEXT->set_misc (TagTestMisc, content);
      else if (args->get)
	return ({RXML_CONTEXT->misc[args->get]});
      else if (args["get-prog"])
	return ({RXML_CONTEXT->misc[TagTestMisc]});
      return ({});
    }
  }
}

class TagRunError
{
  inherit RXML.Tag;
  constant name = "run-error";

  class Frame
  {
    inherit RXML.Frame;
    array do_return()
    {
      run_error (args->message || "A test run error");
    }
  }
}
