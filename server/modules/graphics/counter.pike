// $Id: counter.pike,v 1.14 1998/03/18 18:50:44 neotron Exp $
// 
// Roxen Graphic Counter Module	by Jordi Murgo <jordi@lleida.net>
// Modifications  1 OCT 1997 by Bill Welliver <hww3@riverweb.com>
// Optimizations 22 FEB 1998 by David Hedbor <david@hedbor.org>
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
// $Log: counter.pike,v $
// Revision 1.13  1998/03/17 23:35:55  neotron
// Changed counter default dir, and added default ppm fonts (a).
//
// Revision 1.12  1998/03/17 23:11:33  neotron
// Added thread safe constant.
//
// Revision 1.11  1998/02/23 01:00:33  neotron
// Some minor fixes, which makes it possible to compile the module...
//
// Revision  1.10 1998/02/22 02:38:01 neotron
// Optimized using new Image.GIF / Image.colortable code. Also did
// other optimizations, resulting int a very slight speed
// increase. The Image.GIF optimization results in 2.5 (normal fonts)
// to 7.5 times faster image generation.
//
// Revision  1.9 1997/10/01 14:24:56 hww3
// Added support for Roxen 1.2
// Support for nfont fonts.
//
// Revision 1.8  1997/01/13 18:19:12  jordi
// Added gif support for digits, but it is not usable because internal
// problems in Image()->from_gif() library.
// Fixed some bugs in rotate.
// Now paints correctly backgroud and foreground in standard fonts.
// Addeded support for users own digits.
//
// Revision 1.7  1997/01/11 21:43:28  jordi
// <counter revision> now returns "x.x" correctly
//
// Revision 1.6  1997/01/11 21:36:11  jordi
// Bypass compatible attributes to <accessed tag>
// GNU disclamer.
//
// Revision 1.5  1997/01/10 19:33:36  jordi
// Bugfix in Cool Font List
//
// Revision 1.4  1997/01/10 18:16:18  jordi
// Size in standard an cool fonts are equivalents.
//
// Revision 1.3  1997/01/10 16:01:50  jordi
// size=x align=x rotate=x border=x implemented.
//
// Revision 1.2  1997/01/09 19:36:59  jordi
// Implemented PPM support.
//
// Revision 1.1  1997/01/07 16:30:21  jordi
// Initial revision
//

string cvs_version = "$Id: counter.pike,v 1.14 1998/03/18 18:50:44 neotron Exp $";

string copyright = ("<BR>Copyright 1997 "
		    "<a href=http://savage.apostols.org/>Jordi Murgo</A> and "
		    "<a href=http://www.lleida.net/>"
		    "Lleida Networks Serveis Telematics, S.L.</A> Roxen 1.2 "
		    "support by <a href=http://www.riverweb.com/~hww3>"
		    "Bill Welliver</a>. Heavily optimized by <a href="
		    "http://david.hedbor.org/>David Hedbor</a>.");

#include <module.h>
#include <array.h>
inherit "module";
inherit "roxenlib";

import Image;
constant thread_safe = 1;

#define MAX( a, b )	( (a>b)?a:b )

//
// ROXEN Config-Interface
//
void create()
{
  defvar("mountpoint", "/counter/", "Mount point", TYPE_LOCATION, 
	 "Counter location in virtual filesystem.");

  defvar("ppmpath", "etc/digits/", "PPM GIF Digits Path", TYPE_DIR,
	 "Were are located PPM/GIF digits (Ex: 'digits/')");

  defvar("userpath", "html/digits/", "PPM GIF path under Users HOME", TYPE_STRING,
	 "Where are users PPM/GIF files (Ex: 'html/digits/')<BR>Note: Relative to users $HOME" );

  defvar("ppm", "a", "Default PPM GIF-Digit style", TYPE_STRING,
	 "Default PPM/GIF-Digits style for counters (Ex: 'a')"); 
}

