array pages =
({
  ({ "status",            "Tasks",               0             }),
  ({ "maintenance",       "Tasks",               0             }),
  ({ "developer",         "Tasks",               "devel_mode"  }),
  ({ "debug_info",        "Tasks",               0             }),
});

string parse(object id)
{
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

    res += "<tab "+ea+"href='?class="+page[0]+"'"+((page[0] == q)?" selected":"")+" preparse>";
    res += "<cf-locale get="+page[0]+">";
    res += "</tab>";
    res += tpost;
  }
  return res;
}
