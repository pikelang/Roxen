// This is a roxen module. Copyright © 2000, Roxen IS.

#include <module.h>
inherit "module";

constant cvs_version = "$Id: roxen_test.pike,v 1.5 2000/11/20 12:59:14 nilsson Exp $";
constant thread_safe = 1;
constant module_type = MODULE_ZERO;
constant module_name = "Roxen self test module";
constant module_doc  = "Tests Roxen WebServer.";

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
void xml_test(string t, mapping m, string c) {

  ltests++;
  tests++;

  string rxml,w_res,a_res;
  RequestID id = get_id();
  Parser.HTML()->add_containers( ([ "rxml" : lambda(string t, mapping m, string c) { rxml=c; },
				    "result" : lambda(string t, mapping m, string c) { w_res=c; },
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
  ]) )->finish(c);

  mixed err = catch( a_res = Roxen.parse_rxml( rxml, id ));
  if(err) {
    fails++;
    lfails++;
    report_error(" Test \"%s\"\nFailed (backtrace)\n",rxml);
    report_error("%s\n",describe_backtrace(err));
    return;
  }

  if(!m["no-canon"])
    a_res = canon_html(a_res);

  if(w_res && a_res != w_res) {
    fails++;
    lfails++;
    report_error(" Test \"%s\"\n Failed (%O != %O)\n", rxml, a_res, w_res);
    return;
  }
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


// --- Mission control ------------------------

void find_tests(string path) {
  report_debug("Looking for tests in %s\n",path);
  foreach(get_dir(path), string file)
    if(file!="CVS" && file_stat(path+file)[1]==-2)
      find_tests(path+file+"/");
    else if(file[-1]!='~' && glob("RoxenTest_*", file)) {
      report_debug("\nFound test file %s\n",path+file);
      if(glob("*.xml",file))
	run_xml_tests(Stdio.read_file(path+file));
    }
}

int die;
void do_tests() {

  if(roxen->start_time - time() < 2)
    call_out( do_tests, 2 );

  if(die) return;
  die=1;
  find_tests("modules/");
  report_debug("\n\nDid a grand total of %d tests, %d failed.\n", tests, fails);

  roxen->shutdown(1.0);
}
