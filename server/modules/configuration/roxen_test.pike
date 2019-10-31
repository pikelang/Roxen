// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.

#include <module.h>
inherit "module";

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_TAG|MODULE_PROVIDER;
constant module_name = "Roxen self test module";
constant module_doc  = "Tests Roxen WebServer.";
constant is_roxen_tester_module = 1;

Configuration conf;
Stdio.File index_file;
Protocol port;
RoxenModule rxmlparser;

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

int tests, ltests, test_num;
int fails, lfails;
int pass;
string tag_test_data;
int bkgr_fails;

void background_failure()
{
  // Called in all configurations/instances of this module, by
  // describe_backtrace() (roxenloader.pike), in self test mode. We
  // need to check whether it's for us or not by checking if we're
  // running currently.
  if (is_running()) {
    // Log something to make these easier to locate in the noisy test logs.
    report_error ("################ Background failure\n");
    bkgr_fails++;
  }
}

int testloop_alive;
mixed testloop_abs_co;

void testloop_ping()
{
  testloop_alive = time();
}

void testloop_abort_if_stuck()
{
#ifndef __NT__
  if (!query("abs_timeout")) return;

  if (!is_not_finished() || !is_running()) {
    testloop_abs_co = UNDEFINED;
    return;
  }

  if ((time(1) - testloop_alive) > 60 * query("abs_timeout")) {
    report_debug("**** %s: ABS: Testloop has stalled!\n"
		 "**** %s: ABS: %d seconds since last test.\n",
		 ctime(time()) - "\n",
		 ctime(time()) - "\n",
		 time(1) - testloop_alive);
    roxen.engage_abs(0);
  }

  testloop_abs_co = call_out(testloop_abort_if_stuck, 100);
#endif
}

void schedule_tests (int|float delay, function func, mixed... args)
{
  // Run the tests in a normal handler thread so that real background
  // jobs can run as usual.

  testloop_ping();
  call_out (roxen.handle, delay,
	    lambda (function func, array args) {
	      // Meddle with the busy_threads counter, so that this
	      // handler thread running the tests doesn't delay the
	      // background jobs.
	      testloop_ping();
	      roxen->busy_threads--;
	      mixed err = catch (func (@args));
	      roxen->busy_threads++;
	      testloop_ping();
	      if (err) throw (err);
	    }, func, args);
}

void schedule_tests_single_thread (int|float delay,
				   function func, mixed... args)
{
  // The opposite of schedule_tests, i.e. tries to ensure no other
  // jobs gets executed in parallel by either background_run or a
  // roxen.handle.
  testloop_ping();
  call_out (lambda (function func, array args) {
	      testloop_ping();
	      roxen->hold_handler_threads();
	      testloop_ping();
	      mixed err = catch (func (@args));
	      roxen->release_handler_threads (0);
	      testloop_ping();
	      if (err) throw (err);
	    }, delay, func, args);
}

// This function is used to hand over testsuite control
// from one configuration to the next.
int do_continue(int _tests, int _fails)
{
  if(finished)
    return 0;

  running = 1;
  tests += _tests;
  fails += _fails;
  testloop_ping();
  testloop_abort_if_stuck();
  schedule_tests (0.5, do_tests);
  return 1;
}

string query_provides()
{
  return "roxen_test";
}

void create()
{
  defvar("selftestdir", "etc/test", "Self test directory", TYPE_STRING);
  defvar("abs_timeout", 10, "ABS Timeout", TYPE_INT);
}

void start(int n, Configuration c)
{
  conf=c;
  index_file = Stdio.File();

  module_dependencies (0, ({"rxmlparse"}), 1);
  rxmlparser = conf->find_module ("rxmlparse");

  if(is_ready_to_start())
  {
    running = 1;

    testloop_ping();
    testloop_abort_if_stuck();

    schedule_tests (0.5, do_tests);
  }
}

void set_id_path (RequestID fake_id, string path)
{
  fake_id->set_url("http://localhost:17369" + path);
  string realpath =
    combine_path_unix (query("selftestdir"), "filesystem" + path);
  if (file_stat (realpath)) fake_id->realfile = realpath;
}

protected string ignore_errors = 0;

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

string strip_silly_ws (string in)
// Silly whitespace is defined to be any whitespace next to tags,
// comments, processing instructions, and at the beginning or end of
// the whole string.
{
  return Roxen.get_xml_parser()->_set_data_callback (
    lambda (Parser.HTML p, string data) {
      return ({String.trim_all_whites (data)});
    })->finish (in)->read();
}


// --- XML-based test files -------------------------------

void xml_set_module_var(Parser.HTML file_parser, mapping m, string c) {
  conf->find_module(m->module)->getvar(m->variable)->set(c);
  return;
}