//
// Module Definition
//
array register_module()
{
  return ({ 
    MODULE_LOCATION | MODULE_PARSER,
    "Graphical Counter", 
    "This is the Graphic &lt;Counter&gt; Module.<br><p>"
	"\n<p><pre>"
	"&lt; counter\n"
    "         border=...                 | like &lt;IMG BORDER=...\n"  
    "         align=[left|center|right]  | like &lt;IMG ALIGN=...\n"
    "         width=...                  | like &lt;IMG WIDTH=...\n"
    "         height=...                 | like &lt;IMG HEIGHT=...\n"
    "\n" 
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
    "\n"
    "         style=\"stylename\"          | Cool PPM font name (default style=a)\n"
    "         nfont=\"fontname\" &gt;          | Standard NFONT name\n</pre>",
    0,
    1,	// Allow only a copy per server.
    });
}

//
// Where is located our Virtual Filesystem
// 
string query_location() { return query("mountpoint"); }

//
//  Show a selectable Font list
//
mapping fontlist(string bg, string fg, int scale)
{
  string out;
  array  fnts;
  int    i;
	
  out =
    "<HTML><HEAD><TITLE>Available Counter Fonts</TITLE></HEAD>"
    "<BODY BGCOLOR=#ffffff TEXT=#000000>\n"
    "<H2>Available Graphic Counter Fonts</H2><HR>"+
    cvs_version + "<BR>" + copyright + "<HR>";
		 
  catch( fnts=sort(roxen->available_fonts(1)) );
  if( fnts ) {
    out += "<B>Available Fonts:</B><MENU>";
    for( i=0; i<sizeof(fnts); i++ ) {
      out += "<A HREF='" + query("mountpoint");
      out += "0/" + bg + "/" ;
      out += fg +"/0/1/" + (string)scale + "/0/";
      out += fnts[i] + "/1234567890'>";
      out += fnts[i] + "</A><BR>\n";
    }
    out += "</DL>";
  } else {
    out += "Sorry, No Available Fonts";
  }
  
  out += "<HR>" + copyright + "</BODY></HTML>";
  
  return http_string_answer( out );
}

//
// Show a selectable Cool PPM list
//
mapping ppmlist(string font, string user, string dir)
{
  string out;
  array  fnts;
  int    i;

  out =
    "<HTML><HEAD><TITLE>Cool PPM/GIF Font not Found</TITLE></HEAD>"
    "<BODY BGCOLOR=#ffffff TEXT=#000000>\n"
    "<H2>Cool PPM Font '"+font+"' not found!!</H2><HR>"+
    cvs_version + "<BR>" + copyright + "<HR>";
		 

  catch( fnts=sort_array(get_dir( dir ) - ({".",".."})) );
  if( fnts ) {
    out += "<B>Available PPM Fonts:</B><MENU>";
    for( i=0; i<sizeof(fnts); i++ ) {
      out += "<A HREF='";
      out += query("mountpoint");
      out += user + "/n/n/0/1/5/0/";
      out += fnts[i] + "/1234567890'>";
      out += fnts[i] + "</A><BR>\n";
    }
    out += "</DL>";
  } else {
    out += "Sorry, No Available PPM/GIF Fonts";
  }
  
  out+= "<HR>" + copyright + "</BODY></HTML>";
  
  return http_string_answer( out );
}

//
// HEX to Array Color conversion.
//
array (int) mkcolor(string color)
{
  int c = (int) ( "0x"+(color-" ") );
  return ({ ((c >> 16) & 0xff),
	      ((c >>  8) & 0xff),
	      (c        & 0xff) });
}

