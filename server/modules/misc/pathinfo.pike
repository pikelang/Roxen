/*
 * $Id: pathinfo.pike,v 1.3 1999/03/25 22:01:22 grubba Exp $
 *
 * PATH_INFO support for Roxen.
 *
 * Henrik Grubbström 1998-10-01
 */

#include <module.h>

inherit "module";

constant cvs_version = "$Id: pathinfo.pike,v 1.3 1999/03/25 22:01:22 grubba Exp $";
constant thread_safe = 1;

// #define PATHINFO_DEBUG

array register_module()
{
  return ({ MODULE_LAST, "PATH_INFO support",
	    "Support for PATH_INFO style URLs.",
	    0, 1 });
}

mapping|int last_resort(object id)
{
#ifdef PATHINFO_DEBUG
  roxen_perror(sprintf("PATHINFO: Checking %O...\n", id->not_query));
#endif /* PATHINFO_DEBUG */
  if (id->misc->path_info) {
    // Already been here...
#ifdef PATHINFO_DEBUG
    roxen_perror(sprintf("PATHINFO: Been here, done that.\n"));
#endif /* PATHINFO_DEBUG */
    return 0;
  }

  string query = id->not_query;
  array(int) offsets = Array.map(query/"/", sizeof);

  int sum = 0;
  int i;
  for (i=0; i < sizeof(offsets); i++) {
    sum = (offsets[i] += sum) + 1;
  }

  int lo = (offsets[0] != 0);	// Skip testing the empty string.
  int hi = sizeof(offsets) - 1;

  while(lo <= hi) {		// Don't let the beams cross.
    int probe = (lo + hi)/2;
    string file = query[..offsets[probe]-1];

#ifdef PATHINFO_DEBUG
    roxen_perror(sprintf("PATHINFO: Trying %O...\n", file));
#endif /* PATHINFO_DEBUG */

    /* Note: Zapps id->not_query. */
    array st = id->conf->stat_file(file, id);
    if (st) {
      if (st[1] >= 0) {
	// Found a file!
	id->misc->path_info = query[offsets[probe]..];
	id->not_query = file;
#ifdef PATHINFO_DEBUG
	roxen_perror(sprintf("PATHINFO: Found: %O:%O\n",
			     id->not_query, id->misc->path_info));
#endif /* PATHINFO_DEBUG */
	return 1;	// Go through id->handle_request() one more time...
      }
#ifdef PATHINFO_DEBUG
      roxen_perror(sprintf("PATHINFO: Directory: %O\n", file));
#endif /* PATHINFO_DEBUG */

      lo = probe + 1;
    } else {
      hi = probe - 1;
    }
  }
  /* not_query is zapped by id->conf->stat_file(). */
  id->not_query = query;
  return 0;
}
