// This is a roxen module. Copyright © 1998 - 2000, Roxen IS.

inherit "module";

constant cvs_version = "$Id: pathinfo.pike,v 1.12 2000/03/20 03:05:56 mast Exp $";
constant thread_safe = 1;

#ifdef PATHINFO_DEBUG
# define PATHINFO_WERR(X) werror("PATHINFO: "+X+"\n");
#else
# define PATHINFO_WERR(X)
#endif

constant module_type = MODULE_LAST;
constant module_name = "Path info support";
constant module_doc  = #"\
Support for \"path info\" style URLs, e.g. URLs that got a path like
<tt>/index.html/a/b</tt>, where <tt>/index.html</tt> is an existing
file, but <tt>/index.html/a</tt> and <tt>/index.html/a/b</tt> aren't.
In this case <tt>/index.html</tt> will be fetched, and the rest,
<tt>/a/b</tt> is made available in the RXML variable page.pathinfo.";

mapping|int last_resort(object id)
{
  PATHINFO_WERR(sprintf("Checking %O...", id->not_query));
  if (id->misc->path_info) {
    // Already been here...
    PATHINFO_WERR(sprintf("Been here, done that."));
    return 0;
  }

  string query = id->not_query;
  string pi = "";
  while( (search( query[1..], "/" ) != -1) && strlen( query ) > 0 )
  {
    query = reverse(query);
    string add_path_info;
    sscanf( query, "%[^/]/%s", add_path_info, query );
    query = reverse( query );
    pi = "/"+reverse( add_path_info )+pi;
    id->misc->path_info = pi;
    PATHINFO_WERR(sprintf("Trying: %O (%O)", query, pi));
    array st = id->conf->stat_file( query, id );
    if( st && (st[ ST_SIZE ] > 0))
    {
      id->not_query = query;
      PATHINFO_WERR(sprintf("Found: %O:%O",
			    id->not_query, id->misc->path_info));
      return 1;
    }
  }
  return 0;
}