//
// Generation of Standard Font Counters
//
mapping find_file_font( string f, object id )
{
  string fontname, strcounter, fg, bg;
  int len, counter, trans, type, rot;
  float scale;

  if(sscanf(f, "%d/%s/%s/%d/%d/%f/%d/%s/%d", 
	    type, bg, fg, trans, len, scale, rot,  
	    fontname, counter) != 9 )
    return 0;

  if(fontname=="ListAllFonts")
    return fontlist(bg,fg,(int)(scale*5.0));
  
  scale /= 5;
  if( scale > 2.0 )
    scale = 2.0;
  
  if( len > 10 )
    len = 10;
  else if(len < 1)
    len = 6;
  
  object fnt;
  fnt=get_font(fontname, 32 ,0, 0, "left", 0, 0);

  if(!fnt)
    return fontlist(bg,fg,(int)(scale*5.0));
  object txt  = fnt->write(sprintf("%0*d", len, counter));	
  object img  = image(txt->xsize(), txt->ysize(), @mkcolor(bg));

  if(scale != 1)
    if(rot)
      img = img->paste_alpha_color( txt, @mkcolor(fg) )->scale(scale)
	->rotate(rot, @mkcolor(bg));
    else
      img = img->paste_alpha_color( txt, @mkcolor(fg) )->scale(scale);
  else if(rot)
    img = img->paste_alpha_color( txt, @mkcolor(fg) )->rotate(rot,
							      @mkcolor(bg));
  else
    img = img->paste_alpha_color( txt, @mkcolor(fg) );
  
#if constant(Image.GIF)
  // Use the newer, faster encoding if available.
  string key = bg+":"+fg;

  // Making the color table is slow. Therefor we cache it.
  object ct = cache_lookup("counter_coltables", key);
  if(!ct) {
    ct = colortable(img, 32)->cubicles(20,20,20);
    cache_set("counter_coltables", key, ct);
  }
  
  if(trans)
    return http_string_answer(GIF.encode_trans(img, ct, @mkcolor(bg)), 
			      "image/gif");
  else
    return http_string_answer(GIF.encode(img, ct),"image/gif");
#else
  return http_string_answer(img->togif( @(trans?mkcolor(bg):({})) ),
			    "image/gif" );
#endif
}

//
// Generation of Cool PPM/GIF Counters
//
mapping find_file_ppm( string f, object id )
{
  string fontname, fg, bg, user;
  int len, counter, trans, rot;
  object digit, result;
  float scale;
  string buff, dir, *us;
  array (string)strcounter;
  if(sscanf(f, "%s/%s/%s/%d/%d/%f/%d/%s/%d", 
	    user, bg, fg, trans, len, scale, rot, fontname, counter) != 9 )
    return 0;

  scale /= 5;
  if( scale > 2.0 )
    scale = 2.0;

  if( len > 10 )
    len = 10;
  else if(len < 1)
    len = 6;
  strcounter = sprintf("%0*d", len, counter ) / "";
  int numdigits = sizeof(strcounter);
  int currx;

  array digits = cache_lookup("counter_digits", fontname);
  // Retrieve digits from cache. Load em, if it fails.


  if(!arrayp(digits)) {
    if( user != "1" && roxen->userlist() &&
	(us=roxen->userinfo(user, id)) )
      dir = us[5] + (us[5][-1]!='/'?"/":"") + query("userpath");
    else
      dir = query("ppmpath"); 

    digits = allocate(10);
    object digit;
    for(int dn = 0; dn < 10; dn++ )
    {
      buff = Stdio.read_bytes(dir + fontname+"/"+dn+".ppm" );// Try .ppm
      if (!buff 
#if constant(Image.PNM)
	  || catch( digit = PNM.decode( buff ))
#else
	  || catch( digit = image()->fromppm( buff ))
#endif
	  || !digit)
      {
	buff = Stdio.read_bytes( dir + fontname+"/"+dn+".gif" ); // Try .gif
	if(!buff)
	  return ppmlist( fontname, user, dir );	// Failed !!
	mixed err;
#if constant(Image.GIF) && constant(Image.GIF.decode)
	err =  catch( digit = GIF.decode( buff ));
#else
	int|function f;

	if(f = image()->fromgif)
	  err = catch( digit = f( buff ));
#endif
	if(err || !digit)
	  return ppmlist( fontname, user, dir );
      }
      
      digits[dn] = digit;
    }
    cache_set("counter_digits", fontname,  digits);
  }

  result = image(digits[0]->xsize()*2 * numdigits,
		 digits[0]->ysize(), @mkcolor(bg));
  for( int dn=0; dn < numdigits; dn++ )
  {
    int c = (int)strcounter[dn];
    werror(sprintf("%O:", c));
    result = result->paste(digits[c], currx, 0);
    currx += digits[c]->xsize();
  }	  
  write("\n");
  // Apply Color Filter 	
  //
  result = result->copy(0,0,currx-1,result->ysize()-1);
  if(fg != "n" )
    result = result->color( @mkcolor(fg) );
  if(scale != 1)
    result = result->scale(scale);
  if(rot)
    result = result->rotate(rot, @mkcolor(bg));
#if constant(Image.GIF)  
  object ct = cache_lookup("counter_coltables", fontname);
  if(!ct) {
    // Make a suitable color table for this ppm-font. We need all digits
    // loaded, as some fonts have completely different colors.
    object data;
    int x;
    data = image(digits[0]->xsize()*2 * numdigits,
		       digits[0]->ysize());
    for( int dn = 0; dn < 10; dn++ ) {
      data = data->paste(digits[dn], x, 0);
      x += digits[dn]->xsize();
    }
    ct = colortable(data->copy(0,0,x-1,data->ysize()-1), 64)
      ->cubicles(20,20,20);
    cache_set("counter_coltables", fontname, ct);
  }
  
  if(trans)
    return http_string_answer(GIF.encode_trans(result, ct, @mkcolor(bg)), 
			      "image/gif");
  else
    return http_string_answer(GIF.encode(result, ct),"image/gif");
#else
  return http_string_answer(result->togif(@(trans?mkcolor(bg):({}))),
			    "image/gif");
#endif
}