void xml_add_module(Parser.HTML file_parser, mapping m, string c) {
  conf->enable_module(c);
  return;
}

void xml_drop_module(Parser.HTML file_parser, mapping m, string c) {
  conf->disable_module(c);
  return;
}

void xml_dummy(Parser.HTML file_parser, mapping m, string c) {
  return;
}

void xml_use_module(Parser.HTML file_parser, mapping m, string c,
		    mapping ignored, multiset(string) used_modules) {
  conf->enable_module(c);
  used_modules[c] = 1;
  return;
}

void xml_test(Parser.HTML file_parser, mapping args, string c,
	      mapping(int:RXML.PCode) p_code_cache) {

  testloop_ping();

  if (roxen.is_shutting_down()) return;

  test_num++;
  RXML.PCode p_code = p_code_cache[test_num];
  if (pass == 2 && !p_code) return; // Not a test that produced p-code.

  ltests++;
  tests++;

  string rxml="";
  mixed res;

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
    message = (pass == 2 ? "[Pass 2 (p-code)] " : "[Pass 1 (source)] ") + message;
    if( verbose )
      if( strlen( rxml ) )
	report_debug("FAIL\n" );
    report_error (indent (2, sprintf ("################ Error at line %d:",
				      file_parser->at_line())));
    if( strlen( rxml ) )
      report_debug( indent(2, rxml ) );
    rxml="";
    report_error( indent(2, message ) );
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
      report_debug( "%4d %-69s (pass %d)  ",
		    ltests, sprintf("%O", test)[..68], pass);
    }
  };

  RequestID id = roxen.InternalRequestID();
  id->conf = conf;
  id->prot = "HTTP";
  id->supports = (< "images" >);
  id->client = ({ "RoxenTest" });
  id->misc->pref_languages = PrefLanguages();
  id->misc->pref_languages->set_sorted( ({"sv","en","bräk"}) );
  NOCACHE();
  set_id_path (id, "/index.html");

  int no_canon, no_strip_silly_ws;
  Parser.HTML parser =
    Roxen.get_xml_parser()->
    add_containers( ([ "rxml" :
		       lambda(object t, mapping m, string c) {
			 test_test( c );
			 id->misc->stat = conf->stat_file ("/index.html", id);
			 mixed err = catch {
			   ignore_errors = m["ignore-errors"];
			   if (pass == 1) {
			     RXML.Type type = m->type ?
			       RXML.t_type->encode (m->type) (
				 conf->default_content_type->parser_prog) :
			       conf->default_content_type;
			     if (m->parser)
			       type = type (RXML.t_parser->encode (m->parser));
			     RXML.Parser parser = Roxen.get_rxml_parser (id, type, 1);
			     parser->context->add_scope ("test", (["pass": 1]));
			     parser->write_end (rxml);
#ifdef GAUGE_RXML_TESTS
			     werror ("Line %d: Test took %.3f us (pass 1)\n",
				     file_parser->at_line(),
				     gauge (res = parser->eval()) * 1e9);
#else
			     res = parser->eval();
#endif
			     parser->p_code->finish();
			     p_code_cache[ltests] = parser->p_code;
			   }
			   else {
			     RXML.Context ctx = p_code->new_context (id);
			     ctx->add_scope ("test", (["pass": 2]));
#ifdef GAUGE_RXML_TESTS
			     werror ("Line %d: Test took %.3f us (pass 2)\n",
				     file_parser->at_line(),
				     gauge (res = p_code->eval (ctx)) * 1e9);
#else
			     res = p_code->eval (ctx);
#endif
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

			 if(stringp (res) && !args["no-canon"])
			   res = canon_html(res);
			 else
			   no_canon = 1;
			 if (stringp (res) && !args["no-strip-ws"])
			   res = strip_silly_ws (res);
			 else
			   no_strip_silly_ws = 1;
		       },

		       "test-in-file":
		       lambda(object t, mapping m, string c) {
			 test_test (tag_test_data = c);
			 set_id_path (id, m->file);

			 int logerrorsr = rxmlparser->query("logerrorsr");
			 int quietr = rxmlparser->query("quietr");
			 if(m["ignore-rxml-run-error"]) {
			   rxmlparser->getvar("logerrorsr")->set(0);
			   rxmlparser->getvar("quietr")->set(1);
			 }

			 res = conf->try_get_file(m->file, id);

			 if(m["ignore-rxml-run-error"]) {
			   rxmlparser->getvar("logerrorsr")->set(logerrorsr);
			   rxmlparser->getvar("quietr")->set(quietr);
			 }

			 if(stringp (res) && !args["no-canon"])
			   res = canon_html(res);
			 else
			   no_canon = 1;
			 if (stringp (res) && !args["no-strip-ws"])
			   res = strip_silly_ws (res);
			 else
			   no_strip_silly_ws = 1;
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
			   if (!no_strip_silly_ws)
			     c = strip_silly_ws (c);
			   if (m->not ? res == c : res != c) {
			     test_error("Failed\n(got: %O\nexpected: %O)\n",
					res, c);
			     throw(1);
			   }
			   test_ok( );
			 }
		       },

		       "glob" :
		       lambda(object t, mapping m, string c) {
			 if (m->not ? glob(c, res) : !glob(c, res)) {
			   test_error("Failed\n(result %O\ndoes not match %O)\n",
				      res, c);
			   throw(1);
			 }
			 test_ok( );
		       },

		       "has-value" :
		       lambda(object t, mapping m, string c) {
			 if (m->not ? has_value(res, c) : !has_value(res, c)) {
			   test_error("Failed\n(result %O\ndoes not contain %O)\n",
				      res, c);
			   throw(1);
			 }
			 test_ok( );
		       },

		       "regexp" :
		       lambda(object t, mapping m, string c) {
			 if (m->not ? Regexp(c)->match(res) :
			     !Regexp(c)->match(res)) {
			   test_error("Failed\n(result %O\ndoes not match %O)\n",
				      res, c);
			   throw(1);
			 }
			 test_ok( );
		       },

		       "equal":
		       lambda(object t, mapping m, string c) {
			 c = "constant c = (" + c + ");";
			 program p;
			 if (mixed err = catch (p = compile_string (c))) {
			   test_error ("Failed\n(failed to compile %O)\n", c);
			   throw (1);
			 }
			 mixed v;
			 if (mixed err = catch (v = p()->c)) {
			   test_error ("Failed\n(failed to clone and "
				       "get value from %O)\n", c);
			   throw (1);
			 }
			 if (m->not ? equal (res, v) : !equal (res, v)) {
			   test_error("Failed\n(result %O\ndoes not match %O)\n",
				      res, v);
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
				 throw (1);
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
			       id->realauth = m->user + ":" + m->password;
			       id->request_headers->authorization =
				 "Basic " + MIME.encode_base64 (id->realauth);
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

class TagTestData {
  inherit RXML.Tag;
  constant name = "test-data";
  constant flags = RXML.FLAG_DONT_CACHE_RESULT;
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

  // El cheapo xml header parser.
  if (has_prefix (data, "<?xml")) {
    sscanf (data, "%[^\n]", string s);
    if (sscanf (s, "%*sencoding=\"%s\"", s) == 2)
      data = Locale.Charset.decoder (s)->feed (data)->drain();
  }

  ltests=0;
  lfails=0;

  test_num = 0;
  pass = 1;
  Roxen.get_xml_parser()->add_containers( ([
    "add-module" : xml_add_module,
    "drop-module" : xml_dummy /* xml_drop_module */,
    "use-module": xml_use_module,
    "test" : xml_test,
    "comment": xml_comment,
  ]) )->
    set_extra (p_code_cache, used_modules)->
    finish(data);

  if (roxen.is_shutting_down()) return;

  int test_tags = 0;

  Roxen.get_xml_parser()->add_quote_tag ("!--", "", "--")
			->add_tags ((["test": lambda () {test_tags++;}]))
			->finish (data);

  if(test_tags != ltests)
    report_warning("Possibly XML error in testsuite - "
		   "got %d test tags but did %d tests.\n",
		   test_tags, ltests);

  // Go through them again, evaluation from the p-code this time.
  test_num = 0;
  pass = 2;
  Roxen.get_xml_parser()->add_containers( ([
    "add-module" : xml_dummy /* xml_add_module */,
    "drop-module" : xml_drop_module,
    "test" : xml_test,
    "comment": xml_comment,
  ]) )->
    set_extra (p_code_cache, used_modules)->
    finish(data);

  if (roxen.is_shutting_down()) return;

  foreach (indices (used_modules), string modname)
    conf->disable_module (modname);

  report_debug("Did %d tests, failed on %d%s.\n", ltests, lfails,
	      bkgr_fails ?
	       ", detected " + bkgr_fails + " background failures" : "");

  if (bkgr_fails) {
    fails += bkgr_fails;
    bkgr_fails = 0;
  }

  continue_run_tests();
}


// --- Pike test files -----------------------

void run_pike_tests(object test, string path)
{
  testloop_ping();

  void update_num_tests(int tsts, int fail)
  {
    tests+=tsts;
    fails+=fail;

    report_debug("Did %d tests, failed on %d%s.\n", tsts, fail,
		 bkgr_fails ?
		 ", detected " + bkgr_fails + " background failures" : "");

    if (bkgr_fails) {
      fails += bkgr_fails;
      bkgr_fails = 0;
    }

    continue_run_tests();
  };

  if(!test)
    return;

  if( mixed error = catch(test->low_run_tests(conf, update_num_tests)) ) {
    if (error != 1) throw (error);
    update_num_tests( 1, 1 );
  }
}


// --- Mission control ------------------------

array(string) test_files;

void continue_run_tests( )
{
  testloop_ping();
  if (sizeof (test_files)) {
    string file = test_files[0];
    test_files = test_files[1..];

    report_debug("\nRunning test %s\n",file);

    if (has_suffix (file, ".xml"))
    {
      schedule_tests (0, run_xml_tests, Stdio.read_file(file));
      return;
    }
    else			// Pike test.
    {
      object test;
      mixed error;
      tests++;
      if( error=catch( test=compile_file(file)( verbose ) ) ) {
	report_error("################ Failed to compile %s:\n%s", file,
		     describe_backtrace(error));
	fails++;
      }
      else
      {
	if (test->single_thread)
	  schedule_tests_single_thread (0, run_pike_tests, test, file);
	else
	  schedule_tests (0, run_pike_tests,test,file);
	return;
      }
    }
  }

  running = 0;
  finished = 1;
  remove_call_out(testloop_abs_co);
  testloop_abs_co = UNDEFINED;
  if(is_last_test_configuration())
  {
    // Note that e.g. the distmaker parses this string.
    report_debug("\nDid a grand total of %d tests, %d failed.\n\n",
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
  if(time() - roxen->start_time < 2 ) {
    schedule_tests (0.2, do_tests);
    return;
  }
  report_debug("\nStarting roxen self test in %s\n",
	       query("selftestdir"));

  array(string) tests_to_run =
    Getopt.find_option(roxen.argv, 0,({"tests"}),0,"" )/",";
  foreach( tests_to_run; int i; string p )
    if( !has_prefix(p, "RoxenTest_") )
      tests_to_run[i] = "RoxenTest_" + p;

  verbose = !!Getopt.find_option(roxen.argv, 0,({"tests-verbose"}),0, 0 );

  conf->rxml_tag_set->handle_run_error = rxml_error;
  conf->rxml_tag_set->handle_parse_error = rxml_error;

  test_files = ({});
  mapping(string:int) matched_pos = ([]);
  ADT.Stack file_stack = ADT.Stack();
  file_stack->push( 0 );
  file_stack->push( combine_path(query("selftestdir"), "tests" ));

file_loop:
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
	foreach( tests_to_run; int i; string p ) {
	  if( glob( "*/"+p+"*", file ) )
	  {
	    if (has_suffix (file, ".xml") || has_suffix (file, ".pike")) {
	      test_files += ({file});
	      matched_pos[file] = i;
	    }
	    continue file_loop;
	  }
	}
	report_debug( "Skipped test %s\n", file);
      }
    }
  }

  // The order should not be significant ...
  test_files = Array.shuffle (test_files);

  // ... but let the caller control the order in case it turns out to be.
  sort (map (test_files, matched_pos), test_files);

  schedule_tests (0, continue_run_tests);
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

class TestNull
{
  inherit RXML.Nil;
  constant is_RXML_encodable = 1;
  string _sprintf (int flag) {return flag == 'O' && "TestNull()";}
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
		(["data":TestNull()]),
		(["data":RXML.empty]),
		(["data":EntityDyn()]),
		(["data": Val.null]),
	     });

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

class TagTestArgs
{
  inherit RXML.Tag;
  constant name = "test-args";

  array(RXML.Type) result_types = ({RXML.t_mapping});

  mapping(string:RXML.Type) req_arg_types = ([
    "req-string": RXML.t_string (RXML.PEnt),
    "req-int": RXML.t_int (RXML.PEnt),
  ]);

  mapping(string:RXML.Type) opt_arg_types = ([
    "opt-string": RXML.t_string (RXML.PEnt),
    "opt-int": RXML.t_int (RXML.PEnt),
    "opt-float": RXML.t_float (RXML.PEnt),
  ]);

  class Frame
  {
    inherit RXML.Frame;

    array do_return()
    {
      result = args;
    }
  }
}

class TagTestContentReq
{
  inherit RXML.Tag;
  constant name = "test-required-content";

  RXML.Type content_type = RXML.t_any (RXML.PXml);
  array(RXML.Type) result_types = ({RXML.t_any});

  int flags = RXML.FLAG_CONTENT_VAL_REQ;

  class Frame
  {
    inherit RXML.Frame;
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
