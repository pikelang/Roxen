inherit "module";
inherit "html";
inherit "roxenlib";
#include <roxen.h>
#include <module.h>
#include <stat.h>
#include <config_interface.h>

#define LOCALE	LOW_LOCALE->config_interface
#define CU_AUTH id->misc->config_user->auth

constant module_type = MODULE_PARSER|MODULE_CONFIG;
constant module_name = "Configuration interface RXML tags";

void start(int num, Configuration conf)
{
  conf->parse_html_compat=1;
}

void create() {
  query_tag_set()->prepare_context=set_entities;
}

class Scope_usr
{
  inherit RXML.Scope;

  mixed `[]  (string var, void|RXML.Context c, void|string scope)
  {
    object id = c->id;
    switch( var )
    {
     case "linkcolor":
       object c1 = Image.Color( config_setting( "bgcolor" ) );
       if(!c1)
         c1 = Image.Color.black;
       if( `+(0,@(array)c1) < 200 )
         return (string)Image.Color.lightblue;
       return (string)Image.Color.darkblue;

     case "fade1":
       object c1 = Image.Color( config_setting( "bgcolor" ) );
       if(!c1)
         c1 = Image.Color.black;
       if( `+(0,@(array)c1) < 200 )
         return (string)Image.Color(@map(map((array)c1, `+, 0x21 ),min,255));
       return (string)Image.Color(@map(map( (array)c1, `-, 0x11 ),max,0) );

     case "fade2":
       object c1 = Image.Color( config_setting( "bgcolor" ) );
       if(!c1)
         c1 = Image.Color.black;
       if( `+(0,@(array)c1) < 200 )
         return (string)Image.Color( @map(map((array)c1, `+, 0x61 ),min,255));
       return (string)Image.Color( @map(map( (array)c1, `-, 0x51 ),max,0) );

     case "fade3":
       object c1 = Image.Color( config_setting( "bgcolor" ) );
       if(!c1) c1 = Image.Color.black;
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
       object c1 = Image.Color( config_setting( "bgcolor" ) );
       if(!c1) c1 = Image.Color.black;
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

void set_entities(RXML.Context c) {
  c->extend_scope("usr", usr_scope);
}

string internal_topmenu_tag_item(string t, mapping m,
				 mapping c, RequestID id)
{
  if( m->perm  &&
      (!id->misc->config_user || !CU_AUTH( m->perm )))
    return "";
  c->them += ({ m });
  return "";
}

string internal_c_topmenu(string t, mapping m, string d, mapping c, RequestID id)
{
  mixed items = (["them":({})]);

  mapping a = ([]);
  parse_html( d, (["item":internal_topmenu_tag_item]), a, items, id );

  items = items->them;

  c->top=( "<tablist bgcolor='"+config_setting2("fade3")+
           "' font='"+config_setting( "font" ) +"'>" );
  foreach(items, mapping i)
  {
    mapping targs = ([]);
    if(i->selected)
    {
      targs->selected = "selected";
      targs->bgcolor =  config_setting2( "fade3" );
      targs->selcolor = config_setting( "bgcolor" );
      targs->textcolor = config_setting( "fgcolor" );
    }
    else
    {
      targs->bgcolor =  config_setting2( "fade3" );
      targs->dimcolor = config_setting2( "fade2" );
      targs->textcolor = config_setting( "bgcolor" );
    }
    if( i->first ) targs->first=i->first;
    if( i->last )  targs->last=i->last;
    targs->href = i->href;
    c->top += make_container( "tab", targs, " "+i->title+" " );
  }
  c->top += "</tablist>";
  return "";
}

string i_lmenu_tag_item(string t, mapping m, string d, mapping c, RequestID id)
{
  mapping a = ([]);
  mixed items = (["them":({})]);
  if( m->perm  &&
     (!id->misc->config_user || !CU_AUTH( m->perm )))
    return "";
  parse_html( d, a, (["item":i_lmenu_tag_item]), items, id );
  m->items = items->them;
  c->them += ({ m });
  return "";
}

string submit_gtxt( string name, mapping gta, string cnts, object id )
{
  return "\n<cset preparse variable=___gtext>"+
         make_container( "gtext-url",gta,cnts)+"</cset>"
         "<formoutput quote=½>"+
         make_tag( "input",
                   ([ "name":name,
                      "type":"image",
                      "src":"½___gtext:quote=none½",
                      "border":"0",
                   ]) )+
         "</formoutput>\n";
}

constant nbsp = iso88591["&nbsp;"];
string internal_c_middle(string t, mapping m, string d, mapping c,RequestID id)
{
  c->middle = (d);
  return "";
}

string internal_c_content(string t, mapping m, string d, mapping c, RequestID id)
{
  // parse <var> with friends here...
  c->content = d;
  return "";
}

string indent(string what, int how)
{
  return " "*how + replace(what, "\n", ("\n" + " "*how));
}

string table(string data, string|void aa)
{
  if(!aa)
    aa = "";
  else
    aa=" "+aa;
  return "<table border=0 cellpadding=0 cellspacing=0 "+aa+">\n"+data+"\n</table>\n";
}

string tr(string data, string|void aa)
{
  if(!aa)
    aa = "";
  else
    aa=" "+aa;
  return "<tr"+aa+">"+data+"</tr>\n";
}

string td(string data, string|void aa)
{
  if(!aa)
    aa = "";
  else
    aa=" "+aa;
  return "<td"+aa+">"+data+"</td>\n";
}

string container_roxen_config(string t, mapping m, string data, RequestID id)
{
  int _start = gethrtime();

  mapping c = ([
    "title":"",
    "left":"",
    "top":"",
    "content":"",
    "middle":"",
  ]);


  string rest;
  rest = parse_html(data,([]),
                    ([
                      "middle":internal_c_middle,
                      "top-menu":internal_c_topmenu,
                      "content":internal_c_content,
                    ]), c, id);


//   c->title =
  string page =  #"
  <table width=100% cellpadding=0 cellspacing=0 border=0 bgcolor='"+config_setting2("fade3")+#"'>
    <tr bgcolor='"+config_setting2("fade3")+#"'>
      <td colspan=2>
       <table><tr><td>
         <img src=/internal-roxen-roxen-blue-small.gif xspacing=10>
         </td>
          <td><font color='"+config_setting2("fade4")+#"'><cf-locale get=administration_interface>
              </font></td></tr></table></td>
      <td align=right valign=top rowspan=2>"+c->middle+#"</td>
    </tr>
    <tr valign=bottom>
      <td colspan=2 valign=bottom>"+c->top+#"</td>
    </tr>
  </table>
";

  page += c->content;

  return page;
}

string get_var_doc( string s, object mod, int n, object id )
{
  s = LOW_LOCALE->module_doc_string( mod, s, (n==1) );
  if( !s ) return "";
  if( n==2 )
    sscanf( s, "%*s:%s", s );
  return s;
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
     break;

   case TYPE_DIR_LIST:
   case TYPE_STRING_LIST:
   case TYPE_INT_LIST:
     if( !var[ VAR_MISC ] )
     {
       val /= ",";
       int i;
       for( i = 0; i<sizeof( val ); i++ )
         val[i] = trim( val[i] );
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
//        mapping translate =
//                LOW_LOCALE->module_doc_string(in, v, 2);
//       if(!translate)
// 	translate = mkmapping(var[ VAR_MISC ],var[ VAR_MISC ]);
//       if( mixed tmp = search( translate, val ) )
//         val = tmp;
     }
     break;

   case TYPE_FLAG:
     if( val == "Yes" || val == LOW_LOCALE->yes )
       val = 1;
     else
       val = 0;
     break;
   default:
     werror("Unknown variable type ["+var[ VAR_TYPE ]+"]\n");
     return "";
  }
  if( equal( var[ VAR_VALUE ], val ) )
    return "";
// Already done...
//   if( stringp(val) )
//     val = utf8_to_string(val);
//   if( arrayp( val ) )
//     val = map( val, lambda( mixed q ) {
//                       if(stringp(q))
//                         return utf8_to_string(q);
//                       return q;
//                     } );
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
     return pre + "<input name=\""+path+"\" type=password size=30,1>";
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
         continue; /* f -= "\0"; // Presubaly a bug in Image.TTF. */
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
     return input(path, var[VAR_VALUE], 30);

   case TYPE_FLOAT:
     if( view_mode )
       return "<b>"+var[VAR_VALUE]+"</b>";
     return input(path, sprintf( "%.3f", var[VAR_VALUE]), 10);

   case TYPE_INT:
     if( view_mode )
       return "<b>"+var[VAR_VALUE]+"</b>";
     return input(path, var[VAR_VALUE], 10);

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
      if(!translate)
	translate = mkmapping(misc,misc);

      for(i=0; i<sizeof(misc); i++)
      {
	if(misc[i]==var[VAR_VALUE])
        {
          if( view_mode )
            return "<b>"+html_encode_string((string)translate[misc[i]])+"</b>";
	  tmp+=("  <option value=\""+
		replace((string)misc[i],"\"","&quote;")
		+ "\" selected> "+
		translate[misc[i]]+" ");
        }
 	else
	  tmp+=("  <option value=\""+
		replace((string)misc[i],"\"","&quote;")+ "\"> "+
		translate[misc[i]]+" ");
      }
      return tmp+"</select>";
    }
    if( view_mode )
      return "<b><tt>"+html_encode_string((((array(string))var[VAR_VALUE])*","))+"</tt></b>";
    return input( path, ((array(string))var[VAR_VALUE])*", ", 60 );


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
     return res + "</select>";
    break;

   case TYPE_COLOR:
     if (!intp( var[ VAR_VALUE ] ))
       var[ VAR_VALUE ] = 0;	// Black.. maybe not the best default color...
    return "<input name=" + path + " size=12 value= "
           + ((var[ VAR_VALUE ] >> 16) & 255)
           + ":" + ((var[ VAR_VALUE ] >> 8) & 255)
           + ":" + (var[ VAR_VALUE ] & 255)
           + ">"+"<input type=submit value="+LOW_LOCALE->ok+">";
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
   case TYPE_PORTS:
   case TYPE_FLAG:
   case TYPE_COLOR:
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
    "doc":  (id->misc->config_settings->query("docs")?
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
       cf( config_setting("more_mode"),
           config_setting("expert_mode"),
           config_setting("devel_mode"),
           (int)id->variables->initial))
    {
      return 0;
    }
    else if( intp( cf ) )
    {
      if((int)id->variables->initial && !(cf&VAR_INITIAL))      return 0;
      if((cf & VAR_EXPERT) && !config_setting("expert_mode"))   return 0;
      if((cf & VAR_MORE) && !config_setting("more_mode"))       return 0;
      if((cf & VAR_DEVELOPER) && !config_setting("devel_mode")) return 0;
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
      "section":"Misc",
      "selected":
      ((id->variables->section=="Misc"||!id->variables->section)?
       "selected":""),
    ]);
  return 0;
}

