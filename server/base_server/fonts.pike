/* $Id: fonts.pike,v 1.14 1997/09/05 22:35:09 per Exp $ */

#include <module.h>

import Image;
constant Font = Image.font;

string fix_name(string in)
{
  return replace(lower_case(in), ({"-"," "}), ({ "_", "_" }));
}

array available_font_versions(string name, int size)
{
  string base_dir, dir;
  array available;
  foreach(roxen->QUERY(font_dirs), dir)
  {
    base_dir = dir+size+"/"+fix_name(name);
    if((available = get_dir(base_dir)))
      break;
    base_dir=dir+"/"+roxen->QUERY(default_font_size)+"/"+fix_name(name);
    if((available = get_dir(base_dir)))
      break;
    base_dir=dir+"/"+roxen->QUERY(default_font_size)+"/"+roxen->QUERY(default_font);
    if((available = get_dir(base_dir)))
      break;
  }
  if(!available) return 0;
  return available;
}

string describe_font_type(string n)
{
  string res;
  if(n[1]=='i') res = "italic";
  else res="";

  switch(n[0])
  {
   case 'n': if(!strlen(res)) res="normal"; break;
   case 'B': res+=" black";  break;
   case 'b': res+=" bold";  break;
   case 'l': res+=" light";  break;
  }
  return res;
}

array get_font_italic_bold(string n)
{
  int italic,bold;
  if(n[1]=='i') italic = 1;

  switch(n[0])
  {
   case 'B': bold=2; break;
   case 'b': bold=1; break;
   case 'l': bold=-1;  break;
  }
  return ({ italic, bold });
}

string make_font_name(string name, int size, int bold, int italic)
{
  string base_dir, dir;
  mixed available;
  if(file_stat(name)) return name;
  foreach(roxen->QUERY(font_dirs), dir)
  {
    base_dir = dir+size+"/"+fix_name(name);
    if((available = get_dir(base_dir)))
      break;
    base_dir=dir+"/"+roxen->QUERY(default_font_size)+"/"+fix_name(name);
    if((available = get_dir(base_dir)))
      break;
    base_dir=dir+"/"+roxen->QUERY(default_font_size)+"/"+roxen->QUERY(default_font);
    if((available = get_dir(base_dir)))
      break;
  }
  if(!available) return 0;

  string bc=(bold>=0?(bold==2?"B":(bold==1?"b":"n")):"l"), ic=(italic?"i":"n");
  
  available = mkmultiset(available);
  if(available[bc+ic]) return base_dir+"/"+bc+ic;
  if(bc=="l") bc="n";
  if(available[bc+ic]) return base_dir+"/"+bc+ic;
  if(bc=="B") bc="b";
  if(available[bc+ic]) return base_dir+"/"+bc+ic;
  if(bc=="b") bc="n";
  if(available[bc+ic]) return base_dir+"/"+bc+ic;
  if(ic=="i") ic="n";
  if(available[bc+ic]) return base_dir+"/"+bc+ic;

  foreach(({ "n","l","b", "B", }), bc)
    foreach(({ "n", "i" }), ic)
      if(available[bc+ic])
	return base_dir+"/"+bc+ic;
  return 0;
}

object get_font(string f, int size, int bold, int italic,
		string justification, float xspace, float yspace)
{
  object fnt;
  string key, name;

  catch {
    name=make_font_name(f,size,bold,italic);
    key=name+"/"+justification+"/"+xspace+"/"+yspace;

    if(fnt=cache_lookup("fonts", key))
      return fnt;
    else
      fnt = Font();
    if(!fnt->load( name ))
    {
      report_debug("Failed to load the font "+name+", using the default font.\n");
      if(!fnt->load(make_font_name(roxen->QUERY(default_font),
				   roxen->QUERY(default_font_size),
				   bold, italic)))
      {
	report_error("Failed to load the default font.\n");
	return 0;
      }
    }
    if(justification=="right") fnt->right();
    if(justification=="center") fnt->center();
    fnt->set_x_spacing((100.0+(float)xspace)/100.0);
    fnt->set_y_spacing((100.0+(float)yspace)/100.0);
    cache_set("fonts", key, fnt);
    return fnt;
  };
  // Error if the font-file is not really a font-file...
  return 0;
}

void create()
{
  add_constant("get_font", get_font);
  add_constant("available_font_versions", available_font_versions);
  add_constant("describe_font_type", describe_font_type);
  add_constant("get_font_italic_bold", get_font_italic_bold);
}
