/* $Id: fonts.pike,v 1.7 1997/06/12 00:28:19 grubba Exp $ */

#include <module.h>

import Image;
constant Font = Image.font;

string fix_name(string in)
{
  return replace(lower_case(in), ({"-"," "}), ({ "_", "_" }));
}



string make_font_name(string name, int size, int bold, int italic)
{
  string base_dir;
  mixed available;
  if(file_stat(name)) return name;
  base_dir = roxen->QUERY(font_dir)+"/"+size+"/"+fix_name(name);
  if(!(available = get_dir(base_dir)))
  {
    base_dir=roxen->QUERY(font_dir)+"/"+roxen->QUERY(default_font_size)+"/"+fix_name(name);
    if(!(available = get_dir(base_dir)))
    {
      base_dir=roxen->QUERY(font_dir)+"/"+roxen->QUERY(default_font_size)+"/"+roxen->QUERY(default_font);
      if(!(available = get_dir(base_dir)))
	return 0;
    }
  }

  string bc=(bold>=0?(bold==2?"B":(bold==1?"b":"n")):"l"), ic=(italic?"i":"n");
  
  available = mkmultiset(available);
  if(available[bc+ic]) return base_dir+"/"+bc+ic;
  if(bc=="B") bc="b";
  if(available[bc+ic]) return base_dir+"/"+bc+ic;
  if(bc=="B") bc="n";
  if(available[bc+ic]) return base_dir+"/"+bc+ic;
  if(ic=="i") ic="n";
  if(available[bc+ic]) return base_dir+"/"+bc+ic;

  foreach(({ "B", "b", "n", "l" }), bc)
    foreach(({ "i", "n" }), ic)
      if(available[bc+ic]) return base_dir+"/"+bc+ic;
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
    if(!fnt->load( name )) {
      perror("Failed to load the font "+name+", using the default font.\n");
      if(!fnt->load("fonts/"+roxen->QUERY(default_font_size) +"/"+
		    roxen->QUERY(default_font)))
	return 0;
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
}
