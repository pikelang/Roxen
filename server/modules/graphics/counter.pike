//
// Roxen Graphic Counter Module	by Jordi Murgo <jordi@lleida.net>
// Modifications  1 OCT 1997 by Bill Welliver <hww3@riverweb.com>
// Optimizations 22 FEB 1998 by David Hedbor <david@hedbor.org>
// Optimizations 11 DEC 1999 by Martin Nilsson <nilsson@idonex.se>
//
// -----------------------------------------------------------------------
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
//
// -----------------------------------------------------------------------
//

constant cvs_version = "$Id: counter.pike,v 1.27 1999/12/11 20:37:31 nilsson Exp $";

constant copyright = ("<br>Copyright 1997-1999 "
		    "<a href=http://savage.apostols.org/>Jordi Murgo</a> and "
		    "<a href=http://www.lleida.net/>"
		    "Lleida Networks Serveis Telematics, S.L.</a> Roxen 1.2 "
		    "support by <a href=http://www.riverweb.com/~hww3>"
		    "Bill Welliver</a>. Heavily optimized by <a href="
		    "http://david.hedbor.org/>David Hedbor</a>.");

#include <module.h>
inherit "module";
inherit "roxenlib";

constant thread_safe = 1;

#define MAX( a, b )	( (a>b)?a:b )


// --------------------- Module Definition ----------------------

void start( int num, Configuration conf )
{
  module_dependencies (conf, ({ "accessed" }));
}

array register_module()
{
  return ({ MODULE_PARSER | MODULE_PROVIDER, "Graphical Counter",
    "Generates graphical counters.", 0, 1 });
}

