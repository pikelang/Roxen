// This is a roxen module. Copyright © 2000, Roxen IS.

#include <module.h>
inherit "module";

constant cvs_version = "$Id: roxen_test.pike,v 1.13 2001/02/01 04:32:30 per Exp $";
constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Roxen self test module";
constant module_doc  = "Tests Roxen WebServer.";
constant is_roxen_tester_module = 1;

Configuration conf;
Stdio.File index_file;
Protocol port;

int verbose;


void start(int n, Configuration c)
{
  conf=c;
  index_file = Stdio.File();
  call_out( do_tests, 0.5 );
}

RequestID get_id()
{
  object id = RequestID(index_file, port, conf);
  id->conf = conf;
  id->misc = ([ "defines":([ " _ok":1 ]) ]);
  id->cookies=([]);
  id->config=(<>);
  id->real_variables=([]);
  id->variables=([]);
  id->prestate=(<>);
  id->supports=(< "images" >);
  id->client_var=([]);

  id->pragma=(<>);
  id->client=({});

  id->realfile="etc/roxen_test/filesystem/index.html";
  id->not_query="/index.html";
  id->raw_url="/index.html";
  id->method="GET";
  id->remoteaddr="127.0.0.1";
  NOCACHE();
  return id;
}

string canon_html(string in) {
  array tags=in/"<";
  string ut=tags[0];
  tags=tags[1..];

  foreach(tags, string tag) {
    string post="";
    int xml;
    if(sscanf(tag, "%s>%s", tag, post)!=2 &&
       sscanf(tag, "%s>", tag)!=1 )
      continue;

    array args=tag/" ";
    string name=args[0];
    args=args[1..];
    if(sizeof(args) && args[-1]=="/") {
      xml=1;
      args=args[..sizeof(args)-2];
    }
    args=sort(args);
    ut+="<"+name;
    if(sizeof(args)) ut+=" "+(args*" ");
    if(xml) ut+=" /";
    ut+=">"+post;
  }
  return ut;
}


// --- XML-based test files -------------------------------

void xml_add_module(string t, mapping m, string c) {
  return;
}

void xml_remove_module(string t, mapping m, string c) {
  return;
}

int tests, ltests;
int fails, lfails;
void xml_test(string t, mapping args, string c) {

  ltests++;
  tests++;

  string rxml="", res;

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
      report_debug( "%4d %-69s  ",
		    ltests, replace(test[..68],
				    ({"\t","\n", "\r"}),
				    ({"\\t","\\n", "\\r"}) ));
    }
  };
  
  RequestID id = get_id();
  Parser.HTML parser =
    Parser.HTML()->
    add_containers( ([ "rxml" :
		       lambda(string t, mapping m, string c) {
			 test_test( c );
			 mixed err =
			   catch( res = Roxen.parse_rxml( rxml, id ));
			 if(err)
			 {
			   test_error("Failed (backtrace)\n");
			   test_error("%s\n",describe_backtrace(err));
			   throw(1);
			 }
			 if(!args["no-canon"])
			   res = canon_html(res);
		       },
		       "result" :
		       lambda(string t, mapping m, string c) {
			 if(res != c) {
			   if(m->not) return;
			   test_error("Failed (%O != %O)\n", res, c);
			   throw(1);
			 }
			 test_ok( );
		       },
		       "glob" :
		       lambda(string t, mapping m, string c) {
			 if( !glob(c, res) ) {
			   if(m->not) return;
			   test_error("Failed (%O does not match %O)\n",
				      res, c);
			   throw(1);
			 }
			 test_ok( );
		       },
		       "has-value" :
		       lambda(string t, mapping m, string c) {
			 if( !has_value(res, c) ) {
			   if(m->not) return;
			   test_error("Failed (%O does not contain %O)\n",
				      rxml, res, c);
			   throw(1);
			 }
			 test_ok( );
		       },
    ]) )
    ->add_tags( ([ "add" : lambda(string t, mapping m, string c) {
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
			     }
			   },
    ]) );

  if( catch(parser->finish(c)) ) {
    fails++;
    lfails++;
  }

  if( verbose && strlen( rxml ) ) test_ok();
  return;
}

void xml_comment(string t, mapping m, string c) {
  report_debug(c + (c[-1]=='\n'?"":"\n"));
}

void run_xml_tests(string data) {

  ltests=0;
  lfails=0;
  Parser.HTML()->add_containers( ([ "add-module" : xml_add_module,
				    "remove-module" : xml_remove_module,
				    "test" : xml_test,
				    "comment": xml_comment,
  ]) )->finish(data);
  if(ltests<sizeof(data/"</test>")-1)
    report_warning("Possibly XML error in testsuite.\n");
  report_debug("Did %d tests, failed on %d.\n", ltests, lfails);
  continue_find_tests();
}

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
  if( catch(test->low_run_tests(conf, update_num_tests)) )
    update_num_tests( 1, 1 );
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
      else if( glob("*/RoxenTest_*", file ) )
      {
	report_debug("\nFound test file %s\n",file);
	int done;
	foreach( tests_to_run, string p )
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
		report_error("Failed to compile %s\n%s\n", file,
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

  report_debug("\n\nDid a grand total of %d tests, %d failed.\n",
	       tests, fails);
  if( fails > 127 )
    fails = 127;
  _exit( fails );
}

void do_tests()
{
  remove_call_out( do_tests );
  if(time() - roxen->start_time < 2 ) {
    call_out( do_tests, 0.2 );
    return;
  }

  tests_to_run = Getopt.find_option(roxen.argv, "d",({"tests"}),0,"" )/",";
  verbose = (int)Getopt.find_option(roxen.argv, "d",({"tests-verbose"}),0, 0 );
  file_stack->push( 0 );
  file_stack->push( "etc/roxen_test/tests" );
  call_out( continue_find_tests, 0 );
}


// --- Some tags used in the RXML tests ---------------

class TagEmitTESTER {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "TESTER";

  array(mapping(string:string)) get_dataset(mapping m, RequestID id) {
    switch(m->test) {
    case "2":
      return map( "aa,a,aa,a,bb,b,cc,c,aa,a,dd,d,ee,e,aa,a,a,a,aa"/",",
		  lambda(string in) { return (["data":in]); } );
    case "1":
    default:
      return ({
	([ "a":"kex", "b":"foo", "c":"1", "d":"12foo" ]),
	([ "a":"kex", "b":"boo", "c":"2", "d":"foo" ]),
	([ "a":"krut", "b":"gazonk", "c":"3", "d":"5foo33a" ]),
	([ "a":"kox", "c":"4", "d":"5foo4a" ])
      });
    }
  }
}
