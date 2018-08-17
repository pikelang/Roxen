// This is a roxen module. Copyright © 1999 - 2009, Roxen IS.
//
inherit "module";
inherit "html";
inherit "roxenlib";
#include <stat.h>
#include <config_interface.h>
#include <config.h>
#include <roxen.h>
#include <module.h>
//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

#define CU_AUTH id->misc->config_user->auth

constant cvs_version = "$Id$";
constant module_type = MODULE_TAG|MODULE_CONFIG;
constant module_name = "Tags: Administration interface tags";

/* Not exactly true, but the config filesystem forbids parallell
 * accesses anyway so there is no need for an extra lock here..
 */
constant thread_safe = 1;

void create()
{
  query_tag_set()->prepare_context=set_entities;
}

protected mapping(int:string) css_font_size = ([
  -2: "x-small",
  -1: "small",
  //0: "medium",
  1: "large",
  2: "x-large",
]);

class Scope_cf
{
  inherit RXML.Scope;
  mixed `[]  (string var, void|RXML.Context c, void|string scope, void|RXML.Type type)
  {
    RequestID id = c->id;
    while( id->misc->orig ) id = id->misc->orig;
    switch( var )
    {
     case "num-dotdots":
       int depth = sizeof( (id->not_query+(id->misc->path_info||"") )/"/" )-2;
       string dotodots = depth>0?(({ "../" })*depth)*"":"./";
       return ENCODE_RXML_TEXT(dotodots, type);

     case "current-url":
       return ENCODE_RXML_TEXT(id->not_query+(id->misc->path_info||""), type);
    }
  }
}

class Scope_usr
{
  inherit RXML.Scope;

#define ALIAS( X ) `[](X,c,scope)
#define QALIAS( X ) (`[](X,c,scope)?"\""+roxen_encode(`[](X,c,scope),"html")+"\"":0)

