// $Id: counter.pike,v 1.3 1998/02/22 02:26:12 neotron Exp $
// 
// Roxen Graphic Counter Module	by Jordi Murgo <jordi@lleida.net>
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
// Revision 1.2  1998/01/22 07:34:07  neotron
// Fixed the graphical counter!
//
// Revision 1.1  1998/01/21 08:09:02  neotron
// Added the counter module to CVS. It's now extremely easy to make a
// graphical counter! Just get the fonts and add the options in the
// config interface.
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

string cvs_version = "$Id: counter.pike,v 1.3 1998/02/22 02:26:12 neotron Exp $";

string copyright = "<BR>Copyright 1997 "
+"<a href=http://savage.apostols.org/>Jordi Murgo</A> and "
+"<a href=http://www.lleida.net/>"
+"Lleida Networks Serveis Telematics, S.L.</A>";
#include <simulate.h>

#include <module.h>
inherit "module";
inherit "roxenlib";

#define MAX( a, b )	( (a>b)?a:b )

//
// ROXEN Config-Interface
//
void create()
{
  defvar("mountpoint", "/counter/", "Mount point", TYPE_LOCATION, 
	 "Counter location in virtual filesystem.");

  defvar("fontpath", "fonts/32/", "Font Path", TYPE_DIR,
	 "Default Font Path (Ex: 'fonts/32/')");

  defvar("ppmpath", "digits/", "PPM GIF Digits Path", TYPE_DIR,
	 "Were are located PPM/GIF digits (Ex: 'digits/')");

  defvar("userpath", "html/digits/", "PPM GIF path under Users HOME", TYPE_STRING,
	 "Where are users PPM/GIF files (Ex: 'html/digits/')<BR>Note: Relative to users $HOME" );

  defvar("ppm", "a", "Default PPM GIF-Digit style", TYPE_STRING,
	 "Default PPM/GIF-Digits style for counters (Ex: 'a')"); 
}

//
// Module Definition
//
mixed *register_module()
{
  return ({ 
    MODULE_LOCATION | MODULE_PARSER,
      "Graphic Counter Module", 
      "This is the Graphic &lt;Counter&gt; Module.",
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
mapping fontlist(string bg, string fg, string font, int scale)
{
  string out;
  array  fnts;
  int    i;
	
  out = "<HTML><HEAD><TITLE>Standard Font not Found</TITLE></HEAD>"
    + "<BODY BGCOLOR=#ffffff TEXT=#000000>\n"
    + "<H2>Standard Font '"+font+"' not found!!</H2><HR>"+
    cvs_version + "<BR>" + copyright + "<HR>";
  
  catch( fnts=sort_array(get_dir(query("fontpath")) - ({".",".."})) );
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
  
  out+= "<HR>" + copyright + "</BODY></HTML>";
  
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

  out = "<HTML><HEAD><TITLE>Cool PPM/GIF Font not Found</TITLE></HEAD>"
    + "<BODY BGCOLOR=#ffffff TEXT=#000000>\n"
    + "<H2>Cool PPM Font '"+font+"' not found!!</H2><HR>"+
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
  string fontname, strcounter, strsize, fg, bg;
  int len, counter, trans, type, rot;
  float scale;

  if(sscanf(f, "%d/%s/%s/%d/%d/%f/%d/%s/%d", 
	    type, bg, fg, trans, len, scale, rot,  
	    fontname, counter) != 9 )
    return 0;

  scale /= 5;
  if( scale > 2.0 )
    scale = 2.0;

  if( len > 10 )
    len = 10;

  strsize = sprintf("%%0%dd", len);
  strcounter = sprintf( strsize, counter );

  object fnt=Image.font();

  if (!fnt->load(query("fontpath")+fontname)) {
    perror("Could not load font '" + fontname + "'" ); 
    return fontlist(bg, fg, fontname, (int)( (float)(scale*5)) );
  }

  object txt  = fnt->write(strcounter);	
  object img  = txt->clone()->clear( @(mkcolor(bg)) );
  object fore = txt->clone()->clear( @(mkcolor(fg)) );

  img = img->paste_mask( fore, txt );

  // Delete Objects 
  //
  txt=fore=fnt=0;

  return http_string_answer(
			    img->scale(scale)->rotate(rot, @mkcolor(bg))->togif( @(trans?mkcolor(bg):({})) ),
			    "image/gif" );
}

//
// Generation of Cool PPM/GIF Counters
//
mixed find_file_ppm( string f, object id )
{
  string fontname, strcounter, strsize, fg, bg, user;
  int len, counter, trans, rot;
  object result;
  float scale;
  string ppmbuff, dir, *us;
  int currx;
  mapping retval;
  if(sscanf(f, "%s/%s/%s/%d/%d/%f/%d/%s/%d", 
	    user, bg, fg, trans, len, scale, rot, fontname, counter) != 9 )
    return 0;

  if( len > 10 )
    len = 10;
  
  strsize = sprintf("%%0%dd", len);
  strcounter = sprintf( strsize, counter );
  int numdigits = sizeof(strcounter / "");
  if( user != "1" && roxen->userlist() && (us=roxen->userinfo(user,id)) )
    dir = us[5] + (us[5][-1]!='/'?"/":"")+ query("userpath");
  else
    dir = query("ppmpath"); 
  array digits = cache_lookup("digits", fontname);
  object colortable;
  if(digits == -1)
    return ppmlist( fontname, user, dir );	// Failed !!
  if(!arrayp(digits)) {
    digits = allocate(10);
    object digit;
    for( int dn=0; dn < 10; dn++ )
    {
      ppmbuff = read_bytes( dir + fontname+"/"+dn+".ppm");     // Try .ppm
      if(!ppmbuff || catch( digit = Image.image()->fromppm( ppmbuff ))) {
	cache_set("digits", fontname,  -1);
	return ppmlist( fontname, user, dir );	// Failed !!
      } 
      digits[dn] = digit;
    }
    cache_set("digits", fontname,  digits);
  }
  result = Image.image(digits[0]->xsize()*2 * numdigits,
		       digits[0]->ysize());
  for( int dn=0; dn < sizeof( strcounter ); dn++ )
  {
    int c = (int)strcounter[dn..dn];
    result = result->paste(digits[c], currx, 0);
    currx += digits[c]->xsize();
  }
  string gif;
//#define OLD
#ifndef OLD
  colortable = cache_lookup("colortables", fontname);
  if(!colortable) {
    object data;
    int x;
    data = Image.image(digits[0]->xsize()*2 * numdigits,
		       digits[0]->ysize());
    for( int dn = 0; dn < 10; dn++ ) {
      data = result->paste(digits[dn], x, 0);
      x += digits[dn]->xsize();
    }
    colortable = Image.colortable(data->copy(0,0,x-1,data->ysize()-1), 64);
    cache_set("colortables", fontname, colortable->cubicles(20,20,20));
  }
  
  gif = Image.GIF.encode(result->copy(0,0,currx-1,result->ysize()-1),colortable);
#else
  gif = result->copy(0,0,currx-1,result->ysize()-1)->togif();
#endif
  return
    http_string_answer(gif);
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
    return "$Revision: 1.3 $" - "$" - " " - "Revision:";

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
	
  if( args->font ) {
	
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
+ args->font;

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
  return ([ "counter":tag_counter,
		     "counter_url":tag_counter ]);
}
