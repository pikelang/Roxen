// This is a roxen module.

#include <module.h>
inherit "module";

constant cvs_version = "$Id: repositoryfs.pike,v 1.7 2005/02/10 23:12:00 _cvs_dirix Exp $";
constant thread_safe = 1;

constant module_type = MODULE_LOCATION;
constant module_name = "File systems: Repository fs";
constant module_doc = "CVS repository file system";
constant module_unique = 0;

void create()
{
  defvar( "location", "/",
    "Mount point", TYPE_LOCATION|VAR_INITIAL,
    "Where the module will be mounted in the site's virtual file "
    "system." );

  defvar("repository", "/cvsroot",
    "Path to repository", TYPE_DIR|VAR_INITIAL,
    "The path to the CVS repository or a subdirectory in it.");
}

string mid;
string rep;

void start() {
  mid = module_identifier();
  rep = query("repository");
}

string query_name()
{
  return query("location")+" from "+query("repository");
}

Stat stat_file( string f, RequestID id )
{
  Stdio.Stat s = file_stat(rep+f);
  if(!s)
    s = file_stat(rep+f+",v");
  if(!s)
    return 0;
  //  s->size = 0;
  return s;
}

string real_file( string f, RequestID id )
{
  return 0;
}

array find_dir( string f, RequestID id )
{
  array dir = get_dir(rep+f);
  if(!dir) return 0;
  dir = map(dir, lambda(string file) {
		   sscanf(file, "%s,v", file);
		   return file; });
  return dir;
}

int|Stdio.FakeFile find_file( string f, RequestID id )
{
  f = query("repository")+f;
  Stdio.Stat s = file_stat(f);
  if(!s) {
    f += ",v";
    s = file_stat(f);
  }
  else {
    if( s->isdir )
      return -1;
    return 0; // Strange...
  }

  if(!s) return 0;

  Stdio.FakeFile res = cache_lookup( "repositoryfs", f );
  if(res) return res;
  Parser.RCS p = Parser.RCS(f);
//  string content = p->revisions[p->head]->get_contents_for_revision();
  string content = p->get_contents_for_revision(p->revisions[p->head]);
  s->size = sizeof(content);
  res = Stdio.FakeFile(content , "r" );
  cache_set( "repositoryfs", f, res );
  return res;
}
