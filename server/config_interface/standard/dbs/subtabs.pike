#include <roxen.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

array pages =
({
  ({ "status",      "",   "View Settings",   0, LOCALE(372, "MySQL status")}),
  ({ "dbs",   "dbs.html", "Edit Global Variables", 0, LOCALE(373, "Other DBs") }),
});

string parse( RequestID id )
{
  string q="";
  while( id->misc->orig )  id = id->misc->orig;
  q = (id->not_query/"/")[-1];
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
