inherit "module";
inherit "html";
inherit "roxenlib";
#include <roxen.h>
#include <module.h>
#include <stat.h>

#define LOCALE	LOW_LOCALE->config_interface

constant module_type = MODULE_PARSER|MODULE_CONFIG;
constant module_name = "Configuration interface RXML tags";

string internal_topmenu_tag_item(string t, mapping m, 
				 mapping c, RequestID id)
{
  c->them += ({ m });
}

string internal_c_topmenu(string t, mapping m, string d, mapping c, RequestID id)
{
  mixed items = (["them":({})]);
  
  mapping a = ([]);
  parse_html( d, (["item":internal_topmenu_tag_item]), a, items, id );

  items = items->them;

  c->top=("<table cellpadding=0 cellspacing=0 border=0><tr><td>"
	  "<img src=/internal-roxen-unit width=30 height=10></tr>"
	  "<td valign=bottom>"
	  "<img src=/internal-roxen-unit width=1 height=6><br>");

  foreach(items, mapping i)
  {
    string color, fgcolor;
    if(i->selected)
    {
      color = "$TOP_SELECTED_BG$";
      fgcolor = "$TOP_SELECTED_FG$";
    }
    else
    {
      color = "$TOP_TAB_BG$"; 
      fgcolor = "$TOP_TAB_FG$";
    }

    c->top += (submit_gtxt( "goto_"+i->href,
                           ([
                             "fg":fgcolor, 
                             "bg":color,
                             "afont":"haru",
                             "scale":"0.5",
                             "spacing":"2",
                             "xspacing":"20",
                             "notrans":"notrans",
                           ]),
                           i->title,
                           id ) +
               "<img src=/internal-roxen-unit width=10 height=1>");
  }
  c->top += "</td></tr></table>";
  return "";
}