  mixed `[]=( string var, mixed value, void|RXML.Context c,
	      void|string scope, void|RXML.Type type)
  {
    object s = c->id->misc->config_settings;
    Variable.Variable v;
    if( v = s->getvar( var ) )
      v->set( value );
    else
      s->definvisvar( var, value, TYPE_STRING );
    s->save();
  }

  protected string fade_color( int color_type, object c1,
			       RXML.Context c, string scope, RXML.Type type)
  {
    int add;
    switch( color_type )
    {
      case 1:  add = 0x21;color_type=1; break;
      case 2:  add = 0x61;color_type=1; break;
      case 11: add = 0x05;color_type=2; break;
      case 12: add = 0x15;color_type=2; break;
      case 21: add = 0x25;color_type=2; break;
      case 22: add = 0x35;color_type=2; break;
    }
    switch( color_type )
    {
      case 1: /* RGB */
	if( `+(0,@(array)c1) < 200 )
	  return (string)Image.Color( @map(map((array)c1,`+,add),min,255));
	return (string)Image.Color(@map(map((array)c1, `-,(add-0x10)),max,0));
      case 2: /* HSV */
	c1=Image.Color.guess(ALIAS("content-bg"));
	array hsv = c1->hsv();
	if( !hsv[2]  )
	  hsv[2] = add;
	else
	  hsv[2] = max( hsv[2]-add, 0);
	return ENCODE_RXML_TEXT( (string)Image.Color.hsv(@hsv), type);
    }
  }

  mixed `[]  (string var, void|RXML.Context c, void|string scope, void|RXML.Type type)
  {
    RequestID id = c->id;

    if( id->misc->cf_theme &&
        id->misc->cf_theme[ var ] )
      return id->misc->cf_theme[ var ];

    object c1;

    switch( var )
    {
      string q, res;
     case "left-buttonwidth": return "150";
     case "gbutton-width": return ENCODE_RXML_INT(0, type);

      /* composite */
     case "count-0": return ENCODE_RXML_TEXT("/internal-roxen-count_0", type);
     case "count-1": return ENCODE_RXML_TEXT("/internal-roxen-count_1", type);
     case "count-2": return ENCODE_RXML_TEXT("/internal-roxen-count_3", type);
     case "count-3": return ENCODE_RXML_TEXT("/internal-roxen-count_2", type);


     case "toptabs-padwidth": return ENCODE_RXML_INT(50, type);
     case "leftside-padwidth": return ENCODE_RXML_INT(150, type);
     case "leftside-padheight": return ENCODE_RXML_INT(1, type);
     case "logo-html":
       return ENCODE_RXML_XML("<imgs border=\"0\" src="+QALIAS("logo")+" />", type);

     case "toptabs-args":
       res = "frame-image="+QALIAS("toptabs-frame");
       if( ALIAS("top-bgcolor") != "none" )
         res += " pagebgcolor="+QALIAS("top-bgcolor");
       else
         res += " pagebgcolor="+QALIAS("bgcolor");
       res += " bgcolor="+QALIAS("toptabs-bgcolor" );
       res += " font="+QALIAS("toptabs-font" );
       res += " dimcolor="+QALIAS("toptabs-dimcolor" );
       res += " textcolor="+QALIAS("toptabs-dimtextcolor" );
       res += " seltextcolor="+QALIAS("toptabs-seltextcolor" );
       res += " selcolor="+QALIAS("toptabs-selcolor" );
       res += " quant=128";
       if( stringp( q = ALIAS("toptabs-extraargs" ) ) )
         res += " "+q;
       return ENCODE_RXML_XML(res, type);

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
       if( ALIAS("bgcolor") != "none" )
         res += " pagebgcolor="+QALIAS("bgcolor");
       return ENCODE_RXML_XML(res, type);

     case "body-args":
       res = "link="+QALIAS("linkcolor")+" vlink="+QALIAS("linkcolor")+
             " alink="+QALIAS("fade2")+" bgcolor="+QALIAS("bgcolor")+
             " text="+QALIAS("fgcolor");
       if( stringp(q = QALIAS( "background" )) && strlen( q ) )
         res += " background="+q;
       return ENCODE_RXML_XML(res, type);

     case "top-tableargs":
       if( ALIAS("top-bgcolor") != "none" )
         res = "bgcolor="+QALIAS("top-bgcolor");
       else
         res="";
       if( stringp(q = QALIAS( "top-background" )) && strlen( q ) )
         res += " background="+q;
       return ENCODE_RXML_XML(res, type);

     case "toptabs-tableargs":
       res = "";
       if( ALIAS("toptabs-bgcolor") != "none" )
         res = "bgcolor="+QALIAS("toptabs-bgcolor");
       if( stringp(q = QALIAS( "toptabs-background" )) && strlen( q ) )
         res += " background="+q;
       if( stringp(q = QALIAS( "toptabs-align" )) && strlen( q ) )
         res += " align="+q;
       else
         res += " align=\"left\"";
       return ENCODE_RXML_XML(res, type);

     case "subtabs-tableargs":
       res = "valign=\"bottom\" bgcolor="+QALIAS("subtabs-bgcolor");
       if( stringp(q = QALIAS( "subtabs-background" )) && strlen( q ) )
         res += " background="+q;
       if( stringp(q = QALIAS( "subtabs-align" )) && strlen( q ) )
         res += " align="+q;
       else
         res += " align=\"left\"";
       return ENCODE_RXML_XML(res, type);

     case "left-tableargs":
       res = "valign=\"top\" width=\"150\"";
       if( stringp(q = QALIAS( "left-background" )) && strlen( q ) )
         res += " background="+q;
       return ENCODE_RXML_XML(res, type);

     case "content-tableargs":
       res = " width=\"100%\" valign=\"top\"";
       if( stringp(q = QALIAS( "content-background" )) && strlen( q ) )
         res += " background="+q;
       return ENCODE_RXML_XML(res, type);

    case "set-wiz-id":
      // Used in links with form variables.
      return sprintf("_roxen_wizard_id=%s",
		     Roxen.html_encode_string(Roxen.get_wizard_id_cookie(id) || ""));

      /* standalone, nothing is based on these. */
     case "warncolor":            return ENCODE_RXML_TEXT("darkred", type);
     case "content-toptableargs": return ENCODE_RXML_TEXT("", type);
     case "split-tableargs":      return ENCODE_RXML_TEXT("", type);
     case "split2-tableargs":     return ENCODE_RXML_TEXT("", type);
     case "split2-width":         return ENCODE_RXML_TEXT("", type);
     case "left-image":           return ENCODE_RXML_TEXT("/internal-roxen-unit", type);
     case "selected-indicator":   return ENCODE_RXML_TEXT("/internal-roxen-next", type);
     case "database-small":       return ENCODE_RXML_TEXT("/internal-roxen-database_small", type);
     case "table-small":          return ENCODE_RXML_TEXT("/internal-roxen-table_small", type);
     case "next":                 return ENCODE_RXML_TEXT("/internal-roxen-next", type);
     case "item-indicator":       return ENCODE_RXML_TEXT("/internal-roxen-dot", type);
     case "logo":                 return ENCODE_RXML_TEXT("/internal-roxen-roxen", type);
     case "err-1":                return ENCODE_RXML_TEXT("/internal-roxen-err_1", type);
     case "err-2":                return ENCODE_RXML_TEXT("/internal-roxen-err_2", type);
     case "err-3":                return ENCODE_RXML_TEXT("/internal-roxen-err_3", type);
     case "obox-titlefont":       return ENCODE_RXML_TEXT("helvetica,arial", type);
     case "padlock":              return ENCODE_RXML_TEXT("/internal-roxen-padlock", type);
     case "obox-titlestyle":      return ENCODE_RXML_TEXT("", type);
     case "obox-border":          return ENCODE_RXML_TEXT("black", type);
     case "content-frame":        return ENCODE_RXML_TEXT("", type);
     case "module-list-frame":    return ENCODE_RXML_TEXT("", type);
     case "list-style-boxes":     return ENCODE_RXML_TEXT("", type);


      /* 1-st level */
     case "tab-frame-image":      return ENCODE_RXML_TEXT("/internal-roxen-tabframe", type);
     case "gbutton-frame-image":  return ENCODE_RXML_TEXT("/internal-roxen-gbutton", type);

    /* also: font, bgcolor, fgcolor */

  /* 2nd level */
     case "content-titlebg":      return ENCODE_RXML_TEXT( ALIAS( "bgcolor" ), type);
     case "content-titlefg":      return ENCODE_RXML_TEXT( ALIAS( "fgcolor" ), type);
     case "gbutton-font":         return ENCODE_RXML_TEXT( ALIAS( "font" ), type);
     case "left-buttonframe":     return ENCODE_RXML_TEXT( ALIAS( "gbutton-frame-image" ), type);
     case "gbutton-disabled-frame-image":  return ENCODE_RXML_TEXT( ALIAS("gbutton-frame-image"), type);
     case "obox-bodybg":          return ENCODE_RXML_TEXT( ALIAS( "bgcolor" ), type);
     case "obox-bodyfg":          return ENCODE_RXML_TEXT( ALIAS( "fgcolor" ), type);
     case "obox-titlefg":         return ENCODE_RXML_TEXT( ALIAS( "bgcolor" ), type);
     case "subtabs-bgcolor":      return ENCODE_RXML_TEXT( ALIAS( "bgcolor" ), type);
     case "subtabs-dimtextcolor": return ENCODE_RXML_TEXT( ALIAS( "bgcolor" ), type);
     case "subtabs-frame":        return ENCODE_RXML_TEXT( ALIAS( "tab-frame-image" ), type);
     case "subtabs-seltextcolor": return ENCODE_RXML_TEXT( ALIAS( "fgcolor" ), type);
     case "tabs-font":            return ENCODE_RXML_TEXT( ALIAS( "font" )+" bold", type);
     case "toptabs-frame":        return ENCODE_RXML_TEXT( ALIAS( "tab-frame-image" ), type);
     case "toptabs-dimtextcolor": return ENCODE_RXML_TEXT( ALIAS( "bgcolor" ), type);
     case "toptabs-selcolor":     return ENCODE_RXML_TEXT( ALIAS( "bgcolor" ), type);
     case "toptabs-seltextcolor": return ENCODE_RXML_TEXT( ALIAS( "fgcolor" ), type);

    /* also: fade1 - fade4 */

    /* 3rd level */

     case "content-bg":           return ENCODE_RXML_TEXT( ALIAS( "fade1" ), type);
     case "left-buttonbg":        return ENCODE_RXML_TEXT( ALIAS( "fade1" ), type);
     case "left-selbuttonbg":     return ENCODE_RXML_TEXT( ALIAS( "fade3" ), type);
     case "obox-titlebg":         return ENCODE_RXML_TEXT( ALIAS( "fade2" ), type);
     case "subtabs-dimcolor":     return ENCODE_RXML_TEXT( ALIAS( "fade2" ), type);
     case "subtabs-font":         return ENCODE_RXML_TEXT( ALIAS( "tabs-font" ), type);
     case "subtabs-selcolor":     return ENCODE_RXML_TEXT( ALIAS( "fade1" ), type);
     case "top-bgcolor":          return ENCODE_RXML_TEXT( ALIAS( "fade3" ), type);
     case "top-fgcolor":          return ENCODE_RXML_TEXT( ALIAS( "fade4" ), type);
     case "toptabs-bgcolor":      return ENCODE_RXML_TEXT( ALIAS( "fade3" ), type);
     case "toptabs-dimcolor":     return ENCODE_RXML_TEXT( ALIAS( "fade2" ), type);
     case "toptabs-font":         return ENCODE_RXML_TEXT( ALIAS( "tabs-font" ), type);
    }


    if( var != "bgcolor" )
    {
      c1 = Image.Color.guess( ALIAS("bgcolor") );
      if(!c1)
        c1 = Image.Color.black;
    }


#undef ALIAS
#undef QALIAS

    switch( var )
    {
     case "matrix11": return fade_color( 11, c1, c, scope, type );
     case "matrix12": return fade_color( 12, c1, c, scope, type );
     case "matrix21": return fade_color( 21, c1, c, scope, type );
     case "matrix22": return fade_color( 22, c1, c, scope, type );
     case "fade1":    return fade_color( 1,  c1, c, scope, type );
     case "fade2":    return fade_color( 2,  c1, c, scope, type );

     case "fade3": {
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
       return ENCODE_RXML_TEXT( (string)Image.Color( @map(map(a,max,0),min,255) ), type);
     }

     case "fade4": {
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
       return ENCODE_RXML_TEXT( (string)Image.Color( @map(map(a,max,0),min,255) ), type);
     }
    }
    return config_setting(var) || id->prestate[var];
  }

  string _sprintf (int flag) { return flag == 'O' && "RXML.Scope(usr)"; }
}

RXML.Scope usr_scope=Scope_usr();
RXML.Scope cf_scope=Scope_cf();

void set_entities(RXML.Context c)
{
  c->extend_scope("usr", usr_scope);
  c->extend_scope("cf", cf_scope);
}

int upath;

string get_var_form( string s, object var, object mod, RequestID id,
                     int set )
{
  int view_mode;

  if( mod == roxen )
  {
    if( !CU_AUTH( "Edit Global Variables" ) )
      view_mode = 1;
  } 
  else if( mod->register_module ) 
  {
    if( !CU_AUTH( "Site:"+mod->my_configuration()->name ) )
      view_mode = 1;
  } 
  else if( mod->find_module && mod->Priority ) 
  {
    if( !CU_AUTH( "Site:"+mod->name ) )
      view_mode = 1;
  }

  if( !view_mode && set )
  {
    if( set!=2 )    var->set_from_form( id );
    else
    {
      var->set_warning( 0 );
      var->set( var->default_value() );
    }
  }
  string pre = var->get_warnings();

  if( pre )
    pre = "<div style='color: &usr.warncolor;'><pre>"+
        html_encode_string( pre )+
	"</pre></div>";
  else
    pre = "";
  

  // This test is here insted of in the get_variable_map function for a
  // good reason: The value might have been changed by a submit that also
  // changed the value of another variable in such a way that this variable
  // is no longer visible.
  //
  // Thus, we have to do all that  work above even if the variable will not
  // be visible
  if( !var->check_visibility( id,
                              config_setting2("more_mode"),
                              config_setting2("expert_mode"),
                              config_setting2("devel_mode"),
                              (int)RXML.get_var( "initial", "form" ),
                              get_conf( mod ) == id->conf) )
    return 0;

  string tmp;
  if( mod->check_variable &&
      (tmp = mod->check_variable( s, var->query() ) ))
    pre += 
	"<div style='color: &usr.warncolor;'><pre>"
        + html_encode_string( tmp )
	+ "</pre></div>";

  if( !view_mode && var->render_form )
    return pre + var->render_form( id );
  return pre + var->render_view( id );
}

string diff_url( RequestID id, object mod, Variable.Variable var )
{
  RoxenModule cfs = id->conf->find_module( "config_filesystem#0" );

  // There is one occasion when there is no id->port_obj: When the
  // port for the configuration interface is changed.
  string base =(id->port_obj ? 
		combine_path((id->port_obj->path||"/"),
			     cfs->query_location()[1..])+
		"diff.pike":
		cfs->query_location()+"diff.pike");
  return base+"?variable="+Roxen.http_encode_url(var->path())+
    "&amp;&usr.set-wiz-id;";
}

mapping get_variable_map( string s, object mod, RequestID id, int noset )
{
  if( !mod ) return ([]);
  object var = mod->getvar( s );
  mapping res = ([ "sname":s]);

  int defv = !!id->variables[var->path()+"do_default.x"];
  if( defv )
    id->variables["save.x"]="1";
  
  if( res->form =
      get_var_form( s, var, mod, id, !noset ?
		    1+defv:0))
  {
    // FIXME: Do lazy evaluation of all this. It's rather likely that
    // the variable will be filtered away in the calling function.
    //
    // Perhaps add caching as well (section -> visible variables)
    // That would invite problems, though.
    string old_locale;
    if ((old_locale = roxen.get_locale()) != "eng") {
      roxen.set_locale("eng");
      res->rname = (string)var->name();
      roxen.set_locale(old_locale);
    } else {
      res->rname = (string)var->name();
    }
    res["no-default"] = var->get_flags() & VAR_NO_DEFAULT;
    res->path = var->path();
    res["diff-txt"] = var->diff( 0 );
    res->diff="";
    if( !res["diff-txt"] && var->diff( 1 ) )
      res->diff = 
	"<a target=rxdiff_"+var->path()+
	" href='"+diff_url( id, mod, var )+"'><link-gbutton>"+
	LOCALE(502,"Diff")+"</link-gbutton></a>";
    if(!res["diff-txt"])
      res["diff-txt"]="";
    res->id = var->_id;
    res->changed = !var->is_defaulted();
    res->cid = res->changed*-10000000+res->id;
    string n = (string) var->name();
    res->name = has_value(n, ":") ? ((n / ":")[1..] * ":") : n;
    res->cname = (!res->changed)+res->name;
    res->doc = config_setting2("docs")?(string)var->doc():"";
    res->value = var->query();
    res->type = var->type;
  }
  return res;
}

object get_conf( object mod )
{
  if( mod->my_configuration )
    return mod->my_configuration();
  return mod;
}

mapping low_variable_section(string|object localized_name,
			     object mod, RequestID id)
{
  string section = RXML.get_var( "section", "form" );
  string s = (string)localized_name;
  if( sscanf( s, "%s:%*s", s ) ) {
    string s2 = s;
    string old_loc;
    if (objectp(localized_name) &&
	(old_loc = roxen.get_locale()) != "eng") {
      roxen.set_locale("eng");	// Standard.
      s2 = (string)localized_name;
      roxen.set_locale(old_loc);
      sscanf(s2, "%s:", s2);
    }
    return ([
      "section":s2,	// Must not be localized.
      "sectionname":s,	// Localized.
      "selected":(section==s2?"selected":"")
    ]);
  }
  else
    return ([
      "section":"Settings",
      "sectionname":LOCALE(256,"Settings"),
      "selected":
      ((section=="Settings" || !section)?"selected":""),
    ]);
  return 0;
}

mapping get_variable_section( string s, object mod, RequestID id )
{
  Variable.Variable var = mod->getvar( s );
  LocaleString localized_name = var->name();
  return low_variable_section(localized_name, mod, id);
}

array get_variable_maps( object mod, 
                         mapping m, 
                         RequestID id, 
                         int fnset )
{
  if( !mod )
    return ({});
  while( id->misc->orig )
    id = id->misc->orig;
  array variables = map( indices(mod->query()),
                         get_variable_map,
                         mod,
                         id,
                         fnset );


  variables = filter( variables,
                      lambda( mapping q ) {
                        return q->form && strlen(q->sname);
                      } );


  // This is true when we are looking at configuration interface
  // modules.  All variables starting with '_' are related to security
  // and priority.  Letting the user mess around with these settings
  // in the configuration interface is highly risky, since it's
  // trivial to lock oneself out from the interface.
  if( id->conf == get_conf(mod) )
    variables = filter( variables,
                        lambda( mapping q ) { return q->sname[0] != '_'; } );

  if (string fs = css_font_size[config_setting("form-font-size")])
    map( variables, lambda( mapping q ) {
		      if( search( q->form, "<" ) != -1 )
			q->form=("<div style='font-size: "+fs+"'>"+
				 q->form+"</div>");
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
                         return !search( q->rname, (m->section+":") );
                       } );
  }

  switch(  config_setting("sortorder") )
  {
    default:                    sort( variables->name, variables );  break;
    case "as defined":          sort( variables->id,   variables );  break;
    case "changed/as defined":  sort( variables->cid,  variables );  break;
    case "changed/alphabetical":sort( variables->cname,variables );  break;
  }

  if( !fnset )
    if( id->variables["save.x"] )
    {
      // Can't delay this. I'd need to set it blocking on a
      // configuration variable basis in that case. /mast
      //remove_call_out( mod->save );
      //call_out( mod->save, 5 );
      if( mod->save_me )
        mod->save_me();
      else
        mod->save();
    }
  return variables;
}

array get_variable_sections( object mod, mapping m, RequestID id )
{
  mapping w = ([]);
  array vm = indices(mod->query());
  // Also filter the sections when looking at the settings for a module 
  // in the configuration interface.
  if( get_conf(mod) == id->conf )
    vm = filter( vm, lambda( mixed q ) { 
                       return stringp(q)&&strlen(q)&&(q[0]!='_');
                     } );

  array variables = map( vm, get_variable_map, mod, id, 1 );
  variables = filter( variables,
                      lambda( mapping q ) {
                        return q->form && strlen(q->sname);
                      } );

  variables = map(variables->sname,get_variable_section,mod,id);
  variables = Array.filter( variables-({0}),
                       lambda( mapping q ) {
                         return !w[ q->section ]++;
                       });
  sort( variables->section, variables );
  return variables;
}

object(Configuration) find_config_or_error(string config)
{
  if(!config)
    error("No configuration specified!\n");
    
  object(Configuration) conf = roxen->find_configuration(config);
  if (!conf)
    error("Unknown configuration %O\n", config);
  return conf;
}

mapping get_port_map( object p )
{
  mapping ret = ([
    "port":p->get_key(),
    "info":"",
    "warning":"",
    "error":"",
  ]);

  if (!p->bound) {
    ret->warning =
      LOCALE(300,"This port was requested, but binding it failed.");
  }

  if (!p->ip||!has_value(p->ip, ":")) {
    // IPv4
    ret->name = p->name+"://"+(p->ip||"*")+":"+p->port+"/";
  } else {
    // IPv6
    /* RFC 3986 3.2.2. Host
     *
     * host       = IP-literal / IPv4address / reg-name
     * IP-literal = "[" ( IPv6address / IPvFuture  ) "]"
     * IPvFuture  = "v" 1*HEXDIG "." 1*( unreserved / sub-delims / ":" )
     *
     * IPv6address is as in RFC 3513.
     */
    ret->name = p->name+"://["+p->ip+"]:"+p->port+"/";
  }

  array(int) keypair_ids = p->query("ssl_keys", 1);
  if (arrayp(keypair_ids)) {
    // SSL/TLS port.
    int got_valid;
    foreach(keypair_ids, int keypair_id) {
      array(Crypto.Sign.State|array(string)) keypair =
	CertDB.get_keypair(keypair_id);
      if (!keypair) continue;
      [Crypto.Sign.State private_key, array(string) certs] = keypair;

      Standards.X509.TBSCertificate tbs =
	Standards.X509.decode_certificate(certs[0]);

      array(string) res = ({});

      if (!tbs) {
	ret->warning = LOCALE(1130, "Invalid certificate");
	continue;
      }

      if (tbs->issuer->get_der() == tbs->subject->get_der()) {
	ret->info = LOCALE(1152, "Self-signed certificate");
      }

      if (tbs->not_after < time(1)) {
	// Already expired.
	ret->error = LOCALE(1153, "Expired certificate");
      } else if (tbs->not_after < time(1) + (3600 * 24 * 30)) {
	// Expires within 30 days.
	ret->warning = LOCALE(1154, "Certificate expires soon");
      }
    }
  }

  return ret;
}

mapping get_url_map( string u, mapping ub )
{
  if( ub[u] && ub[u]->conf )
    return ([
      "url": roxen.normalize_url (u),
      "conf":replace(ub[u]->conf->name, " ", "-" ),
      "confname":ub[u]->conf->query_name(),
    ]);
}

class TagCFBoxes
{
  inherit RXML.Tag;
  constant name = "cf-boxes";

  class Frame
  {
    inherit RXML.Frame;
    protected mapping(string:object) boxes = ([]);

    protected object compile_box( string box )
    {
      if( boxes[box] )
      {
        master()->refresh( object_program( boxes[box] ), 1 );
        destruct( boxes[box] );
      }

      string id;
      if( sscanf( box, "%s:%s", box, id ) )
	boxes[box] = Roxen.parse_box_xml( "config_interface/boxes/"
					  +box+".xml", id );
      else if(!catch(boxes[box]=(object)("config_interface/boxes/"+box+".pike")))
	roxen.dump("config_interface/boxes/"+box+".pike");
      return boxes[box];
    }

    protected object get_box( string box, RequestID id )
    {
      object bx = boxes[ box ];
      if( !bx  || (!id->pragma["no-cache"] &&
		   master()->refresh_inherit( object_program( bx ) ) > 0 ) )
        return compile_box( box );
      return bx;
    }

    array sort_boxes( array what, RequestID id )
    {
      mapping pos = ([]);
      array res = ({});
      foreach( what, string q )
      {
        object box = get_box( q, id );
        if( box )
          pos[ box->box_position ] += ({ q });
      }
      foreach( sort(indices(pos)), int p )
        res += pos[p];
      return res;
    }

    array do_return( RequestID id )
    {
      string left="";
      string right="";
      foreach( sort_boxes(config_setting( "left_boxes" ),id), string f )
	
        left+=get_box( f,id )->parse( id )+"<br />";
      foreach( sort_boxes(config_setting( "right_boxes" ),id), string f )
        right+=get_box( f,id )->parse( id )+"<br />";
      result="<table width='100%'><tr valign=top><td width='100%'>"+left+"</td><td>"+
                         right+"</td></tr></table>";
    }
  }
}

class TagConfigSettingsplugin
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "config-settings";
  
  array get_dataset( mapping m, RequestID id )
  {
    return get_variable_maps( id->misc->config_settings, m, id, !!m->noset);
  }
}

class TagConfigModulesplugin
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "config-modules";

  array get_dataset(mapping m, RequestID id)
  {
    object conf = find_config_or_error( m->configuration );
    
    array variables = ({ });
    foreach( values(conf->otomod), string q )
    {
      ModuleInfo mi = roxen.find_module((q/"#")[0]);
      RoxenModule m = conf->find_module( q );
      array variables =
                ({
                  ([
                    "sname":replace(q, "#", "!"),
                    "name":(m->query_name ? m->query_name() :
			    (mi->get_name()+
			     ((int)reverse(q)?" # "+(q/"#")[1]:""))),
                    "doc":mi->get_description(),
                  ]),
                });
    }
    sort( variables->name, variables );
    return variables;
  }
}


class TagConfigVariablesplugin
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "config-variables";
  
  array get_dataset(mapping m, RequestID id)
  {
    return get_variable_maps( find_config_or_error( m->configuration ), 
                              m, id, !!m->noset);
  }
}


class TagConfigPortsplugin
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "ports";

  array get_dataset(mapping m, RequestID id)
  {
    if (m->port) {
      Protocol p = roxen->find_port(m->port);
      if (p) return ({ get_port_map(p) });
      return ({});
    }
    array pos = roxen->all_ports();
    sort( pos->get_key(), pos );
    pos = map( pos, get_port_map );
    foreach( pos, mapping v )
      if( v->port == RXML.get_var( "port", "form" ) )
        v->selected = "selected";
    return pos;
  }
}

class TagPortVariablesplugin
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "port-variables";

  array get_dataset(mapping m, RequestID id)
  {
    return get_variable_maps( roxen->find_port( m->port ), ([]),
                              id, !!m->noset);
  }
}

class TagPortURLsplugin
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "port-urls";

  array get_dataset(mapping m, RequestID id)
  {
    mapping u = roxen->find_port( m->port )->urls;
    array(mapping(string:string)) res =
      map(sort(indices(u)),get_url_map,u)-({0});
    if (m->distinct) {
      mapping(string:int) found = ([]);
      res = filter (res, lambda (mapping(string:string) ent) {
			   int first = !found[ent[m->distinct]];
			   found[ent[m->distinct]] = 1;
			   return first;
			 });
    }
    if (string excl_conf = m["exclude-conf"])
      res = filter (res, lambda (mapping(string:string) ent) {
			   return ent->conf != excl_conf;
			 });
    return res;
  }
}

class TagConfigVariablesSectionsplugin
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "config-variables-sections";
  
  array get_dataset(mapping m, RequestID id)
  {
    array v = get_variable_sections( find_config_or_error( m->configuration ),
                                     m, id );

    string section = RXML.get_var( "section", "form" );
    if( m["add-module-priorities"] && (id->conf != m->configuration) )
      v = ({ 
        ([
          "section":"ModulePriorities",
          "sectionname":LOCALE(551,"Module Priorities"),
          "selected":(section=="ModulePriorities")?"selected":"",
        ]),
      }) + v;
    if( m["add-status"] )
      v = ({ 
        ([
          "section":"Status",
          "sectionname":LOCALE(228,"Status"),
          "selected":(!section||(section=="Status")?"selected":""),
        ]),
      }) + v;

    if( section != "Settings" )
      foreach( v, mapping q )
	if( (q->section == "Settings") )
	  m_delete( q, "selected" );

    v[0]->last = "last";
    v[-1]->first = "first";
    return v;
  }
}

class TagModuleVariablesplugin
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "module-variables";

  array get_dataset(mapping m, RequestID id)
  {
    object mod = find_config_or_error( m->configuration )
           ->find_module( replace( m->module, "!", "#" ) );
    if( !mod )
      RXML.run_error("Unknown module "+ m->module +"\n");
    return get_variable_maps( mod, m, id, !!m->noset);
  }
}

class TagModuleVariablesSectionsplugin
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "module-variables-sections";
  
  array get_dataset(mapping m, RequestID id)
  {
    array variables;
    Configuration conf = find_config_or_error( m->configuration );
    RoxenModule mod = conf->find_module( replace( m->module, "!", "#" ) );
    string section = RXML.get_var( "section", "form" );
    if( !mod )
      RXML.run_error("Unknown module: "+m->module+"\n");

    variables = get_variable_sections( mod, m, id ) +  ({ ([
       "section":"Status",
       "sectionname":LOCALE(228,"Status"),
       "selected":((section=="Status" )?"selected":""),
     ]) });

    if( !section )
      id->variables->info_section_is_it = "1";
    foreach( variables, mapping m )
      if(m->section == "Settings" )
	m_delete( id->variables, "info_section_is_it" );
    
    if( id->variables->info_section_is_it )
      variables[-1]->selected = "selected";

    if( mod->module_full_doc || (mod->module_type & MODULE_TAG ) )
      variables = ({ ([
       "section":"Docs",
       "sectionname":LOCALE(383,"Documentation"),
       "selected":((section=="Docs")?"selected":""),
     ]) }) + variables;
    
     int hassel;

     
     foreach( reverse(variables), mapping q )
     {
       if( hassel )
         q->selected = "";
       else
         hassel = strlen(q->selected);
     }
     variables = reverse(variables);
     variables[0]->first = " first ";
     variables[-1]->last = " last=30 ";
     if( !hassel )
     {
       // No selected tab.
       variables[0]->selected="selected";
       RXML.set_var( "section", variables[0]->section, "form" );
     }
     return variables;
  }
}

// usage: <cf-headline/>
class TagCFHeadline
{
  inherit RXML.Tag;
  constant name = "cf-headline";

  class Frame
  {
    inherit RXML.Frame;
    array do_return( RequestID id )
    {
      result_type = RXML.t_text;
      return ({ roxen->query("config_header_string") });
    }
  }
}

class TagGlobalVariablesSectionsplugin
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "global-variables-sections";
  
  array get_dataset(mapping m, RequestID id)
  {
    array v = get_variable_sections( roxen, m, id );
    v[0]->last = "last";
    v[-1]->first = "first";
    return v;
  }
}

class TagGlobalVariablesplugin
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "global-variables";
  array get_dataset(mapping m, RequestID id)
  {
    return get_variable_maps( roxen, m, id, !!m->noset);
  }
}

class TagConfigurationsplugin
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "configurations";
  array get_dataset(mapping m, RequestID id)
  {
    array confs = roxen->configurations;
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
    if(m->self && lower_case(m->self) == "no")
      confs -= ({ id->conf });
#endif
    array variables = map( confs,
                      lambda(object o ) {
                        if( !o->error_log[0] )
                          return ([
                            "name":o->query_name(),
                            "sname":replace(lower_case(o->name),
                                            ({" ","/","%"}),
                                            ({"-","-","-"}) ),
                          ]);
                      } )-({0});

     sort(variables->name, variables);
     return variables;
  }
}

class TagThemePath
{
  inherit RXML.Tag;
  constant name = "theme-path";
  constant flags = 0;
  class Frame 
  {
    inherit RXML.Frame;
    int do_iterate;
    void do_enter( RequestID id )
    {
      while( id->misc->orig ) 
        id = id->misc->orig;
      if( glob( "*"+args->match, id->not_query ) )
        do_iterate = 1;
      else
	do_iterate = -1;
      return 0;
    }
  }
}

string simpletag_theme_set( string tag, mapping m, string s, RequestID id  )
{
  if( strlen( s ) )
    RXML.parse_error("&lt;theme-set/&gt; does not support contents\n" );
  if( !id->misc->cf_theme )
    id->misc->cf_theme = ([]);
  if( m->themefile )
    m->to = "/themes/"+config_setting2( "theme" )+"/"+m->to;
  if( m->integer )
    m->to = (int)m->to;
  id->misc->cf_theme[ m->what ] = m->to;
  return "";
}

string simpletag_rli( string t, mapping m, string c, RequestID id )
{
  return "<tr>"
         "<td valign='top'><img src='&usr.count-"+(++id->misc->_rul_cnt&3)+
         ";' /></td><td valign='top'>"+c+"</td></tr>\n";
}

string simpletag_rul( string t, mapping m, string c, RequestID id )
{
  id->misc->_rul_cnt = -1;
  return "<table>"+c+"</table>";
}

string simpletag_roxen_wizard_id_variable(string t, mapping m, string c,
					  RequestID id)
{
  string wizard_id = Roxen.get_wizard_id_cookie(id);
  if (!sizeof(wizard_id || "")) {
    wizard_id = Roxen.set_wizard_id_cookie(id);
  }
  if (wizard_id != id->variables["_roxen_wizard_id"]) {
    foreach(id->real_variables; string var;) {
      m_delete(id->real_variables, var);
    }
    foreach(id->variables; string var;) {
      m_delete(id->real_variables, var);
    }
    id->variables["_roxen_wizard_id"] = wizard_id;
  }
  return sprintf("<input type='hidden' name='_roxen_wizard_id' "
		 "value='%s' />",
		 Roxen.html_encode_string(wizard_id));
}

class TagCfPerm
{
  inherit RXML.Tag;
  constant name = "cf-perm";
  constant flags = 0;
  class Frame
  {
    inherit RXML.Frame;
    int do_iterate;
    void do_enter( RequestID id )
    {
      if( id->misc->config_user && ( CU_AUTH( args->perm )==!args->not ) )
        do_iterate = 1;
      else
	do_iterate = -1;
      return 0;
    }
  }
}


string simpletag_cf_obox( string t, mapping m, string c, RequestID id )
{
  return
#"<table cellpadding='1' cellspacing='0' border='0'
         width='"+m->width+"' align='center' bgcolor='"+
    config_setting2("obox-border")+#"'>
 <tr><td>
  <table cellpadding='"+(m->padding?m->padding:"2")+#"'
         cellspacing='0' border='0'
         width='"+m->iwidth+#"' align='center'>
  <tr bgcolor='"+config_setting2("obox-titlebg")+#"'>
    <th valign='top'>
      <font color='"+config_setting2( "obox-titlefg" )+#"' 
            face='"+config_setting2("obox-titlefont")+#"'
            style='"+config_setting2("obox-titlestyle")+
    "'><b>"+m->title+#"</b></font>
    </th>
  </tr>

  <tr><td bgcolor='"+config_setting2("obox-bodybg")+"'><font color='"+
    config_setting2("obox-bodyfg")+"'>"+c+#"</font></td></tr>
  </table>
  </td></tr></table>";
}
string simpletag_box_frame( string t, mapping m, string c, RequestID id )
{
  if (!m["box-frame"]) return c;
  string bodybg = m->bodybg || config_setting2("obox-bodybg");
  return
#"<table cellpadding='1' cellspacing='0' border='0'
         width='"+m->width+"' align='left' bgcolor='"+
    config_setting2("obox-border")+#"'>
 <tr><td>
  <table cellpadding='"+(m->padding?m->padding:"2")+#"'
         cellspacing='0' border='0'
         width='"+m->iwidth+#"' align='center'>

  <tr><td bgcolor='"+bodybg+"'><font color='"+
    config_setting2("obox-bodyfg")+"'>"+c+#"</font></td></tr>
  </table>
  </td></tr></table>";
}


string simpletag_cf_render_variable( string t, mapping m,
				     string c, RequestID id )
{
  string extra = "";


#define   _(X) RXML.get_var( X, 0 )
#define usr(X) RXML.get_var( X, "usr" )
#define var(X) RXML.get_var( X, "var" )

  int chng;
  string dfs, dfe, def="";
  if (string fs = css_font_size[config_setting ("docs-font-size")]) {
    dfs = "<div style='font-size: "+fs+"'>";
    dfe = "</div>";
  }
  else
    dfs = dfe = "";

  if( chng = ((int)_("changed") == 1) )
    if( !(int)_("no-default") )
      def = "<br /><submit-gbutton2 name='"+_("path")+"do_default' "
	"onclick=\"return confirm('" +
	LOCALE(1041, "Are you sure you want to restore the default value?") +
	"');\" > "+
	LOCALE(475,"Restore default value")+" "+_("diff-txt")+
	" </submit-gbutton2> "+_("diff")+"\n";
  
  switch( usr( "changemark" ) )
  {
    case "not":
      return
	"<tr><td valign='top' width='30%'><b>"+
	Roxen.html_encode_string(_("name"))+"</b></td>\n"
	"<td valign='top'>"+_("form")+def+"</td></tr>\n"
	"<tr><td colspan='2'>"+dfs+_("doc")+dfe+"</td></tr>\n";

    default:
      if( chng )
	extra = "bgcolor='"+usr("fade2")+"'";
      return "<tr>\n"
	"<td valign='top' width='30%'><b>"+
	Roxen.html_encode_string(_("name"))+"</b></td>\n"
	"<td valign='top' "+extra+">"+_("form")+def+"</td>\n"
	"</tr>\n"
	"<tr>\n"
	"<td colspan='2'>"+dfs+_("doc")+dfe+"</td>\n"
	"</tr>\n";
      break;
      
    case "header":
      if( chng != (int)var("oldchanged") )
      {
	RXML.set_var( "oldchanged", chng, "var" );
	if( chng )
	  extra = 
	    "<tr bgcolor='"+usr("content-titlebg")+"'>\n"
	    "<td colspan='2' width='100%'>\n"
	    "<div style='color: "+usr("content-titlefg")+"'>"+
	    LOCALE(358,"Changed")+"</div>\n"
	    "</td>\n"
            "</tr>\n";
	else
	  extra = 
	    "<tr bgcolor='"+usr("content-titlebg")+"'>\n"
	    "<td colspan='2' width='100%'>\n"
	    "<div style='color: "+usr("content-titlefg")+"'>"+
	    LOCALE(359,"Unchanged")+"</div>\n"
	    "</td>\n"
            "</tr>\n";

      }
      return
	extra+
	"<tr><td valign='top' width='30%'><b>"+
	Roxen.html_encode_string(_("name"))+"</b></td>"
	"<td valign='top'>"+_("form")+"<br />"+def+"</td></tr>"
	"<tr><td colspan='2'>"+dfs+_("doc")+dfe+"</td></tr>\n";
  }
}


string simpletag_box( string t, mapping m, string c, RequestID id )
{
  if( m->type == "small" )
  {
    m->width=200;
    m->iwidth=198;
    return simpletag_cf_obox( t, m, c, id );
  }
  m->width=400;
  m->iwidth=398;
  return simpletag_cf_obox( t, m, c, id );
}

class TagCfUserWants
{
  inherit RXML.Tag;
  constant name = "cf-userwants";
  constant flags = 0;
  class Frame
  {
    inherit RXML.Frame;
    int do_iterate;
    void do_enter( RequestID id )
    {
      if( config_setting2( args->option )==!args->not )
        do_iterate = 1;
      else
	do_iterate = -1;
      return 0;
    }
  }
}


// License tags.
string license_dir = getenv("ROXEN_LICENSEDIR") || "../license";

class TagGetPostFilename
{
  inherit RXML.Tag;
  constant name = "get-post-filename";
  mapping(string:RXML.Type) req_arg_types =
    ([ "filename":RXML.t_text(RXML.PXml),
       "js-filename":RXML.t_text(RXML.PXml) ]);
  class Frame
  {
    inherit RXML.Frame;
    array do_return(RequestID id)
    {
      return
	({ (replace(((args["js-filename"] && sizeof(args["js-filename"])) ?
		     args["js-filename"] : args["filename"]),
		    "\\", "/") / "/")[-1] });
    }
  }
}

class TagUploadLicense
{
  inherit RXML.Tag;
  constant name = "upload-license";
  mapping(string:RXML.Type) req_arg_types =
    ([ "filename":RXML.t_text(RXML.PXml),
       "from":RXML.t_text(RXML.PXml) ]);
  class Frame
  {
    inherit RXML.Frame;
    License.Key key;
    
    array do_return(RequestID id)
    {
      string filename = Stdio.append_path(license_dir, args["filename"]);
      string tmpname = filename+"~";
      string s = RXML.user_get_var(args["from"]);
      if(!s || sizeof(s) < 10)
	RXML.run_error("Specified licens file is not valid %O.\n", filename);
      Privs privs =
	Privs(sprintf("Creating temporary licence file %O.", tmpname));
      if (mixed err = catch {
	  int bytes = Stdio.write_file(tmpname, s);
	  privs = UNDEFINED;
	  if(bytes != sizeof(s))
	    RXML.run_error("Could not write file %O.\n", tmpname);
	}) {
	privs = UNDEFINED;
	throw(err);
      }
      privs = UNDEFINED;

      License.Key(license_dir, args["filename"]+"~");
      
      privs = Privs(sprintf("Renaming to permanent licence file %O.",
			    filename));
      mv(tmpname, filename);
      privs = UNDEFINED;
    }
  }
}

class TagIfLicense {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "license";
  int eval(string u, RequestID id, mapping args)
  {
    return Stdio.is_file(Stdio.append_path(license_dir, u));
  }
}

mapping get_license_vars(License.Key key)
{
  return ([ "company_name":    key->company_name(),
	    "expires":         key->expires(),
	    "hostname":        key->hostname(),
	    "type":            key->type(),
	    "sites":           key->sites(),
	    "number":          key->number(),
	    "license-version": key->license_version(),
	    "comment":         key->comment()||"",
	    "modules":         key->get_modules(),
	    "name":            key->name(),
	    "configurations":
	    String.implode_nicely(License.
				  get_configurations_for_license(key)->name),
	    
	    "filename":     key->filename(),
	    "creator":      key->creator(),
	    "created":      key->created(),
	    "key":          key ]);
}

class TagLicense
{
  inherit RXML.Tag;
  constant name = "license";
  
  class Frame
  {
    inherit RXML.Frame;
    string scope_name;
    mapping vars;
    License.Key key;
    
    array do_enter(RequestID id)
    {
      if(!args->name || args->name == "")
	RXML.parse_error("No license name specified.\n");
      
      scope_name = args->scope||"license";
      key = License.get_license(license_dir, args->name);
      if(!key)
      {
	RXML.run_error("Can not find license %O.\n", args->name);
	return ({});
      }
      vars = get_license_vars(key);
    }
  }
}

class TagEmitLicenseModules {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "license-modules";
  array get_dataset(mapping args, RequestID id)
  {
    RXML.Context c = RXML.get_context();
    mapping modules = c->get_var("modules");
    if(!modules)
    {
      RXML.parse_error("No key defined. emit#license-modules can only be used "
		       "within <license>.\n");
      return ({});
    }
    array res = ({});
    foreach(sort(indices(modules)), string name)
    {
      res += ({ ([ "name":name,
		   "enabled":(modules[name]?"yes":"no"),
		   "features":modules[name] ]) });
    }
    return res;
  }
}

class TagEmitLicenseModuleFeature {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "license-module-features";
  array get_dataset(mapping args, RequestID id)
  {
    RXML.Context c = RXML.get_context();
    if(!c->get_var("enabled"))
    {
      RXML.parse_error("No key defined. emit#license-module-features can only be used "
		       "within emit#license-modules.\n");
      return ({});
    }
    mapping features = c->get_var("features");
    if(!features)
      return ({});

    array res = ({});
    foreach(sort(indices(features)), string name)
    {
      res += ({ ([ "name":name,
		   "value":features[name] ]) });
    }
    return res;
  }
}

class TagEmitLicenses {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "licenses";
  array get_dataset(mapping args, RequestID id)
  {
    array(License.Key|mapping) licenses = License.get_licenses(license_dir);
    array(mapping) vars = ({});
    foreach(licenses, License.Key key)
    {
      if(mappingp(key))
	vars += ({ key + ([ "malformed":"yes" ]) });
      if(objectp(key))
	vars += ({ get_license_vars(key) });
    }
    return vars;
  }
}

// TagEmitLicenseWarnings is moved to server/modules/tags/rxmltags.pike
