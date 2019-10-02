#include <roxen.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

array pages =
({
//({ "update",       "update.html",   "Update",     0, LOCALE(400, "Update")}),
  ({ "usersettings", "settings.html", 0,            0, LOCALE(220, "Your Settings") }),
  ({ "users",        "users.html",    "Edit Users", 0, LOCALE(221, "Users")}),
});

string parse( RequestID id )
{
  string q="";
  while( id->misc->orig )  id = id->misc->orig;
  sscanf( id->not_query, "/%s", q );
  if( q == "index.html" )
    q = "";
  if( q == "whatsnew.html" )
    q = "";
  string res="";
  foreach( pages, array page )
  {
    string tpost = "";
    if( page[2] )
    {
      res += "<cf-perm perm='"+page[2]+"'>";
      tpost = "</cf-perm>"+tpost;
    }
    if( page[3] )
    {
      res += "<cf-userwants option='"+page[3]+"'>";
      tpost = "</cf-userwants>"+tpost;
    }

    string ea="";
    if( page == pages[0] )       ea = "first ";
    if( page == pages[-1] )      ea = "last=30 ";

    res += "<tab "+ea+"href='"+page[1]+"'"+((page[1] == q)?" selected='1'":"")+">" +
      page[4]+"</tab>" + tpost;
  }

  return res;
}