array get_variable_maps( object mod, mapping m, object id )
{
  array variables = map( indices(mod->variables),get_variable_map,mod,id);
  variables = Array.filter( variables,
                            lambda( mapping q ) {
                              return q->form &&
                                     strlen(q->sname) &&
                                     (q->sname[0] != '_');
                            } );
  if( m->section && (m->section != "all"))
  {
    if( !strlen( m->section ) || (search( m->section, "Misc" ) != -1 ))
      variables = Array.filter( variables,
                                lambda( mapping q )
                                {
                                  return search( q->rname, ":" ) == -1;
                                } );
    else
      variables = Array.filter( variables,
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

string container_cf_dirlist( string t, mapping m, string c, object id )
{

}

object(Configuration) find_config_or_error(string config)
{
  object(Configuration) conf = roxen->find_configuration(config);
  if (!conf)
    error("Unknown configuration %O\n", config);
  return conf;
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
     object rl = master()->resolv("Locale")["Roxen"];
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
     variables = get_variable_sections( mod, m, id ) |
     ({ ([
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
         hassel = 1;
     }
     if(!hassel)
       variables[0]->selected="selected";
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
     break;

   default:
     return "<b>Invalid output source: "+m->source+"</b>";
  }
  m_delete( m, "source" );

  return do_output_tag( m, variables, c, id );
}

string tag_cf_num_dotdots( string t, mapping m, object id )
{
  while( id->misc->orig ) id = id->misc->orig;
  int depth = sizeof( (id->not_query+(id->misc->path_info||"") )/"/" )-3;
  string dotodots = depth>0?(({ "../" })*depth)*"":"./";
  return dotodots;
}


array(string) tag_cf_current_url( string t, mapping m, object id )
{
  while ( id->misc->orig )
    id = id->misc->orig;
  return ({ id->not_query+(id->misc->path_info?id->misc->path_info:"") });
}

string tag_cf_locale( string t, mapping m, object id )
{
  mixed val;
  object q;

  if( m->section )
    q = LOW_LOCALE[ m->section ];

  if( !q || !(val = q[ m->get ] ) )
    if( !(val = LOCALE[ m->get ]) )
      val = LOW_LOCALE[ m->get ];

  if(!val)
    return "Unknown field: "+m->get;
  if( functionp( val ) )
    return val( );
  return val;
}

string container_cf_perm( string t, mapping m, string c, RequestID id )
{
  if( !id->misc->config_user )
    return "";
  return CU_AUTH( m->perm )==!m->not ? c : "";
}

string container_cf_userwants( string t, mapping m, string c, RequestID id )
{
  if( !id->misc->config_settings )
    return "";
  return id->misc->config_settings->query( m->option ) ? c : "";
}
