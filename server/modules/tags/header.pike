// This is a roxen module. (c) Informationsvävarna AB 1996.

// This module is written by Mattias Wingstedt <wing@infovav.se>,
// please direct further questsions to him.

string cvs_version = "$Id: header.pike,v 1.3 1996/11/27 13:48:15 per Exp $";
#include <module.h>
inherit "module";
inherit "roxenlib";

string cvs_version = "$Id: header.pike,v 1.3 1996/11/27 13:48:15 per Exp $";
#define WATCH(b,a) (perror( sprintf( b + ":%O\n", (a) ) ), (a))

void create()
{
  defvar( "idir", "/icons/", "Icons: Pre-url", TYPE_STRING, 
	 "Prepend this to a icon-url.");

  defvar( "iborder", 0, "Icons: Borders", TYPE_FLAG, 
	 "Should icons have borders?");

  defvar( "icon_prev", "left.gif", "Icons: Previous", TYPE_STRING, 
	 "Icon pointing left.");

  defvar( "icon_up", "up.gif", "Icons: Up", TYPE_STRING, 
	 "Icon pointing up.");

  defvar( "icon_next", "right.gif", "Icons: Next", TYPE_STRING, 
	 "Icon pointing right.");

  defvar( "altprev", "[prev]", "Icons: Alt: Previous", TYPE_STRING, 
	 "Alt-text for the left-pointing icon.");

  defvar( "altup", "[up]", "Icons: Alt: Up", TYPE_STRING, 
	 "Alt-text for the up-pointing icon.");

  defvar( "altnext", "[next]", "Icons: Alt: Next", TYPE_STRING, 
	 "Alt-text for the right-pointing icon.");


  defvar( "header_up", "<hr noshade>", "Header: Up", TYPE_TEXT_FIELD,
	 "" );

  defvar( "header_left", "$logo", "Header: Left", TYPE_TEXT_FIELD,
	 "" );

  defvar( "header_middle", "<font size=+2>$h</font><br>$ARROWS", "Header: Middle", TYPE_TEXT_FIELD,
	 "" );

  defvar( "header_right", "$FLAG_UNAVAILABLE $FLAG_SELECTED $FLAGS_AVAILABE",
	 "Header: Right", TYPE_TEXT_FIELD,
	 "" );

  defvar( "header_down", "<hr noshade>", "Header: Down", TYPE_TEXT_FIELD,
	 "" );


  defvar( "footer_up", "<hr noshade>", "Footer: Up", TYPE_TEXT_FIELD,
	 "" );

  defvar( "footer_left", "$logo", "Footer: Left", TYPE_TEXT_FIELD,
	 "" );

  defvar( "footer_middle",
	 "$ARROWS\n<br><a href=/special/comments.ulpc?page=$URL&creator=$creator>$creator</a>",
	 "Footer: Middle", TYPE_TEXT_FIELD,
	 "" );

  defvar("footer_right", "$FLAG_UNAVAILABLE $FLAG_SELECTED $FLAGS_AVAILABE",
	 "Footer: Right", TYPE_TEXT_FIELD,
	 "" );

  defvar("footer_down", "<hr noshade>", "Footer: Down", TYPE_TEXT_FIELD, "");
}

string icon_prev, icon_up, icon_next;
string altprev, altup, altnext, icon_dir;
int icon_border;
string header_up, header_left, header_middle, header_right, header_down;
string footer_up, footer_left, footer_middle, footer_right, footer_down;

array register_module()
{
  return ({ MODULE_PARSER,
	    "Header module",
	    "Gives header and footer tags. ",
	    ({ }),
	    1
	    });
}

void start()
{
  icon_border = query( "iborder" );
  icon_prev = query( "icon_prev" );
  icon_dir = query( "idir" );
  icon_up = query( "icon_up" );
  icon_next = query( "icon_next" );
  altprev = query( "altprev" );
  altup = query( "altup" );
  altnext = query( "altnext" );
  header_up = query( "header_up" );
  header_left = query( "header_left" );
  header_middle = query( "header_middle" );
  header_right = query( "header_right" );
  header_down = query( "header_down" );
  footer_up = query( "footer_up" );
  footer_left = query( "footer_left" );
  footer_middle = query( "footer_middle" );
  footer_right = query( "footer_right" );
  footer_down = query( "footer_down" );
}

