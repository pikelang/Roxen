// This is a roxen module. Copyright © 2000, Roxen IS.

#include <module.h>
inherit "module";

constant cvs_version = "$Id: roxen_test.pike,v 1.10 2001/01/31 04:27:13 per Exp $";
constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Roxen self test module";
constant module_doc  = "Tests Roxen WebServer.";
constant is_roxen_tester_module = 1;

Configuration conf;
Stdio.File index_file;
Protocol port;

void start(int n, Configuration c) {
  conf=c;
  index_file = Stdio.File();
  call_out( do_tests, 2 );
  report_debug("Call out requested\n");
}

RequestID get_id() {
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

  string rxml, res;
  RequestID id = get_id();
  Parser.HTML parser =
    Parser.HTML()->
    add_containers( ([ "rxml" :
		       lambda(string t, mapping m, string c) {
			 rxml=c;
			 mixed err = catch( res = Roxen.parse_rxml( rxml, id ));
			 if(err) {
			   report_error(" Test \"%s\"\nFailed (backtrace)\n",rxml);
			   report_error("%s\n",describe_backtrace(err));
			   throw(1);
			 }

			 if(!args["no-canon"])
			   res = canon_html(res);
		       },
		       "result" :
		       lambda(string t, mapping m, string c) {
			 if(res != c) {
			   if(m->not) return;
			   report_error(" Test \"%s\"\n Failed (%O != %O)\n", rxml, res, c);
			   throw(1);
			 }
		       },
		       "glob" :
		       lambda(string t, mapping m, string c) {
			 if( !glob(c, res) ) {
			   if(m->not) return;
			   report_error(" Test \"%s\"\n Failed (%O does not match %O)\n",
					rxml, res, c);
			   throw(1);
			 }
		       },
		       "has-value" :
		       lambda(string t, mapping m, string c) {
			 if( !has_value(res, c) ) {
			   if(m->not) return;
			   report_error(" Test \"%s\"\n Failed (%O does not contain %O)\n",
					rxml, res, c);
			   throw(1);
			 }
		       },
    ]) )->add_tags( ([ "add" : lambda(string t, mapping m, string c) {
				 switch(m->what) {
				 default:
				   report_error("Could not <add> %O; unknown variable.\n", m->what);
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
  if(ltests<sizeof(data/"</test>")-1) report_warning("Possibly XML error in testsuite.\n");
  report_debug("Did %d tests, failed on %d.\n", ltests, lfails);
}

void run_pike_tests(object test, string path) {
  if(!test)
    return;
  if(test->run_tests)
    catch
    {
      int tsts, fail;
      [tsts,fail] = test->run_tests(conf);
      tests+=tsts;
      fails+=fail;
    };
}


// --- Mission control ------------------------

array(string) tests_to_run;

void find_tests(string path) {
  report_debug("Looking for tests in %s\n",path);
  foreach(get_dir(path), string file)
    if(file!="CVS" && file_stat(path+file)[1]==-2)
      find_tests( path + file + "/" );
    else if(file[-1]!='~' && glob("RoxenTest_*", file))
    {
      report_debug("\nFound test file %s\n",path+file);
      int done;
      foreach( tests_to_run, string p )
	if( glob( "*"+p+"*", file ) )
	{
	  if(glob("*.xml",file))
	    run_xml_tests(Stdio.read_file(path+file));
	  else if(glob("*.pike",file))
	    run_pike_tests( compile_file(path+file)(), path+file );
	  done++;
	  break;
	}
      if( !done )
	report_debug( "Skipped (not matched by --tests argument)\n" );
    }
}

int die;
void do_tests() {

  tests_to_run = Getopt.find_option(roxen.argv, "d",({"tests"}),0,"" )/",";

  if(time() - roxen->start_time < 2) {
    call_out( do_tests, 2 );
    return;
  }

  if(die) return;
  die=1;
  find_tests("etc/roxen_test/tests/");
  report_debug("\n\nDid a grand total of %d tests, %d failed.\n", tests, fails);

  roxen->shutdown(1.0);
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