string i_lmenu_tag_item(string t, mapping m, string d, mapping c, RequestID id)
{
  mapping a = ([]);
  mixed items = (["them":({})]);
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
string present_items(array i, int ind, object id)
{
  string res="";
  foreach(i, mapping item)
  {
    string foreground = "$LEFT_FG$";
    if(item->selected)
    {
      res += ("<table cols=1 width=100% cellpadding=0 cellspacing=0 border=0>\n"
	      "<tr>\n<td bgcolor=\"$LEFT_SELECTED_BG$\">\n");
      foreground = "$LEFT_SELECTED_FG$";
    }


    res+=("<nobr>"+
          submit_gtxt( "goto_"+item->href,
                       ([ "scale":(string)(0.55-ind*0.05),
                          "fg":foreground,
                       ]),
                       (" "*(ind*4+2))+(item->title),
                       id )+
          "</nobr><br>\n");
    if(item->selected)
      res += "</td>\n</tr></table>\n";
    res += present_items(item->items,ind+1,id);
  }
  return res;
}

string internal_c_leftmenu(string t, mapping m, string d, mapping c, RequestID id)
{
  mixed items = (["them":({})]);
  
  mapping a = ([]);
  parse_html( d, a, (["item":i_lmenu_tag_item]), items, id );
  items = items->them;

  if( !m->title )
    m->title = "";
  c->left += "<gtext verbatim afont=haru font_size=40 scale=0.5 fg=#dcefff> "+
    (m->title/""*" ")+
    "</gtext><br>\n<img src=/internal-roxen-unit height=3 width=1><br>\n" 
             + present_items( items,0,id );
  return "";
}

string internal_c_middle(string t, mapping m, string d, mapping c,RequestID id)
{
  c->middle = ("\n<b><smallcaps space>"+m->title+
	       "</smallcaps></b><br>\n"+d+"\n");
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

constant colors_from = 
({ 
  "$LEFT_SELECTED_BG$",   "$LEFT_SELECTED_FG$", 
  "$LEFT_BG$",   "$LEFT_FG$", 
  "$TOP_SELECTED_BG$",   "$TOP_SELECTED_FG$", 
  "$TOP_TAB_BG$",   "$TOP_TAB_FG$", 
  "$TOP_BG$",   "$TOP_FG$", 
  "$TITLE_BG$",   "$TITLE_FG$", 
  "$CONTENT_BG$",  "$CONTENT_FG$",
});

string container_roxen_config(string t, mapping m, string data, RequestID id)
{
  int _start = gethrtime();
#define PAGECOLOR "#e7e7e7"
  string left_bg = "#003366",       left_fg = "white",
         left_selected_bg=PAGECOLOR,left_selected_fg = "black",
         top_bg="#003366",          top_fg="black",
         top_selected_bg=PAGECOLOR, top_selected_fg="black",
         top_tab_bg = "#7e7e7e",    top_tab_fg = "black",
         content_bg=PAGECOLOR,      content_fg="black",
         title_bg="white",          title_fg="black";

#define VC(c) if(id->variables->c)id->misc->c=c=id->variables->c;if(id->misc->c)c=id->misc->c;

  VC(left_selected_bg); VC(left_selected_fg);
  VC(left_bg);          VC(left_fg);
  VC(top_selected_bg);  VC(top_selected_fg);
  VC(top_tab_bg);       VC(top_tab_fg);
  VC(top_bg);           VC(top_fg);
  VC(content_bg);       VC(content_fg);
  VC(title_bg);         VC(title_fg);

  mapping c = ([
    "title":"",
    "left":"",
    "top":"",
    "content":"",
    "middle":"",
  ]);


  array colors_to = ({
    left_selected_bg, left_selected_fg, 
    left_bg,          left_fg, 
    top_selected_bg,  top_selected_fg, 
    top_tab_bg,       top_tab_fg, 
    top_bg,           top_fg, 
    title_bg,         title_fg, 
    content_bg,       content_fg,
  });

  string rest;
  rest = replace(parse_html(data,([]), 
			    ([ 
			      "middle":internal_c_middle,
			      "top-menu":internal_c_topmenu,
			      "left-menu":internal_c_leftmenu,
			      "content":internal_c_content,
			    ]), c, id), colors_from, colors_to);
    

//   foreach(indices(c), string s)
//     c[s] = replace( c[s], colors_from, colors_to );

  c->title = table(tr(td("<img src=/internal-roxen-unit width=10 height=1>"
			 "<img src=/internal-roxen-roxen-small>") +
		      td("<img src=/internal-roxen-unit width=10 height=1>",
			 "width=10")+
		      td("<img src=/internal-roxen-unit height=6 width=1><br>"+
			 "<font color=$TITLE_FG$>"+c->middle+"</font>",
			 "valign=top align=right width=101%")),  
                   "bgcolor=$TITLE_BG$" );

  // +  td("<img src=/internal-roxen-pike-small>")


#define NCOLS 3
#define TTDEF "width=101%"
  string page = 
    c->title+
// 	  tr(td("<img src=/internal-roxen-unit width=1 height=5>",
// 		"colspan="+NCOLS+" width=1 height=5")) +
    table(tr(td(c->top,
                "align=right valign=bottom colspan="+NCOLS+
                " bgcolor=$TOP_BG$ height=25")),TTDEF)+
    "<img src=/internal-roxen-unit height=3 width=1 alt=\"\"><br>"+
    table(tr(
//          td("<img src=/internal-roxen-unit width=3 height=1>",
//  	        "width=2 bgcolor=$CONTENT_BG$")+
	     td(c->left,
		"valign=top height=80% width=300 bgcolor=$LEFT_BG$")+
	     td("<img alt=\"\" src=/internal-roxen-unit height=1 width=3>",
		"width=3 bgcolor=$CONTENT_BG$")+
	     td("<font color=$CONTENT_FG$>"+c->content+"</font>&nbsp;",
		"width=100% valign=top bgcolor=$CONTENT_BG$")) +
//     tr(td("")*(NCOLS-1)+
//        td("<font size=-1>"+roxen->real_version+"</font>",
//           "width=100% align=right"), 
//        "bgcolor=$CONTENT_BG$ width=100%"),
        "",
    TTDEF+" height=80%");
  

    return rest+replace(page, colors_from, colors_to);
//   return table(tr(td(page, "width=101% height=100%"), 
// 		  "valign=top height=200")+
// 		,
// 		"height=100% width=101% bgcolor=\""+content_bg+"\"");
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
     break;

   case TYPE_PASSWORD:
     if( val == "" )
       return "";

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
           if( !(file_stat( d ) && (file_stat( d )[ ST_SIZE ] == -2 )))
             warning += "<font color=darkred>"+d+
                     " is not a directory</font><br>";
     } else {
       if( var[VAR_TYPE]  == TYPE_INT_LIST )
         val = (int)val;
       mapping translate = 
               LOW_LOCALE->module_doc_string(in, v, 2);
      if(!translate)
	translate = mkmapping(var[ VAR_MISC ],var[ VAR_MISC ]);
      mixed tmp;
      if( ( tmp = search( translate, val ) )||
          search( var[ VAR_MISC ], val ) != -1 )
        return "";
      val = tmp;
     }
     break;

   case TYPE_FLAG:
     if( val == "Yes" || val == LOW_LOCALE->yes )
       val = 1;
     else
       val = 0;
     break;
   default:
     werror("Unknown variable type\n");
     return "";
  }
  if( equal( var[ VAR_VALUE ], val ) )
    return "";
  if( stringp(val) )
    val = utf8_to_string(val);
  if( arrayp( val ) )
    val = map( val, lambda( mixed q ) { 
                      if(stringp(q)) 
                        return utf8_to_string(q);
                      return q;
                    } );
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
  if( mixed cf = var[VAR_CONFIGURABLE] )
  {
    if(functionp(cf) && cf( id ))
      return 0;
    else if( intp( cf ) )
    {
      if((cf & VAR_EXPERT) && !id->misc->expert_mode)
        return 0;
      if((cf & VAR_MORE) && !id->misc->more_mode)
        return 0;
    }
  } else
    return 0;

  switch(var[VAR_TYPE])
  {
   case TYPE_CUSTOM:
     return pre + var[VAR_MISC][1]( var, path );
     break;
   case TYPE_TEXT_FIELD:
     return pre + "<textarea name=\""+path+"\" cols=50 rows=10>"
            + html_encode_string(var[VAR_VALUE]||"")
            + "</textarea>";
     break;
   case TYPE_PASSWORD:
     return pre + "<input name=\""+path+"\" type=password size=30,1>";
    break;
    
   case TYPE_FONT:
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
     return input(path, var[VAR_VALUE], 30);

   case TYPE_FLOAT:
     return input(path, sprintf( "%.3f", var[VAR_VALUE]), 10);

   case TYPE_INT:
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
	  tmp+=("  <option value=\""+
		replace((string)misc[i],"\"","&quote;")
		+ "\" selected> "+
		translate[misc[i]]+" ");
 	else
	  tmp+=("  <option value=\""+
		replace((string)misc[i],"\"","&quote;")+ "\"> "+
		translate[misc[i]]+" ");
      }
      return tmp+"</select>";
    }
    return input( path, ((array(string))var[VAR_VALUE])*", ", 60 );


   case TYPE_FLAG:
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
     break;

   case TYPE_MODULE:
    return LOCALE->module_hint();

   case TYPE_FONT:
    return LOCALE->font_hint();

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
    "type_hint":(id->misc->config_settings->query("docs")?
                  get_var_type( s, mod, id ):""),
    "form": get_var_form( s, mod, id ),
  ]);
}