void create()
{
  defvar("ppmpath", "etc/digits/", "PPM GIF Digits Path", TYPE_DIR,
	 "Were are located PPM/GIF digits (Ex: 'digits/')");

  defvar("userpath", "html/digits/", "PPM GIF path under Users HOME", TYPE_STRING,
	 "Where are users PPM/GIF files (Ex: 'html/digits/')<BR>Note: Relative to users $HOME" );

  defvar("ppm", "a", "Default PPM GIF-Digit style", TYPE_STRING,
	 "Default PPM/GIF-Digits style for counters (Ex: 'a')");
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=(["counter":"","counter_url":""]);
/*
    "         border=...                 | like &lt;IMG BORDER=...\n"
    "         bordercolor=...            | Changes the color of the border, if\n"
    "                                    | the border is enabled.\n"
    "         align=[left|center|right]  | like &lt;IMG ALIGN=...\n"
    "         width=...                  | like &lt;IMG WIDTH=...\n"
    "         height=...                 | like &lt;IMG HEIGHT=...\n"
    "         cheat=xxx                  | Add xxx to the actual number of accesses.\n"
    "         factor=...                 | Modify the number of accesses by factor/100, \n"
    "                                    | that is, factor=200 means 5 accesses will\n"
    "                                    | be seen as 10.\n"
    "         file=xx                    | Show the number of times the file xxx has \n"
    "                                    | been accessed instead of current page.\n"
    "         prec=...                   | Number of precision digits. If prec=2\n"
    "         precision=...              | show 1500 instead of 1543 \n"
    "         add                        | Add one to the number of accesses \n"
    "                                    | of the file that is accessed, or, \n"
    "                                    | in the case of no file, the current\n"
    "                                    | document. \n"
    "         reset                      | Reset the counter.\n"
    "         per=[second|minute|        | Access average per unit of time.\n"
    "         hour|day|week|month]       | \n"
    "         size=[1..10]               | 2.5=half, 5=normal, 10=double\n"
    "         len=[1..10]                | Number of Digits (1=no leading zeroes)\n"
    "         rotate=[-360..360]         | Rotation Angle \n"
    "         fg=#rrggbb                 | Foreground Filter\n"
    "         bg=#rrggbb                 | Bakground Color\n"
    "         trans                      | make Background transparent\n"
    "         user=\"user\"                | Search 'stylename' in user directory\n"
    "         style=\"stylename\"          | Cool PPM font name (default style=a)\n"
    "         nfont=\"fontname\" &gt;          | Standard NFONT name\n</pre>",
*/
#endif

//
// This module provides "counter", and can easily be found with the
// provider functions in configuration.pike.
//
string query_provides() { return "counter"; }

//
//  Show a selectable Font list
//
mapping fontlist(string bg, string fg, int scale)
{
  array  fnts;
  scale=scale/5;
  string out =
    "<html><head><title>Available Counter Fonts</title></head>"
    "<body bgcolor=\"#ffffff\" text=\"#000000\">\n"
    "<h2>Available Graphic Counter Fonts</h2><hr>"+
    cvs_version + "<br>" + copyright + "<hr>";

  catch( fnts=sort(roxen->available_fonts(1)) );
  if( fnts ) {
    out += "<b>Available Fonts:</b><menu>";
    for(int i=0; i<sizeof(fnts); i++ ) {
      out += "<a href='" + query_internal_location()+
             "0/" + bg + "/" + fg +"/0/1/" + (string)scale +
             "/0/" + http_encode_string(fnts[i]) +
             "/1234567890.gif'>" + fnts[i] + "</a><br>\n";
    }
    out += "</dl>";
  } else {
    out += "Sorry, No Available Fonts";
  }

  out += "<hr>" + copyright + "</body></html>";

  return http_string_answer( out );
}

//
// Show a selectable Cool PPM list
//
mapping ppmlist(string font, string user, string dir)
{
  array  fnts;
  string out =
    "<html><head><title>Cool PPM/GIF Font not Found</title></head>"
    "<body bgcolor=\"#ffffff\" text=\"#000000\">\n"
    "<h2>Cool PPM Font '"+font+"' not found!!</h2><hr>"+
    cvs_version + "<br>" + copyright + "<hr>";

  catch( fnts=sort(get_dir( dir ) - ({".",".."})) );
  if( fnts ) {
    out += "<b>Available Digits:</b><dl>";
    string initial="";
    int totfonts=0;
    for(int i=0; i<sizeof(fnts); i++ ) {
      if( initial != fnts[i][0..0] ) {
	initial = fnts[i][0..0];
	out += "<dt><font size=+1><b> ["+ initial +"]</b></font>\n<dd>";
      }
      out +=
	"<a href='" +query_internal_location()+ user + "/n/n/0/0/5/0/"+ http_encode_string(fnts[i]) +
	"/1234567890.gif'>" + fnts[i] + "</a> \n";
      totfonts++;
    }
    out += "</dl>Total Digit Styles : " + totfonts;
  } else {
    out += "Sorry, No Available Digits";
  }

  out+= "<hr>" + copyright + "</body></html>";

  return http_string_answer( out );
}

//
// Generation of Standard Font Counters
//
mapping find_file_font( string f, RequestID id )
{
  string fontname, fg, bg, counter;
  int len, trans, type, rot;
  float scale;

  if(sscanf(f, "%d/%s/%s/%d/%d/%f/%d/%s/%s.%*s",
	    type, bg, fg, trans, len, scale, rot,
	    fontname, counter) != 10 )
    return 0;

  if(fontname=="ListAllFonts")
    return fontlist(bg,fg,(int)(scale*5.0));

  scale /= 5;
  if( scale > 2.0 )
    scale = 2.0;

  Image.Font fnt;
  fnt=get_font(fontname, 32 ,0, 0, "left", 0, 0);

  if(!fnt)
    return fontlist(bg,fg,(int)(scale*5.0));
  while(strlen(counter) < len)
    counter = "0" + counter;

  Image.Image txt  = fnt->write(counter);
  Image.Image img  = Image.image(txt->xsize(), txt->ysize(), @parse_color(bg));

  if(scale != 1)
    if(rot)
      img = img->paste_alpha_color( txt, @parse_color(fg) )->scale(scale)
	->rotate(rot, @parse_color(bg));
    else
      img = img->paste_alpha_color( txt, @parse_color(fg) )->scale(scale);
  else if(rot)
    img = img->paste_alpha_color( txt, @parse_color(fg) )->rotate(rot,
							      @parse_color(bg));
  else
    img = img->paste_alpha_color( txt, @parse_color(fg) );

  string key = bg+":"+fg;

  // Making the color table is slow. Therefor we cache it.
  Image.Colortable ct = cache_lookup("counter_coltables", key);
  if(!ct) {
    ct = Image.colortable(img, 32)->cubicles(20,20,20);
    cache_set("counter_coltables", key, ct);
  }

  if(trans)
    return http_string_answer(Image.GIF.encode_trans(img, ct, @parse_color(bg)),
			      "image/gif");
  else
    return http_string_answer(Image.GIF.encode(img, ct),"image/gif");
}

//
// Generation of Cool PPM/GIF Counters
//
mapping find_file_ppm( string f, RequestID id )
{
  string fontname, fg, bg, user;
  int len, trans, rot;
  string counter;
  Image.Image digit, img;
  float scale;
  string buff, dir, *us;
  array (string)strcounter;
  if(sscanf(f, "%s/%s/%s/%d/%d/%f/%d/%s/%s.%*s",
	    user, bg, fg, trans, len, scale, rot, fontname, counter) != 10 )
    return 0;

  scale /= 5;
  if( scale > 2.0 )
    scale = 2.0;

  strcounter = counter / "";
  while(sizeof(strcounter) < len)
    strcounter = ({0}) + strcounter;

  int numdigits = sizeof(strcounter);
  int currx;

  array digits = cache_lookup("counter_digits", fontname);
  // Retrieve digits from cache. Load em, if it fails.

  if(!arrayp(digits)) {
    if( user != "1" && !catch(us = id->conf->userinfo(user, id)) && us)
      dir = us[5] + (us[5][-1]!='/'?"/":"") + query("userpath");
    else
      dir = query("ppmpath");

    digits = allocate(10);
    for(int dn = 0; dn < 10; dn++ )
    {
      buff = Stdio.read_bytes(dir + fontname+"/"+dn+".ppm" );// Try .ppm
      if (!buff
	  || catch( digit = Image.PNM.decode( buff ))
	  || !digit)
      {
	buff = Stdio.read_bytes( dir + fontname+"/"+dn+".gif" ); // Try .gif
	if(!buff)
	  return ppmlist( fontname, user, dir );	// Failed !!
	mixed err;
	if(catch( digit = Image.GIF.decode( buff )))
	  // Failed to decode GIF.
	  return ppmlist( fontname, user, dir );
	if(!digit)
	  return ppmlist( fontname, user, dir );
      }

      digits[dn] = digit;
    }
    cache_set("counter_digits", fontname,  digits);
  }

  if (fontname=="ListAllStyles")
	return ppmlist( fontname, user, dir );

  img = Image.image(digits[0]->xsize()*2 * numdigits,
		 digits[0]->ysize(), @parse_color(bg));
  for( int dn=0; dn < numdigits; dn++ )
  {
    int c = (int)strcounter[dn];
    img = img->paste(digits[c], currx, 0);
    currx += digits[c]->xsize();
  }

  // Apply Color Filte
  img = img->copy(0,0,currx-1,img->ysize()-1);
  if(fg != "n" )
    img = img->color( @parse_color(fg) );
  if(scale != 1)
    img = img->scale(scale);
  if(rot)
    img = img->rotate(rot, @parse_color(bg));

  Image.Colortable ct = cache_lookup("counter_coltables", fontname);
  if(!ct) {
    // Make a suitable color table for this ppm-font. We need all digits
    // loaded, as some fonts have completely different colors.
    int x;
    Image.Image data = Image.image(digits[0]->xsize()*2 * numdigits,
		       digits[0]->ysize());
    for( int dn = 0; dn < 10; dn++ ) {
      data = data->paste(digits[dn], x, 0);
      x += digits[dn]->xsize();
    }
    ct = Image.colortable(data->copy(0,0,x-1,data->ysize()-1), 64)
      ->cubicles(20,20,20);
    cache_set("counter_coltables", fontname, ct);
  }

  if(trans)
    return http_string_answer(Image.GIF.encode_trans(img, ct, @parse_color(bg)), 
			      "image/gif");
  else
    return http_string_answer(Image.GIF.encode(img, ct),"image/gif");
}

mapping find_internal( string f, RequestID id )
{
  if(f[0..1] == "0/")
    return find_file_font( f, id );	// Umm, standard Font
  else
    return find_file_ppm( f, id ); // Otherwise PPM/GIF 
}

constant cargs=({"bgcolor","fgcolor","trans","rotate","nfont","style","len","size"});
constant aargs=({"add","addreal","case","cheat","database","factor","file","lang",
                 "per","prec","reset","since","type"});

string tag_counter( string tagname, mapping args, RequestID id )
{
  string pre="", url, post="";

  url = query_internal_location();
  int len=(int)args->len;
  if(len > 10)
    len = 10;
  else if(len < 1)
    len = 1;

  if( args->nfont ) {

    //
    // Standard Font ..
    //
    url+= "0/"
      + (args->bgcolor?(args->bg-"#"):"000000") + "/"
      + (args->fgcolor?(args->fg-"#"):"ffffff") + "/"
      + (args->trans?"1":"0") + "/"
      + (string)len + "/"
      + (args->size?args->size:"5") + "/"
      + (args->rotate?args->rotate:"0") + "/"
      + args->nfont;

  } else {

    //
    // Cool PPM fonts ( default )
    //
    url+= (args->user?args->user:"1") + "/"
      + (args->bgcolor?(args->bg-"#"):"n") + "/"
      + (args->fgcolor?(args->fg-"#"):"n") + "/"
      + (args->trans?"1":"0") + "/"
      + (string)len + "/"
      + (args->size?args->size:"5") + "/"
      + (args->rotate?args->rotate:"0") + "/"
      + (args->style?args->style:query("ppm"));
  }

  //
  // Common Part ( /<accessed> and IMG Attributes )
  //

  string accessed=parse_rxml(make_tag("accessed",args), id);

  url +=  "/" + accessed +".gif";

  foreach(cargs+aargs, string tmp)
    m_delete(args,tmp);
  if(!args->lat) args->alt=accessed;
  args->src=url;

  if(args->bordercolor)
  {
    pre = "<font color="+args->bordercolor+">";
    post = "</font>";
  }
  if( tagname == "counter_url" ) return url;

  return pre + make_tag("img",args) + post;	// <IMG SRC="url" ...>
}

mapping query_tag_callers()
{
  return ([ "counter":     tag_counter,
	    "counter_url": tag_counter ]);
}
