// This is a roxen module. Copyright © 1999 - 2000, Roxen IS.
//

inherit "module";
inherit "html";
inherit "roxenlib";
#include <roxen.h>
#include <stat.h>
#include <config_interface.h>

#define LOCALE	LOW_LOCALE->config_interface
#define CU_AUTH id->misc->config_user->auth

constant module_type = MODULE_PARSER|MODULE_CONFIG;
constant module_name = "Configuration interface RXML tags";

/* Not exactly true, but the config filesystem forbids parallell
 * accesses anyway so there is no need for an extra lock here..
 */
constant thread_safe = 1;


void start(int num, Configuration conf)
{
  if (!num) conf->old_rxml_compat++;
}

void stop()
{
  my_configuration()->old_rxml_compat--;
}

void create()
{
  query_tag_set()->prepare_context=set_entities;
}

class Scope_locale
{
  inherit RXML.Scope;
  mixed `[]  (string var, void|RXML.Context c, void|string scope)
  {
    function(void:string)|string val;
    if( !(val = LOCALE[ var ]) )
      val = LOW_LOCALE[ var ];

    if(!val)
      return "Unknown locale field: "+var;
    if( functionp( val ) )
      return val( );
    return val;
  }
}

class Scope_cf
{
  inherit RXML.Scope;
  mixed `[]  (string var, void|RXML.Context c, void|string scope)
  {
    object id = c->id;
    while( id->misc->orig ) id = id->misc->orig;
    switch( var )
    {
     case "num-dotdots":
       int depth = sizeof( (id->not_query+(id->misc->path_info||"") )/"/" )-3;
       string dotodots = depth>0?(({ "../" })*depth)*"":"./";
       return dotodots;

     case "current-url":
       return (id->not_query+(id->misc->path_info||""));
    }
  }
}