string tag_links( string tag, mapping m, object id );
string replace_variables( string str, mapping m, object id )
{
  string a, b, var, value, result;
  array (string) lines;
  int c;

  result = "";
  while (b="", sscanf( str, "%s$%[a-zA-Z-_]%s", a, var, b ) >= 2)
  {
    result += a;
    switch (var)
    {
     case "ARROWS":
      result += tag_links( "", m, id );
      break;
      
     case "FLAG_UNAVAILABLE":
      if (m[ "choosen_language" ] && m[ "language" ] && m[ "flag_dir" ] && m[ "language_data" ]
	  && m[ "choosen_language" ] != m[ "language" ])
	result += "<img src=" + m[ "flag_dir" ] + m[ "choosen_language" ] + ".unavailable.gif "
	  + "alt=\"" + m[ "language_data" ][ m[ "choosen_language" ] ][0] + "\">\n";
      break;

     case "FLAG_SELECTED":
      if (m[ "language" ] && m[ "flag_dir" ] && m[ "language_data" ])
	result += "<img src=" + m[ "flag_dir" ] + m[ "language" ] + ".selected.gif "
	  + "alt=\"" + m[ "language_data" ][ m[ "language" ] ][0] + "\">\n";
      break;

     case "FLAGS_AVAILABE":
      if (m[ "available_languages" ] && m[ "flag_dir" ] && m[ "language_data" ]
	  && m[ "language_list" ])
	for (c=0; c < sizeof( m[ "available_languages" ] ); c++)
	  result += "<a href=" + add_pre_state( id->not_query + (id->query ? "?" + id->query : ""),
					       id->prestate - m[ "language_list" ]
					       + (< indices( m[ "available_languages" ] )[c] >) )
	    + "><img src=" + m[ "flag_dir" ] + indices( m[ "available_languages" ] )[c]
	    + ".available.gif "
	    + "alt=\"" + m[ "language_data" ][ indices( m[ "available_languages" ] )[c] ][0]
	    + "\"></a>\n";
      break;

     case "URL":
      result += add_pre_state( id->not_query + (id->query ? "?" + id->query : ""), id->prestate );
      break;
      
     default:
      if (m[ var ])
	result += m[ var ];
    }
    str = b;
  }
  result += str;
  
  lines = result / "<br>";
  for (c=0; c < sizeof( lines );)
    if (strlen( lines[c] - " " - "\t" - "\r" - "\n" ))
      c++;
    else
      lines = lines[ 0..c-1 ] + lines[ c+1..17000000 ];
  return lines * "\n<br>";
}

string tag_header( string tag, mapping m, object id )
{
  string result, left, middle, right;

  m += id->misc;
  result = replace_variables( header_up, m, id ) + "\n";
  left = replace_variables( header_left, m, id ) + "\n";
  middle = replace_variables( header_middle, m, id ) + "\n";
  right = replace_variables( header_right, m, id ) + "\n";
  // Fix support for clients that doesn't support tables here
  result = "<table width=100% cellspacing=0 cellpadding=0><tr><td colspan=3>" + result
    + "</td></tr>\n<tr><td align=left>" + left
    + "</td>\n<td align=center>" + middle + "</td>\n<td align=right>" + right + "</td>\n";
  result += "<tr><td colspan=3>" + replace_variables( header_down, m, id ) + "</td>\n</table>\n";;
  return result;
}

string tag_footer( string tag, mapping m, object id )
{
  string result, left, middle, right;
  
  m += id->misc;
  result = replace_variables( footer_up, m, id ) + "\n";
  left = replace_variables( footer_left, m, id ) + "\n";
  middle = replace_variables( footer_middle, m, id ) + "\n";
  right = replace_variables( footer_right, m, id ) + "\n";
  // Fix support for clients that doesn't support tables here
  result = "<table width=100% cellspacing=0 cellpadding=0><tr><td colspan=3>" + result
    + "</td></tr>\n<tr><td align=left>" + left
    + "</td>\n<td align=center>" + middle + "</td>\n<td align=right>" + right + "</td>\n";
  result += "<tr><td colspan=3>" + replace_variables( footer_down, m, id ) + "</td>\n</table>\n";;
  return result;
}

string tag_links( string tag, mapping m, object id )
{
  string result = "";
  
  if (m["prev"])
    result += "<a href=\"" + m["prev"]
      + "\"><img src=" + icon_dir + icon_prev + " "
      + "border="+icon_border+" "
      + "alt=\"" + (m["altprev"] ? m["altprev"] : altprev) + "\"></a>\n";
  if (m["up"])
    result += "<a href=\"" + m["up"]
      + "\"><img src=" + icon_dir + icon_up + " "
      + "border="+icon_border+" "
      + "alt=\"" + (m["altup"] ? m["altup"] : altup) + "\"></a>\n";
  if (m["next"])
    result += "<a href=\"" + m["next"]
      + "\"><img src=" + icon_dir + icon_next + " "
      + "border="+icon_border+" "
      + "alt=\"" + (m["altnext"] ? m["altnext"] : altnext) + "\"></a>\n";
  if (tag == "links")
    return "<p align=center>";
  else
    return result;
}

mapping query_tag_callers()
{
  return ([
	   "s-header" : tag_header,
	   "s-footer" : tag_footer,
	   "links" : tag_links,
	   ]);
}

