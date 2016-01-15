#include <roxen.h>
#include <config_interface.h>

//<locale-token project="admin_tasks"> LOCALE </locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("admin_tasks",X,Y)

array pages =
({
  ({ "status",       "Tasks",  0, LOCALE(228,"Status")            }),
  ({ "maintenance",  "Tasks",  0, LOCALE(229,"Maintenance")       }),
#if constant (Nettle)
  ({ ({"SSL"}),       "Tasks", 0, LOCALE(230,"SSL")               }),
#endif
/*({ "developer",     "Tasks", "devel_mode"  }),*/
  ({ "debug_info",    "Tasks", 0, LOCALE(231,"Debug Information") }),
});

string parse( RequestID id )
{
  if( !config_setting2("group_tasks") )
    return "";

  string q=id->variables["class"];
  string res="";
  if( !q ) q = "status";

  foreach( pages, array page )
  {
    string tpost = "";
    if( page[1] )
    {
      res += "<cf-perm perm='"+page[1]+"'>";
      tpost = "</cf-perm>"+tpost;
    }
    if( page[2] )
    {
      res += "<cf-userwants option='"+page[2]+"'>";
      tpost = "</cf-userwants>"+tpost;
    }

    string ea="";
    if( page == pages[0] )       ea = "first ";
    if( page == pages[-1] )      ea = "last=30 ";

    string s( mixed q )
    {
      if( arrayp( q ) ) return q[0];
      return q;
    };

    string sel = (s(page[0])==q?" selected":"");

    res += "<tab "+ea+"href='?class="+s(page[0])+"&amp;&usr.set-wiz-id;'"+sel+">";
    res += page[3];
    res += "</tab>";
    res += tpost;
  }
  return res;
}