class Scope_usr
{
  inherit RXML.Scope;

#define ALIAS( X ) `[](X,c,scope)
#define QALIAS( X ) (`[](X,c,scope)?"\""+roxen_encode(`[](X,c,scope), "html")+"\"":0)
  mixed `[]  (string var, void|RXML.Context c, void|string scope)
  {
    object id = c->id;

    if( id->misc->cf_theme &&
        id->misc->cf_theme[ var ] )
      return id->misc->cf_theme[ var ];

    object c1;

    switch( var )
    {
      string q, res;
      /* composite */
     case "count-0": return "/internal-roxen-count_0";
     case "count-1": return "/internal-roxen-count_1";
     case "count-2": return "/internal-roxen-count_3";
     case "count-3": return "/internal-roxen-count_2";

     case "logo-html":
       return "<img border=\"0\" src="+QALIAS("logo")+" />";

     case "toptabs-args":
       res = "frame-image="+QALIAS("toptabs-frame");
       res += " bgcolor="+QALIAS("toptabs-bgcolor" );
       res += " font="+QALIAS("toptabs-font" );
       res += " dimcolor="+QALIAS("toptabs-dimcolor" );
       res += " textcolor="+QALIAS("toptabs-textcolor" );
       res += " dimtextcolor="+QALIAS("toptabs-dimtextcolor" );
       res += " selcolor="+QALIAS("toptabs-selcolor" );
       if( stringp( q = ALIAS("toptabs-extraargs" ) ) )
         res += " "+q;
       return res;

     case "subtabs-args":
       res ="frame-image="+QALIAS("subtabs-frame")+
           " bgcolor="+QALIAS("subtabs-bgcolor")+
           " font="+QALIAS("subtabs-font")+
           " textcolor="+QALIAS("subtabs-dimtextcolor")+
           " dimcolor="+QALIAS("subtabs-dimcolor")+
           " seltextcolor="+QALIAS("subtabs-seltextcolor")+
           " selcolor="+QALIAS("subtabs-selcolor");
       if( stringp( q = ALIAS("subtabs-extraargs" ) ) )
         res += " "+q;
       return res;

     case "body-args":
       res = "link="+QALIAS("linkcolor")+" vlink="+QALIAS("linkcolor")+
             " alink="+QALIAS("fade2")+" bgcolor="+QALIAS("bgcolor")+
             " text="+QALIAS("fgcolor");
       if( stringp(q = QALIAS( "background" )) && strlen( q ) )
         res += " background="+q;
       return res;

     case "top-tableargs":
       if( ALIAS("top-bgcolor") != "none" )
         res = "bgcolor="+QALIAS("top-bgcolor");
       else
         res="";
       if( stringp(q = QALIAS( "top-background" )) && strlen( q ) )
         res += " background="+q;
       return res;

     case "toptabs-tableargs":
       string res = "";
       if( ALIAS("toptabs-bgcolor") != "none" )
         res = "bgcolor="+QALIAS("toptabs-bgcolor");
       if( stringp(q = QALIAS( "toptabs-background" )) && strlen( q ) )
         res += " background="+q;
       if( stringp(q = QALIAS( "toptabs-align" )) && strlen( q ) )
         res += " align="+q;
       else
         res += " align=\"left\"";
       return res;

     case "subtabs-tableargs":
       res = "valign=\"bottom\" bgcolor="+QALIAS("subtabs-bgcolor");
       if( stringp(q = QALIAS( "subtabs-background" )) && strlen( q ) )
         res += " background="+q;
       if( stringp(q = QALIAS( "subtabs-align" )) && strlen( q ) )
         res += " align="+q;
       else
         res += " align=\"left\"";
       return res;

     case "left-tableargs":
       string res = "valign=\"top\" width=\"150\"";
       if( stringp(q = QALIAS( "left-background" )) && strlen( q ) )
         res += " background="+q;
       return res;

     case "content-tableargs":
       string res = " width=\"100%\" valign=\"top\"";
       if( stringp(q = QALIAS( "content-background" )) && strlen( q ) )
         res += " background="+q;
       return res;


      /* standalone, nothing is based on these. */
     case "content-toptableargs": return "";
     case "left-image":           return "/internal-roxen-unit";
     case "selected-indicator":   return "/internal-roxen-next";
     case "item-indicator":       return "/internal-roxen-dot";
     case "logo":                 return "/internal-roxen-roxen";
     case "err-1":                return "/internal-roxen-err_1";
     case "err-2":                return "/internal-roxen-err_2";
     case "err-3":                return "/internal-roxen-err_3";
     case "obox-titlefont":       return "helvetica,arial";
     case "obox-border":          return "black";


      /* 1-st level */
     case "tab-frame-image":      return "/internal-roxen-tabframe";
     case "gbutton-frame-image":  return "/internal-roxen-gbutton";

    /* also: font, bgcolor, fgcolor */

  /* 2nd level */
     case "content-titlebg":      return ALIAS( "bgcolor" );
     case "content-titlefg":      return ALIAS( "fgcolor" );
     case "gbutton-font":         return ALIAS( "font" );
     case "left-buttonframe":     return ALIAS( "gbutton-frame-image" );
     case "obox-bodybg":          return ALIAS( "bgcolor" );
     case "obox-bodyfg":          return ALIAS( "fgcolor" );
     case "obox-titlefg":         return ALIAS( "bgcolor" );
     case "subtabs-bgcolor":      return ALIAS( "bgcolor" );
     case "subtabs-dimtextcolor": return ALIAS( "bgcolor" );
     case "subtabs-frame":        return ALIAS( "tab-frame-image" );
     case "subtabs-seltextcolor": return ALIAS( "fgcolor" );
     case "tabs-font":            return ALIAS( "font" );
     case "toptabs-frame":        return ALIAS( "tab-frame-image" );
     case "toptabs-dimtextcolor": return ALIAS( "bgcolor" );
     case "toptabs-selcolor":     return ALIAS( "bgcolor" );
     case "toptabs-seltextcolor": return ALIAS( "fgcolor" );

    /* also: fade1 - fade4 */

    /* 3rd level */

     case "content-bg":           return ALIAS( "fade1" );
     case "left-buttonbg":        return ALIAS( "fade1" );
     case "left-selbuttonbg":     return ALIAS( "fade3" );
     case "obox-titlebg":         return ALIAS( "fade2" );
     case "subtabs-dimcolor":     return ALIAS( "fade2" );
     case "subtabs-font":         return ALIAS( "tabs-font" );
     case "subtabs-selcolor":     return ALIAS( "fade1" );
     case "top-bgcolor":          return ALIAS( "fade3" );
     case "top-fgcolor":          return ALIAS( "fade4" );
     case "toptabs-bgcolor":      return ALIAS( "fade3" );
     case "toptabs-dimcolor":     return ALIAS( "fade2" );
     case "toptabs-font":         return ALIAS( "tabs-font" );
    }


    if( var != "bgcolor" )
    {
      c1 = Image.Color( ALIAS("bgcolor") );
      if(!c1)
        c1 = Image.Color.black;
    }

#undef ALIAS
#undef QALIAS

    switch( var )
    {
     case "fade1":
       if( `+(0,@(array)c1) < 200 )
         return (string)Image.Color(@map(map((array)c1, `+, 0x21 ),min,255));
       return (string)Image.Color(@map(map( (array)c1, `-, 0x11 ),max,0) );

     case "fade2":
       if( `+(0,@(array)c1) < 200 )
         return (string)Image.Color( @map(map((array)c1, `+, 0x61 ),min,255));
       return (string)Image.Color( @map(map( (array)c1, `-, 0x51 ),max,0) );

     case "fade3":
       array sub = ({ 0x26, 0x21, 0x18 });
       array add = ({ 0x18, 0x21, 0x26 });
       array a =  (array)c1;
       if( `+(0,@(array)c1) < 200 )
       {
         a[0] += add[0];
         a[1] += add[1];
         a[2] += add[2];
       } else {
         a[0] -= sub[0];
         a[1] -= sub[1];
         a[2] -= sub[2];
       }
       return (string)Image.Color( @map(map(a,max,0),min,255) );

     case "fade4":
       array sub = ({ 0x87, 0x7b, 0x63 });
       array add = ({ 0x63, 0x7b, 0x87 });
       array a =  (array)c1;
       if( `+(0,@(array)c1) < 200 )
       {
         a[0] += add[0];
         a[1] += add[1];
         a[2] += add[2];
       } else {
         a[0] -= sub[0];
         a[1] -= sub[1];
         a[2] -= sub[2];
       }
       return (string)Image.Color( @map(map(a,max,0),min,255) );
    }
    return config_setting( var );
  }

  string _sprintf() { return "RXML.Scope(usr)"; }
}

RXML.Scope usr_scope=Scope_usr();
RXML.Scope locale_scope=Scope_locale();
RXML.Scope cf_scope=Scope_cf();

void set_entities(RXML.Context c)
{
  c->extend_scope("usr", usr_scope);
  c->extend_scope("locale", locale_scope);
  c->extend_scope("cf", cf_scope);
}

string get_var_doc( string s, object mod, int n, object id )
{
  s = LOW_LOCALE->module_doc_string( mod, s, (n==1) );
  if( !s ) return "";
  if( n==2 ) sscanf( s, "%*s:%s", s );
  return s;
}

string theme_name( string theme )
{
  catch {
    return String.trim_all_whites(lopen("config_interface/standard/themes/"+
                                        theme+"/name","r")->read());
  };
  return "Unknown theme";
}

array(string) all_themes( )
{
  return (get_dir( "config_interface/standard/themes/" ) + 
          (get_dir( "../local/config_interface/standard/themes/" )||({}))-
           ({"CVS","README"}));
}

string get_var_value( string s, object mod, object id )
{
  array var = mod->variables[ s ];
  if( !var )
    return "Impossible!";

  switch(var[VAR_TYPE])
  {
    object m;
    string name;
    array tmp;
   case TYPE_CUSTOM:
     return var[VAR_MISC][0]( var, 1 );

   case TYPE_PASSWORD:
     return "****";

   default:
     return (string)var[ VAR_VALUE ];

   case TYPE_FLOAT:
     return sprintf("%.4f", var[VAR_VALUE]);

   case TYPE_THEME: /* config-if local type... */
     return theme_name( var[VAR_VALUE] );

   case TYPE_DIR_LIST:
   case TYPE_STRING_LIST:
   case TYPE_INT_LIST:
     if(var[VAR_MISC])
     {
       mapping q;
       if(q = LOW_LOCALE->module_doc_string(mod, var[VAR_SHORTNAME], 2))
         return q[ var[VAR_VALUE] ];
       return (string)var[VAR_VALUE];
     }
     if(arrayp(var[VAR_VALUE]))
       return ((array(string))var[VAR_VALUE]) * ", ";
     else
       return "";

   case TYPE_FLAG:
     if(var[VAR_VALUE])
       return LOW_LOCALE->yes;
     return LOW_LOCALE->no;
  }
}

string get_world(array(string) urls) {
  if(!sizeof(urls)) return 0;

  string url=urls[0];
  foreach( ({"http:","fhttp:","https:","ftp:"}), string p)
    foreach(urls, string u)
      if(u[0..sizeof(p)-1]==p) {
	url=u;
	break;
      }

  string protocol, server, path;
  int port;
  if(sscanf(url, "%s://%s:%d/%s", protocol, server, port, path)!=4 &&
     sscanf(url, "%s://%s/%s", protocol, server, path)!=3)
    return 0;

  if(protocol=="fhttp") protocol="http";

  array hosts=({ gethostname() }), dns;
  catch(dns=Protocols.DNS.client()->gethostbyname(hosts[0]));
  if(dns && sizeof(dns))
    hosts+=dns[2]+dns[1];

  foreach(hosts, string host)
    if(glob(server, host)) {
      server=host;
      break;
    }

  if(port) return sprintf("%s://%s:%d/%s", protocol, server, port, path);
  return sprintf("%s://%s/%s", protocol, server, path);
}

string set_variable( string v, object in, mixed to, object id )
{
  array var = in->variables[ v ];
  string warning ="";
  mixed val = to;

  if( in == roxen )
  {
    if( !CU_AUTH( "Edit Global Variables" ) )
      return "";
  } else if( in->register_module ) {
    if( !CU_AUTH( "Edit Module Variables" ) )
      return "";
  } else if( in->find_module && in->Priority ) {
    if( !CU_AUTH( "Edit Site Variables" ) )
      return "";
  }

  switch(var[VAR_TYPE])
  {
   case TYPE_FLOAT:
     val = (float)val;
     break;

   case TYPE_INT:
     val = (int)val;
     break;

   case TYPE_DIR:
     if(!strlen(val)) val = "./";
     if( !(file_stat( val ) && (file_stat( val )[ ST_SIZE ] == -2 )))
       warning = "<font color=darkred>"+val+" is not a directory</font>";
     if( val[-1] != '/' )
       val += "/";
     break;

   case TYPE_PASSWORD:
     if( val == "" )
       return "";
     val = crypt( val );
     break;
   case TYPE_TEXT_FIELD:
     val = replace( val, "\r\n", "\n" );
     val = replace( val, "\r", "\n" );
   case TYPE_STRING:
   case TYPE_FILE:
   case TYPE_LOCATION:
     break;

   case TYPE_FONT:
     val = replace( val, " ", "_" );
     break;

   case TYPE_CUSTOM:
   case TYPE_THEME:
     break;

   case TYPE_DIR_LIST:
   case TYPE_STRING_LIST:
   case TYPE_INT_LIST:
     if( !var[ VAR_MISC ] )
     {
       if (sscanf (val, "%*[ \t\n\r]%*c") < 2) {
	 val = ({});
	 break;
       }
       val /= ",";
       int i;
       for( i = 0; i<sizeof( val ); i++ )
         val[i] = String.trim_whites( val[i] );
       if( var[ VAR_TYPE ] == TYPE_INT_LIST )
         val = (array(int))val;
       else if( var[ VAR_TYPE ] == TYPE_DIR_LIST )
         foreach( val, string d )
         {
           if( !(file_stat( d ) && (file_stat( d )[ ST_SIZE ] == -2 )))
             warning += "<font color=darkred>"+d+
                     " is not a directory</font><br>";
           if( d[-1] != '/' )
             val = replace( val, d, d+"/" );
         }
     } else {
       if( var[VAR_TYPE]  == TYPE_INT_LIST )
         val = (int)val;
     }
     break;

   case TYPE_FLAG:
     if( val == "Yes" || val == LOW_LOCALE->yes )
       val = 1;
     else
       val = 0;
     break;
   default:
     report_debug("Unknown variable type ["+var[ VAR_TYPE ]+"]\n");
     return "";
  }

  if (in->check_variable) {
    string err = in->check_variable(v, val);
    if (err) {
      warning += "<font color=darkred>"+err+"</font>";
    }
  }

  if( equal( var[ VAR_VALUE ], val ) )
    return "";

  if( v=="MyWorldLocation" && in->is_configuration && val=="" )
    return "";

  if( v=="URLs" && in->is_configuration ) {
    string world = in->variables->MyWorldLocation[ VAR_VALUE ];
    if( !world || !sizeof(world) )
      in->set( "MyWorldLocation", get_world(val)||"" );
  }

  if( in->set )
    in->set( v, val );
  else
    var[ VAR_VALUE ] = val;

  if( in->save_me )
  {
    remove_call_out( in->save_me );
    call_out( in->save_me, 1 );
  }
  else if( in->save )
  {
    remove_call_out( in->save );
    call_out( in->save, 1 );
  } else {
    if( in->my_configuration )
    {
      in = in->my_configuration();
      remove_call_out( in->save );
      call_out( in->save, 1 );
    }
  }
  return warning;
}

string get_var_form( string s, object mod, object id )
{
  string path = "";
  int view_mode;

  if( mod == roxen )
  {
    if( !CU_AUTH( "Edit Global Variables" ) )
      view_mode = 1;
  } else if( mod->register_module ) {
    if( !CU_AUTH( "Edit Module Variables" ) )
      view_mode = 1;
  } else if( mod->find_module && mod->Priority ) {
    if( !CU_AUTH( "Edit Site Variables" ) )
      view_mode = 1;
  }

  if( mod->my_configuration )
    path = (mod->my_configuration()->name + "/"+
            replace(mod->my_configuration()->otomod[ mod ], "#", "!")+
            "/"+s);
  else if( mod->name )
    path = (mod->name+"/"+s);
  else
    path = s;

  string pre = "";
  path = html_encode_string( replace( path, " " , "_" ) )-"\"";

  if( id->variables[ path ] )
    pre = set_variable( s, mod, id->variables[ path ], id );

  array var = mod->variables[ s ];
  if( !var_configurable( var,id ) )
    return 0;

  switch(var[VAR_TYPE])
  {
   case TYPE_CUSTOM:
     return pre + var[VAR_MISC][1]( var, path );
     break;
   case TYPE_TEXT_FIELD:
     if( view_mode )
       return "<b><tt>"+replace(html_encode_string(var[VAR_VALUE]||""),
                            "\n", "<br")+"</tt></b>";
     return pre + "<textarea name=\""+path+"\" cols=50 rows=10>"
            + html_encode_string(var[VAR_VALUE]||"")
            + "</textarea>";
     break;
   case TYPE_PASSWORD:
     if( view_mode )
       return "<b>Password</b>";
     return pre + "<input name=\""+path+"\" type=password size=30>";
    break;

   case TYPE_FONT:
     if( view_mode )
       return "<b>"+html_encode_string(var[VAR_VALUE])+"</b>";
     array select_from;
     select_from=sort( available_fonts() );
     string res= pre + "<select name="+path+">";
     foreach(map( select_from, replace, "_", " " ), string f)
     {
       if( search( f, "\0" ) != -1 )
         continue; /* f -= "\0"; // Presumably a bug in Image.TTF. */
       if( strlen( f ) )
       {
         res += "<option"+((f == replace(var[VAR_VALUE],"_"," "))?
                           " selected":"")+">"+f+"\n";
       }
     }
     return res+ "</select>";

   case TYPE_STRING:
   case TYPE_FILE:
   case TYPE_DIR:
   case TYPE_LOCATION:
     if( view_mode )
       return "<b>"+html_encode_string(var[VAR_VALUE])+"</b>";
     return pre+input(path, html_encode_string(var[VAR_VALUE]), 30);

   case TYPE_FLOAT:
     if( view_mode )
       return "<b>"+var[VAR_VALUE]+"</b>";
     return pre+input(path, sprintf( "%.3f", var[VAR_VALUE]), 10);

   case TYPE_INT:
     if( view_mode )
       return "<b>"+var[VAR_VALUE]+"</b>";
     return pre+input(path, var[VAR_VALUE], 10);

   case TYPE_THEME: /* config-if local type... */
     array a = all_themes( );
     sort( map(a,theme_name), a );
     string tmp="<select name=\""+path+"\">  ";
     foreach( a, string q )
     {
       if( q == var[VAR_VALUE] )
         tmp += "<option selected value='"+q+"'>"+theme_name(q);
       else
         tmp += "<option value='"+q+"'>"+theme_name(q);
     }
     return pre+tmp+"</select>";

   case TYPE_DIR_LIST:
   case TYPE_STRING_LIST:
   case TYPE_INT_LIST:
    if(var[VAR_MISC])
    {
      string tmp, res="";
      array misc;
      mapping translate;
      int i;

      tmp="<select name=\""+path+"\">  ";
      misc=var[ VAR_MISC ];
      translate = LOW_LOCALE->module_doc_string(mod, s, 2);
      if(!translate) translate = ([]);

      int found = 0;
      for(i=0; i<sizeof(misc); i++)
      {
	if(misc[i]==var[VAR_VALUE])
        {
	  found = 1;
          if( view_mode )
            return "<b>"+html_encode_string((string)(translate[misc[i]]||misc[i]))+"</b>";
	  tmp+=("  <option value=\""+
		replace((string)misc[i],"\"","&quote;")
		+ "\" selected> "+
		(translate[misc[i]] || misc[i])+" ");
        }
 	else
	  tmp+=("  <option value=\""+
		replace((string)misc[i],"\"","&quote;")+ "\"> "+
		(translate[misc[i]] || misc[i])+" ");
      }
      if (!found) {		// To avoid user confusion.
	if( view_mode )
	  return "<b>"+html_encode_string(
	    (string)(translate[var[VAR_VALUE]]||var[VAR_VALUE]))+"</b>";
	tmp+=("  <option value=\""+
	      replace((string)var[VAR_VALUE],"\"","&quote;")
	      + "\" selected> "+
	      (translate[var[VAR_VALUE]] || var[VAR_VALUE])+" ");
      }
      return pre+tmp+"</select>";
    }
    if( view_mode )
      return "<b><tt>"+html_encode_string((((array(string))var[VAR_VALUE])*","))+"</tt></b>";
    return pre+input( path, ((array(string))var[VAR_VALUE])*", ", 40 );


   case TYPE_FLAG:
    if( view_mode )
      return "<b>"+(var[VAR_VALUE]?LOW_LOCALE->yes:LOW_LOCALE->no)+"</b>";
     string res = "<select name="+path+"> ";
     if(var[VAR_VALUE])
       res +=  ("<option value=Yes selected>"+LOW_LOCALE->yes+
                "<option value=No>"+LOW_LOCALE->no);
     else
       res +=  ("<option value=Yes>"+LOW_LOCALE->yes+
                "<option value=No selected>"+LOW_LOCALE->no);
     return pre+res + "</select>";
    break;

  }
}

string get_var_type( string s, object mod, object id )
{
  int flag = !!mod->variables[ s ][ VAR_MISC ];
  switch( mod->variables[ s ][ VAR_TYPE ] )
  {
   case TYPE_CUSTOM:
   case TYPE_TEXT_FIELD:
   case TYPE_STRING:
   case TYPE_FLAG:
   case TYPE_FONT:
     break;

   case TYPE_MODULE:
    return LOCALE->module_hint();

   case TYPE_LOCATION:
    return LOCALE->location_hint();

   case TYPE_FILE:
    return LOCALE->file_hint();

   case TYPE_DIR:
    return LOCALE->dir_hint();

   case TYPE_FLOAT:
    return LOCALE->float_hint();

   case TYPE_INT:
    return LOCALE->int_hint();

   case TYPE_STRING_LIST:
    if(!flag)
      return LOCALE->stringlist_hint();
    break;

   case TYPE_DIR_LIST:
    if(!flag)
      return LOCALE->dirlist_hint();
    break;

   case TYPE_PASSWORD:
     return LOCALE->password_hint();

   case TYPE_INT_LIST:
    if(!flag)
      return LOCALE->intlist_hint();
    break;
  }
  return "";
}

mapping get_variable_map( string s, object mod, object id )
{
  return ([
    "sname":s,
    "rname": get_var_doc( s, mod, 0, id ),
    "doc":  (config_setting2( "docs" )?
             get_var_doc( s, mod, 1, id ):""),
    "name": get_var_doc( s, mod, 2, id ),
    "value":get_var_value( s, mod, id ),
    "type":mod->type,
    "type_hint":(id->misc->config_settings->query("docs")?
                  get_var_type( s, mod, id ):""),
    "form": get_var_form( s, mod, id ),
  ]);
}

int var_configurable( array var, object id )
{
  if( mixed cf = var[ VAR_CONFIGURABLE ] )
  {
    if(functionp(cf) &&
       cf( config_setting2("more_mode"),
           config_setting2("expert_mode"),
           config_setting2("devel_mode"),
           (int)id->variables->initial))
    {
      return 0;
    }
    else if( intp( cf ) )
    {
      if((int)id->variables->initial && !(cf&VAR_INITIAL))      return 0;
      if((cf & VAR_EXPERT) && !config_setting2("expert_mode"))   return 0;
      if((cf & VAR_MORE) && !config_setting2("more_mode"))       return 0;
      if((cf & VAR_DEVELOPER) && !config_setting2("devel_mode")) return 0;
    }
    return 1;
  }
  return 0;
}

mapping get_variable_section( string s, object mod, object id )
{
  if( s[0] == '_' )
    return 0;
  array var = mod->variables[ s ];
  if( !var_configurable( var,id ) )
    return 0;

  s = LOW_LOCALE->module_doc_string( mod, s, 0 );
  if( !s ) return 0;
  if( sscanf( s, "%s:%*s", s ) )
    return ([
      "section":s,
      "selected":(id->variables->section==s?"selected":"")
    ]);
  else
    return ([
      "section":"Settings",
      "selected":
      ((id->variables->section=="Settings"||!id->variables->section)?
       "selected":""),
    ]);
  return 0;
}

array get_variable_maps( object mod, mapping m, object id )
{
  array variables = map( indices(mod->variables),get_variable_map,mod,id);

  variables = filter( variables,
                      lambda( mapping q ) {
                        return q->form &&
                               strlen(q->sname) &&
                               (q->sname[0] != '_');
                      } );
  map( variables, lambda( mapping q ) {
                    if( search( q->form, "<" ) != -1 )
                      q->form=("<font size=-1>"+q->form+"</font>");
                  } );

  if( m->section && (m->section != "_all"))
  {
    if( !strlen( m->section ) || (search( m->section, "Settings" ) != -1 ))
      variables = filter( variables,
                          lambda( mapping q )
                          {
                            return search( q->rname, ":" ) == -1;
                          } );
    else
      variables = filter( variables,
                       lambda( mapping q )
                       {
                         return search( q->rname, m->section )!=-1;
                       } );
  }
  sort( variables->name, variables );
  return variables;
}

array get_variable_sections( object mod, mapping m, object id )
{
  mapping w = ([]);
  array variables = map(indices(mod->variables),get_variable_section,mod,id);
  variables = Array.filter( variables-({0}),
                       lambda( mapping q ) {
                         return !w[ q->section ]++;
                       });
  sort( variables->section, variables );
  return variables;
}

object(Configuration) find_config_or_error(string config)
{
  object(Configuration) conf = roxen->find_configuration(config);
  if (!conf)
    error("Unknown configuration %O\n", config);
  return conf;
}

mapping get_port_map( object p )
{
  return ([
    "port":p->get_key(),
    "name":p->name+"://"+(p->ip||"*")+":"+p->port+"/",
  ]);
}

mapping get_url_map( string u, mapping ub )
{
  return ([
    "url":u,
    "conf":replace(ub[u]->conf->name, " ", "-" ),
    "confname":ub[u]->conf->query_name(),
  ]);
}

string container_configif_output(string t, mapping m, string c, object id)
{
  array(mapping) variables;
  switch( m->source )
  {
   case "config-settings":
     variables = get_variable_maps( id->misc->config_settings, m, id );
     break;

   case "locales":
     object rl = RoxenLocale;
     variables = map( sort(indices(rl) - ({ "Modules", "standard" })),
                      lambda( string l )
                      {
                        string q = id->not_query;
                        string tmp;
                        multiset cl = (<>);
                        sscanf( q, "/%[^/]/%s", tmp, q );
                        cl[ tmp ] = 1;
                        cl[ LOW_LOCALE->latin1_name ] = 1;
                        if( LOW_LOCALE->latin1_name == "standard" )
                          cl[ "english" ] = 1;
                        if( !rl[l] )
                          return 0;
                        return ([
                          "name":rl[l]->name,
                          "latin1-name":rl[l]->latin1_name,
                          "path":fix_relative( "/"+l+"/"+ q +
                                               (id->misc->path_info?
                                                id->misc->path_info:"")+
                                               (id->query&&sizeof(id->query)?
                                                "?" +id->query:""),
                                               id),
                          "selected":( cl[l] ? "selected": "" ),
                          "-selected":( cl[l] ? "-selected": "" ),
                          "selected-int":( cl[l] ? "1": "0" ),
                        ]);
                      } ) - ({ 0 });
     break;

   case "global-modules":
     break;

   case "config-modules":
     object conf = find_config_or_error( m->configuration );

     variables = ({ });
     foreach( values(conf->otomod), string q )
     {
       object mi = roxen->find_module((q/"#")[0]);
       variables +=
       ({
         ([
           "sname":replace(q, "#", "!"),
           "name":mi->get_name()+((int)reverse(q)?" # "+ (q/"#")[1]:""),
           "doc":mi->get_description(),
         ]),
       });
     }
     sort( variables->name, variables );
     break;

   case "config-variables":
     object conf = find_config_or_error( m->configuration );

     variables = get_variable_maps( conf, m, id );
     break;

   case "ports":
     array pos = roxen->all_ports();
     sort( pos->get_key(), pos );
     variables = map( pos, get_port_map );
     int sel;
     foreach( variables, mapping v )
       if( v->port == id->variables->port )
       {
         v->selected = "selected";
         sel=1;
       }
     break;

   case "port-variables":
     catch {
       variables = get_variable_maps( roxen->find_port( m->port ), ([]), id );
     };
     break;

   case "port-urls":
     mapping u = roxen->find_port( m->port )->urls;
     variables = map(indices(u),get_url_map,u);
     break;

   case "config-variables-sections":
     object conf = find_config_or_error( m->configuration );

     variables = get_variable_sections( conf, m, id );
     break;

   case "urls":
     break;

   case "module-variables":
     object conf = find_config_or_error( m->configuration );

     object mod = conf->find_module( replace( m->module, "!", "#" ) );
     if( !mod )
       error("Unknown module "+ m->module +"\n");
     variables = get_variable_maps( mod, m, id );
     break;

   case "module-variables-sections":
     object conf = find_config_or_error( m->configuration );
     object mod = conf->find_module( replace( m->module, "!", "#" ) );
     if( !mod )
       error("Unknown module "+ m->module +"\n");
     variables =get_variable_sections( mod, m, id )|  ({ ([
       "section":"Information",
       "selected":
       (((id->variables->section=="Information")||
         !id->variables->section)?
        "selected":""),
     ]) });

     if( sizeof( variables ) == 1 )
     {
       while( id->misc->orig )
         id = id->misc->orig;
       id->variables->info_section_is_it = "1";
       variables[0]->selected="selected";
     }

     int hassel;
     foreach( reverse(variables), mapping q )
     {
       if( hassel )
         q->selected = "";
       else
         hassel = strlen(q->selected);
     }
     hassel=0;
     foreach( reverse(variables), mapping q )
     {
       if( q->selected == "selected")
       {
         hassel = 1;
         break;
       }
     }
     if(!hassel)
       variables[0]->selected="selected";
     variables = reverse(variables);
     variables[0]->first = " first ";
     variables[-1]->last = " last=30 ";
     break;

   case "global-variables-sections":
     variables = get_variable_sections( roxen, m, id );
     variables[0]->last = "last";
     variables[-1]->first = "first";
     break;

   case "global-variables":
     variables = get_variable_maps( roxen, m, id );
     break;


   case "configurations":
     variables = map( roxen->configurations,
                      lambda(object o ) {
                        return ([
                          "name":o->query_name(),
                          "sname":replace(lower_case(o->name),
                                          ({" ","/","%"}),
                                          ({"-","-","-"}) ),
                        ]);
                      } );

     sort(variables->name, variables);
     break;

   default:
     RXML.parse_error("Invalid output source: "+m->source+"\n");
  }
  m_delete( m, "source" );

#ifndef SERIOUS
  return replace(do_output_tag( m, variables, c, id ), "Default Theme", "Toxic Orange");
#endif

  return do_output_tag( m, variables, c, id );
}

string container_theme_path( string t, mapping m, string c, object id )
{
  while( id->misc->orig ) id = id->misc->orig;
  if( glob( "*"+m->match, id->not_query ) )
    return c;
  return "";
}

string tag_theme_set( string t, mapping m, object id )
{
  if( !id->misc->cf_theme )
    id->misc->cf_theme = ([]);
  if( m->themefile )
    m->to = "/standard/themes/"+config_setting2( "theme" )+"/"+m->to;
  if( m->integer )
    m->to = (int)m->to;
  id->misc->cf_theme[ m->what ] = m->to;
  return "";
}

string container_rli( string t, mapping m, string c, object id )
{
  return "<tr>"
         "<td valign=top><img src=&usr.count-"+(++id->misc->_rul_cnt&3)+
         ";></td><td valign=top>"+ c+"</td></tr>\n";
}

string container_rul( string t, mapping m, string c, object id )
{
  id->misc->_rul_cnt = -1;
  return "<table>"+c+"</table>";
}

string container_cf_perm( string t, mapping m, string c, RequestID id )
{
  if( !id->misc->config_user ) return "";
  return CU_AUTH( m->perm )==!m->not ? c : "";
}

string container_cf_userwants( string t, mapping m, string c, RequestID id )
{
  return config_setting2( m->option ) ? c : "";
}
