constant cvs_version = "$Id: old.pike,v 1.1 2000/09/03 02:33:01 per Exp $";

constant name = "Compatibility bitmap fonts";
constant doc = "Compatibility (bitmapped) fonts for Roxen 1.3 and earlier.";

inherit FontHandler;


array available_fonts()
{
  array res = ({});
  foreach(roxen->query("font_dirs"), string dir)
  {
    dir+="32/";
    if(array d = r_get_dir(dir))
    {
      foreach(d,string f)
      {
        if(f=="CVS") continue;
        Stat a;
        if((a=r_file_stat(dir+f)) && (a[1]==-2)) 
        {
	  array d=r_get_dir(dir+f);
	  foreach( ({ "nn", "ni", "li", "ln", "Bi", "Bn", "bi", "bn" }),
		   string style)
	    if(has_value(d, style)) 
            {
              res |= ({ replace(f,"_", " ") });
              break;
            }
        }
      }
    }
  }
  return res;
}

mapping font_information( string fnt )
{
  int styles;
  string path_found;
  foreach(roxen->query("font_dirs"), string dir)
  {
    dir+="32/";
    if( r_file_stat( dir+fnt ) )
      /* the font file exists in this dir.. */
    {
      array d = r_get_dir(dir+fnt);
      foreach( ({ "nn", "ni", "li", "ln", "Bi", "Bn", "bi", "bn" }),
               string style)
        if(has_value(d, style)) 
        {
          path_found = dir+fnt;
          styles++;
        }
    }
  }
  if(!styles) return 0;
  return ([ "name":fnt,
             "path":path_found,
             "styles":styles,
             "ttf":"no" ]);
}

string fix_name( string what )
{
  return replace( lower_case(what), " ", "_" );
}

array has_font( string name, int size )
{
  string base_dir;
  array available;
  foreach(roxen->query("font_dirs"), string dir)
  {
    base_dir = dir+size+"/"+fix_name(name);
    if((available = r_get_dir(base_dir))) break;
    base_dir=dir+"/32/"+fix_name(name);
    available = r_get_dir(base_dir);
  }
  if(!available) return 0;
  return available - ({ "CVS" });
}

Font open( string name, int size, int bold, int italic )
{
  string f = make_font_name( name, size, bold, italic );
  Image.Font fn = Image.Font();
  foreach( roxen->query( "font_dirs"), string dir )
    foreach( ({ size, 32 }), int sz )
    {
      if( r_file_stat( dir+"/"+sz+"/"+f ) )
      {
        if( fn->load( roxen_path( dir+"/"+sz+"/"+f ) ) )
          return fn;
      }
    }
}