mapping get_variable_section( string s, object mod, object id )
{
  array var = mod->variables[ s ];
  if( mixed cf = var[VAR_CONFIGURABLE] )
  {
    if(functionp(cf) && cf( id ))
      return 0;
    else if( intp( cf ) )
    {
      if((cf & VAR_EXPERT) && !id->misc->config_settings->query("expert_mode"))
        return 0;
      if((cf & VAR_MORE) && !id->misc->config_settings->query("more_mode"))
        return 0;
      if((cf & VAR_DEVELOPER) && 
         !id->misc->config_settings->query("devel_mode"))
        return 0;
    }
  } else
    return 0;

  s = LOW_LOCALE->module_doc_string( mod, s, 0 );
  if( !s ) return 0;
  if( sscanf( s, "%s:%*s", s ) )
    return ([ "section":s ]);
  return 0;
}

array get_variable_maps( object mod, mapping m, object id )
{
  array variables = map( indices(mod->variables),get_variable_map,mod,id);
  variables = Array.filter( variables, 
                            lambda( mapping q ) {
                              return q->form;
                            } );
  if( m->section )
  {
    if( !strlen( m->section ) || (search( m->section, "section" ) != -1 ))
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
                         return !w[q->section]++;
                       });
  sort( variables->section, variables );
  return variables;
}

string container_cf_dirlist( string t, mapping m, string c, object id )
{
  
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
     object conf = roxen->find_configuration( m->configuration );
     if( !conf )
       error("Unknown configuration\n");
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
     object conf = roxen->find_configuration( m->configuration );
     if( !conf )
       error("Unknown configuration "+ m->configuration +"\n");
     variables = get_variable_maps( conf, m, id );
     break;

   case "config-variables-sections":
     object conf = roxen->find_configuration( m->configuration );
     if( !conf )
       error("Unknown configuration "+ m->configuration +"\n");
     variables = get_variable_sections( conf, m, id );
     break;

   case "urls":
     break;

   case "module-variables":
     object conf = roxen->find_configuration( m->configuration );
     if( !conf )
       error("Unknown configuration "+ m->configuration +"\n");
     object mod = conf->find_module( replace( m->module, "!", "#" ) );
     if( !mod )
       error("Unknown module "+ m->module +"\n");
     variables = get_variable_maps( mod, m, id );
     break;

   case "module-variables-sections":
     object conf = roxen->find_configuration( m->configuration );
     if( !conf )
       error("Unknown configuration "+ m->configuration +"\n");
     object mod = conf->find_module( replace( m->module, "!", "#" ) );
     if( !mod )
       error("Unknown module "+ m->module +"\n");
     werror("sections in "+m->module+" in "+conf->name+"\n");
     variables = get_variable_sections( mod, m, id );
     break;

   case "global-variables-sections":
     variables = get_variable_sections( roxen, m, id );
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
  //+ (id->misc->path_info||"")
  int depth = sizeof( (id->not_query )/"/" )-3;
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
