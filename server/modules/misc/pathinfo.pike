// This is a roxen module. Copyright © 1998 - 2000, Roxen IS.

inherit "module";

constant cvs_version = "$Id: pathinfo.pike,v 1.11 2000/03/16 18:57:14 nilsson Exp $";
constant thread_safe = 1;

#ifdef PATHINFO_DEBUG
# define PATHINFO_WERR(X) werror("PATHINFO: "+X+"\n");
#else
# define PATHINFO_WERR(X)
#endif

constant module_type = MODULE_LAST;
constant module_name = "PATH_INFO support";
constant module_doc  = "Support for PATH_INFO style URLs.";

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
    if( strlen( pi ) )
      pi = "/"+reverse( add_path_info )+pi;
    else
      pi = "/"+add_path_info;
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
