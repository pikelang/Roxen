// The Tab lists tag module.
string cvs_version = "$Id: tablist.pike,v 1.12 1999/01/15 12:35:02 neotron Exp $";
#include <module.h>

inherit "module";
inherit "roxenlib";

import Array;
import Image;

//constant Image = image;
constant Font = font;

#define DEFAULT_FONT "32/urw_itc_avant_garde-demi-r"
#define DEFAULT_PATH "fonts/"

// #define DEBUG_TABLIST

string *from=map(indices(allocate(256)),lambda(int l) { return sprintf("%c",l); });
string *to=map(indices(allocate(256)),lambda(int l) {
  switch(l)
  {
    case 0: return "-";
    case 'a'..'z':
    case '.':
    case ':':
    case 'A'+16..'Z':
    case '0'..'9': return sprintf("%c",l);
    default: return sprintf("%c%c",'A'+(l>>4),'A'+(l&15));
  }
});

string make_filename(mapping arguments)
{
  string s = encode_value(arguments);
  return replace(s,from,to);
}

mapping make_arguments(string filename)
{
  filename=replace(filename,to,from);
  
  return decode_value(filename);
}

void draw_bg(object img, array (int) bg, array (int) tc)
{
  img->tuned_box(0, 0, img->xsize()-1, 7, ({
		 ({ @bg }),
		 ({ @bg }),
		 ({ @map(tc, `/, 7) }),
		 ({ @map(tc, `/, 7) }) }) );
  img->line(0, 8, img->xsize()-1, 8, 0,0,0);
  img->box(0, 9, img->xsize()-1, img->ysize()-12, @tc);
  img->tuned_box(0, img->ysize()-11, img->xsize()-1, img->ysize()-1, ({
                 ({ @tc }),
		 ({ @tc }),
		 ({ @map(bg, `/, 3) }),
		 ({ @map(bg, `/, 3) }) }) );
  img->line(0, img->ysize()-1, img->xsize()-1, img->ysize()-1, 0,0,0);
}

void right_shadow(object img, array (int) tc)
{
  int i;

  float dr = (6*((float) tc[0])/7)/10;
  float dg = (6*((float) tc[1])/7)/10;
  float db = (6*((float) tc[2])/7)/10;
  float tr = (float) tc[0]/7;
  float tg = (float) tc[1]/7;
  float tb = (float) tc[2]/7;
  for (i = 0; i < 10; i++) {
    tr += dr; tg += dg; tb += db;
    img->line(img->xsize()-15+i, 9, img->xsize()-5-1+i/2, img->ysize()-1-i,
	      (int)tr,(int)tg,(int)tb);
    img->line(img->xsize()-14+i, 9, img->xsize()-5-1+i/2, img->ysize()-1-i,
	      (int)tr,(int)tg,(int)tb);
  }
}

void right_selected(object img, array (int) bg)
{
  int y;
  float x = img->xsize()-1;
  float dx = ((float) 13)/((float) img->ysize());
  for (y = 9; y < img->ysize(); y++) {
    img->line((int) x, y, img->xsize()-1, y, @bg);
    x -= dx;
  }
  img->line(img->xsize()-1, 9, img->xsize()-13, img->ysize()-1, 0,0,0);
  img->line(img->xsize()-2, 9, img->xsize()-13, img->ysize()-1, 0,0,0);
}

void selected(object img, array (int) bg)
{
  int y;
  float x = ((float) img->xsize()) - 14.0;
  float dx = ((float) 10)/((float) img->ysize());
  for (y = 9; y < img->ysize(); y++) {
    img->line(0, y, (int) x, y, @bg);
    x += dx;
  }
}

void left_end(object img, array (int) bg)
{
  int y;
  float x = (float) 15;
  float dx = ((float) x)/((float) img->ysize());
  for (y = 0; y < img->ysize()-1; y++) {
    img->line(0, y, (int) x, y, @bg);
    x -= dx;
  }
  img->line(15, 9, 0, img->ysize()-1, 0,0,0);
  img->line(14, 9, 0, img->ysize()-1, 0,0,0);
}

void right_end(object img, array (int) bg)
{
  int y;
  float x = 0.0;
  float dx = ((float) 13)/((float) img->ysize());
  for (y = 0; y < img->ysize()-1; y++) {
    img->line(img->xsize()-13 + (int) x, y, img->xsize()-1, y, @bg);
    x += dx;
  }
  right_shadow(img, bg);
}