mapping find_file( string f, object id )
{
  if(f[0..1] == "0/")
    return find_file_font( f, id );	// Umm, standard Font
  else
    return find_file_ppm( f, id ); // Otherwise PPM/GIF 
}

string tag_counter( string tagname, mapping args, object id )
{
  string accessed;
  string pre, url, post;

  //
  // Version Identification ( automagically updated by RCS ) 
  //
  if( args->version )
    return cvs_version;
  if( args->revision )
    return "$Revision: 1.14 $" - "$" - " " - "Revision:";

  //
  // bypass compatible accessed attributes
  // 
  accessed="<accessed"
    + (args->cheat?" cheat="+args->cheat:"")
    + (args->factor?" factor="+args->factor:"")
    + (args->file?" file="+args->file:"")
    + (args->prec?" prec="+args->prec:"")
    + (args->precision?" precision="+args->precision:"")
    + (args->add?" add="+args->add:"")
    + (args->reset?" reset":"")
    + (args->per?" per="+args->per:"")
    + ">";

  pre = "<IMG SRC=\"";
  url = query("mountpoint");
	
  if( args->nfont ) {
	
    //
    // Standard Font ..
    //
    url+= "0/" 
      + (args->bg?(args->bg-"#"):"000000") + "/"
      + (args->fg?(args->fg-"#"):"ffffff") + "/"
      + (args->trans?"1":"0") + "/"
      + (args->len?args->len:"6") + "/" 
      + (args->size?args->size:"5") + "/" 
      + (args->rotate?args->rotate:"0") + "/" 
+ args->nfont;

  } else {
	
    //
    // Cool PPM fonts ( default )
    //
    url+= (args->user?args->user:"1") + "/" 
      + (args->bg?(args->bg-"#"):"n") + "/"	
      + (args->fg?(args->fg-"#"):"n") + "/"
      + (args->trans?"1":"0") + "/"
      + (args->len?args->len:"6") + "/" 
      + (args->size?args->size:"5") + "/"
      + (args->rotate?args->rotate:"0") + "/" 
      + (args->style?args->style:query("ppm"));
  }

  //
  // Common Part ( /<accessed> and IMG Attributes )
  //
  url +=  "/" + accessed;
	
  post =  "\" "  
    + (args->border?"border="+args->border+" ":"")
    + (args->align?"align="+args->align+" ":"")
    + (args->height?"height="+args->height+" ":"")
    + (args->width?"width="+args->width+" ":"")
    + "alt=\"" + accessed + "\">";

  if( tagname == "counter_url" )
    if( args->parsed )
      return  parse_rxml(url,id);
    else
      return url;
  else
    return pre + url + post;	// <IMG SRC="url" ...>
}

mapping query_tag_callers()
{
  return ([ "counter":     tag_counter,
	    "counter_url": tag_counter ]);
}
