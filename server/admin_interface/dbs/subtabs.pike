#include <admin_interface.h>

array pages =
({
  ({ "dbs",         "./", "View Settings", 0, "Databases" }),
  ({ "backups",      "backups.html",   "Edit Global Variables",   0,
     "Database Backups" }),
  ({ "status",      "status.html",   "View Settings",   0,  "MySQL status" }),
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

    res += "<tab "+ea+"href='"+page[1]+"'"+((page[1] == q)?" selected='1'":"")+">" +
      page[4]+"</tab>" + tpost;
  }

  return res;
}
