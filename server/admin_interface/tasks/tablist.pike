#include <admin_interface.h>

array pages =
({
  ({ "status",       "Tasks",  0, "Status"            }),
  ({ "maintenance",  "Tasks",  0, "Maintenance"       }),
#if constant(Crypto) && constant(Crypto.RSA)
  ({ ({"SSL"}),       "Tasks", 0, "SSL"               }),
#endif
/*({ "developer",     "Tasks", "devel_mode"  }),*/
  ({ "debug_info",    "Tasks", 0, "Debug information" }),
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

    res += "<tab "+ea+"href='?class="+s(page[0])+"'"+sel+">";
    res += page[3];
    res += "</tab>";
    res += tpost;
  }
  return res;
}
