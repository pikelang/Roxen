#include <roxen.h>
#include <config_interface.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

//! Page definitions.
//! @array
//!   @elem array(string) 0..
//!     Page definition.
//!     @array
//!       @elem string 0
//!         Page identifier.
//!       @elem string 1
//!         URL.
//!       @elem string 2
//!         Permissions.
//!       @elem zero 3
//!         Userwants (disabled).
//!       @elem string 4
//!         Title.
//!     @endarray
//! @endarray
array pages =
({
  ({ "dbs",         "./", "View Settings", 0, LOCALE(164, "Databases") }),
  ({ "permissions", "permissions.html", "View Settings", 0,
     LOCALE(550, "Site Permissions") }),
  ({ "backups",      "backups.html",   "Edit Global Variables",   0,
     LOCALE(465, "Database Backups") }),
  ({ "schedules",    "schedules.html",   "Edit Global Variables",   0,
     LOCALE(1026, "Backup schedules") }),
#ifdef MORE_DB_OPTS
  ({ "maintenance", "maintenance.html", "Edit Global Variables", 0,
     "MySQL Maintenance" }),
#endif
  ({ "status",      "status.html",   "View Settings",   0,  LOCALE(372, "MySQL status") }),
});

string parse( RequestID id )
{
  string q="";
  while( id->misc->orig )  id = id->misc->orig;
  q = (id->not_query/"/")[-1];
  if( q == "index.html" || q == "browser.pike" || q == "edit_group.pike" )
    q = "./";
  if( q == "restore_db.pike" )
    q = "backups.html";
  string res="";
  foreach( pages, array page )
  {
    string tpost = "";
    if( page[2] )
    {
      if( !config_perm( page[2] ) )
	continue;
    }
//     if( page[3] )
//     {
//       res += "<cf-userwants option='"+page[3]+"'>";
//       tpost = "</cf-userwants>"+tpost;
//     }

    string ea="";
    if( page == pages[0] )       ea = "first ";
    if( page == pages[-1] )      ea = "last=30 ";

    res += "<a "+ea+"href='"+page[1]+"'"+((page[1] == q)?" selected='1'":"")+">" +
      page[4]+"</a>" + tpost;
  }

  return res;
}