object tab(string name, int select, int n, int last, string font,
	   array (int) bg, array (int) tc, array (int) fc)
{
  int w_spacing = 40+20;
  int h_spacing = 20+5;
  object fnt, txt, img, tmp;
  int width, height;

#ifdef DEBUG_TABLIST
  perror("Creating tab \"" + name + (select==n?"\" (selected)\n":"\"\n"));
#endif

  fnt = Font();
  if (!fnt->load(font)) {
     perror("Could not load font \"" + font + "\"\n");
     fnt->load(DEFAULT_PATH DEFAULT_FONT);
  }
  txt = fnt->write(name);
#ifdef DEBUG_TABLIST
  perror((sprintf("Font image size: %d × %d\n",txt->xsize(),txt->ysize())));
#endif
  width = txt->xsize() + w_spacing;
  height = txt->ysize() + h_spacing;

  img = image(width,height);
  draw_bg(img, bg, tc);
  if (n == select)
    selected(img, bg);
  if (n+1 == select)
    right_selected(img, bg);
  if (n == last)
    right_end(img, bg);
  else if (n+1 != select)
    right_shadow(img, tc);

  if ((txt->xsize()) && (txt->ysize())) {
    tmp=image(txt->xsize(), txt->ysize());
    tmp->box(0, 0, tmp->xsize()-1, tmp->ysize()-1, @fc);
    img->paste_mask(tmp, txt, w_spacing/3, h_spacing/2);
  }

  if (!n)
    left_end(img, bg);
  
  return img;
}

array register_module()
{
  return ({
    MODULE_PARSER | MODULE_LOCATION,
      "Tab lists",
      ("This module makes graphical tablists.<p>"
       "<b>NOTE:</b> This module is not supported and is only here "
       "for compatibility reasons. Please use ``<b>Config tab-list</b>'' "
       "instead.<p>"
#if 0
       "<p> It defines the tag "
       "&lt;tablist&gt;.<p>"
       "Arguments:\n<br>"
       "font=string: Select font<br>\n"
       "1= 2= 3= ...: Set the destination for one of the tags<br>\n"
       "bg=#rrggbb: Set background color<br>\n"
       "tc=#rrggbb: Set tab color<br>\n"
       "fc=#rrggbb: Set font color<br>\n"
       "scale=<float>: Scale the result<br>\n"
       "names=foo;bar;gazonk: Set the text on the tabs, separated by ';'<br>\n"
       "selected=<int>: Select which tab to select<br>\n"
#endif
       ""),
    0, 1,
      });
}

void create()
{
  defvar("foo", "/tablists/", "mount point", TYPE_LOCATION|VAR_MORE, "");
  defvar("fontpath", DEFAULT_PATH, "font path", TYPE_DIR|VAR_MORE, "");
  defvar("defaultfont", DEFAULT_FONT, "default font", TYPE_FILE|VAR_MORE, "");
}

string query_location()
{
  return query("foo");
}

mapping find_file(string filename, object request_id)
{
  string s;
  if(s = cache_lookup("tabs", filename))
    return http_string_answer(s, "image/gif");

  mapping arguments = make_arguments(filename);
  int n = (int) arguments->n;
  int last = (int) arguments->last;
  string name = (string) (arguments->name || "");
  int selected = ((int) arguments->selected) || 1;
  selected--;

  float scale = 0.5;
  if ((float) arguments->scale > 0)
    scale *= (float) arguments->scale;

  string font = (string) (arguments->font || query("defaultfont"));
  if (font[0] != '/') font = query("fontpath") + font;
  array (int) bg = parse_color(arguments->bg||"#c0c0c0");  // Background color
  array (int) tc = parse_color(arguments->tc||"#d6c69c");  // Tab color
  array (int) fc = parse_color(arguments->fc||"#000000");  // Font color

  s = tab(name, selected, n, last, font, bg, tc, fc)->scale(scale)->togif(@bg);
  cache_set("tabs", filename, s);
  return http_string_answer(s, "image/gif");
}

string tag_tablist(string tag_name, mapping arguments, object request_id)
{
  int n = 0;
  string s, name;

  array (string) names = ((string) arguments->names)/";";
  arguments[ "last" ] = sizeof(names)-1;
  s = "<table cellspacing=0 cellpadding=0 border=0><tr>";
  foreach(names, name) {
    arguments[ "name" ] = name;
    arguments[ "n" ] = (string) n++;
    s += "<td>";
    if (arguments[(string) n])
      s += "<a href=\""+(arguments[(string) n]?arguments[(string) n]:"")+"\">"+
	   "<img border=0 "
	   "alt=\""+((n==1||(n==(int)arguments->selected))?"/":"")+name+
 	    ((n+1==(int)arguments->selected)?"":"\\")+"\" "+
	   "src="+query_location()+make_filename(arguments)+"></a>";
    else
      s += "<img border=0 "
	   "alt=\""+((n==1||(n==(int)arguments->selected))?"/":"")+name+
	    ((n+1==(int)arguments->selected)?"":"\\")+"\" "+
	   "src="+query_location()+make_filename(arguments)+">";
    s += "</td>";
  }
  s += "</tr></table>";
  return s+"\n";
}

mapping query_tag_callers()
{
  return ([ "tablist":tag_tablist, ]);
}
