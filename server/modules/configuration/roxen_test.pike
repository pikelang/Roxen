// This is a roxen module. Copyright © 2000, Roxen IS.

#include <module.h>
inherit "module";

constant cvs_version = "$Id: roxen_test.pike,v 1.2 2000/11/11 06:23:10 nilsson Exp $";
constant thread_safe = 1;
constant module_type = MODULE_ZERO;
constant module_name = "Roxen self test module";
constant module_doc  = "Tests Roxen WebServer.";

Configuration conf;
object id;

void start(int n, Configuration c) {
  conf=c;
  id=MockID(c);
  call_out( do_tests, 2 );
  report_debug("Call out requested\n");
}

class MockID(Configuration conf) {
  mapping(string:mixed) misc=([ "defines":([ " _ok":1 ]) ]);
  mapping(string:string) cookies=([]);
  multiset(string) config=(<>);
  mapping(string:string) variables=([]);
  multiset(string) prestate=(<>);
  multiset(string) supports=(< "images" >);
  mapping(string:string) client_var=([]);

  array(string) pragma=({});
  array(string) client=({});

  string realfile="etc/roxen_test/filesystem/index.html";
  string not_query="/index.html";
  string raw_url="/index.html";
  string method="GET";
  string remoteaddr="10.0.1.23";

  object clone_me() {
    return MockID(conf);
  }

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
  Parser.HTML()->add_containers( ([ "rxml" : lambda(string t, mapping m, string c) { rxml=c; },
				    "result" : lambda(string t, mapping m, string c) { w_res=c; }
  ]) )->finish(c);

  mixed err = catch( a_res = Roxen.parse_rxml( rxml, id ));
  if(err) {
    fails++;
    lfails++;
    report_error("Test \"%s\"\nFailed (backtrace)\n",rxml);
    report_error("%s\n",describe_backtrace(err));
    return;
  }

  a_res = canon_html(a_res);

  if(a_res != w_res) {
    fails++;
    lfails++;
    report_error("Test \"%s\"\nFailed (%O != %O)\n", rxml, a_res, w_res);
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
  report_debug("Did %d tests, failes on %d tests.\n", ltests, lfails);
  if(ltests<sizeof(data/"</test>")-1) report_warning("Possibly XML error in testsuite.\n");
}


// --- Mission control ------------------------

void find_tests(string path) {
  report_debug("Looking for tests in %s\n",path);
  foreach(get_dir(path), string file)
    if(file!="CVS" && file_stat(path+file)[1]==-2)
      find_tests(path+file+"/");
    else if(file[-1]!='~' && glob("RoxenTest_*", file)) {
      report_debug("Found test file %s\n",path+file);
      if(glob("*.xml",file))
	run_xml_tests(Stdio.read_file(path+file));
    }
}

void do_tests() {

  if(roxen->start_time - time() < 2)
    call_out( do_tests, 2 );

  find_tests("modules/");

  roxen->shutdown(1.0);
}
