array pages =
({
  ({ "welcome",     "",                0,               0             }),
  ({ "usersettings","settings.html",   0,               0             }),
  ({ "users",       "users.html",      "Edit Users",    0             }),
  ({ "debug_info",  "debug_info.html", "View Settings", "devel_mode"  }),
});

string parse(object id)
{
  string q="";
  while( id->misc->orig )  id = id->misc->orig;
  sscanf( id->not_query, "/%*s/%s", q );
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

    res += "<tab "+ea+"href='"+page[1]+"'"+((page[1] == q)?" selected":"")+">";
    res += "<cf-locale get="+page[0]+">";
    res += "</tab>";
    res += tpost;
  }
  return res;
}
