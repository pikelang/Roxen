inherit "config/builders";
string cvs_version = "$Id: mainconfig.pike,v 1.15 1996/12/03 01:17:46 per Exp $";
inherit "roxenlib";
inherit "config/draw_things";

#include <confignode.h>
#include <module.h>

#define dR "00"
#define dG "20"
#define dB "50"

#define bdR "00"
#define bdG "30"
#define bdB "70"


#define BODY "<body bgcolor=#002050 text=#ffffff link=#ffffaa vlink=#ffffaa alink=#f0e0f0>"

#define TABLEP(x, y) (id->supports->tables ? x : y)

int bar=time(1);

program Node = class {
  inherit "struct/node";

  mixed original;
  int changed;

  int bar=previous_object()->bar;
  function saver = lambda(object o) { if(o->changed) o->change(-o->changed); };
  
  string|array error;
  
  void change(int i)
  {
    changed += i;
    if(up) up->change(i);
  }

  private string show_me(string s)
  {
    string name=path(1);
    if(folded)
      return ("<a name=\""+name+"\">"
	      "<a href=\"/(unfold)/" + name + "?"+(bar++)+
	      "\"><img border=0 align=baseline src=/auto/unfold"
	      +(changed?"2":"")+" alt="+(changed?"*-":"--")+">"
	      "</a> "+s);
    else
      return ("<a name=\""+name+"\">"
	      "<a href=\"/(fold)/" + name + "?"+(bar++)+
	      "\"><img border=0 src=/auto/fold"+(changed?"2":"")
	      +"  alt="+(changed?"**":"\"\\/\"")+">"
	      "</a> "+s);
  }

  string describe(int i)
  {
    string res="";
    object node,prevnode;
    mixed tmp;

    if(describer)
      tmp = describer(this_object());
#ifdef NODE_DEBUG
    else
      perror("No describer in node "+path(1)+"\n");
#endif
    if(arrayp(tmp) && sizeof(tmp))
      res += tmp[0] + "<dt>" + (!i?show_me(tmp[1]):tmp[1]) + "\n\n";
    else if(stringp(tmp) && strlen(tmp))
      res += "<dt>" + (i?tmp:show_me(tmp)) + "\n\n";
    else if(!tmp)
      return "";

    if(!i && strlen(res))
      res += "<dd>";
    else if(strlen(res))
      res += "<p>";

    if(!folded)
    {
      int sdl = 0; /* Add slash-dl to the end.. */
      
      if(!i && strlen(res))
      {
	sdl = 1;
	res += "<dl>\n\n";
      }
      node = down;
      while(node)
      {
	if(!objectp(node))	// ERROR! Destructed node in tree!
	{
	  if(objectp(prevnode))
	    prevnode->next=0;
	  node=0;
	  break;
	}
	prevnode = node;
	node = node->next;
	res += prevnode->describe();
      }
      if(sdl)
	res += "</dl>\n\n";
    }
    return res;
  }
  
  
  object config()
  {
    object node;
    node=this_object();
    while(node)
      if(node->type == NODE_CONFIGURATION)
	return node->data;
      else
	node=node->up;
  }
  
  void save()
  {
    object node;
    node=down;
    
    // depth-first save.
    while(node)
    {
      if(node->changed) node->save();
      node=node->next; 
    }
    if(saver) saver(this_object());
  }
};

object root=Node();
int expert_mode;


void create()
{
  build_root(root);
  init_ip_list();
  call_out(init_ip_list, 0);
}

#define PUSH(X) do{res+=({(X)});}while(0)
#define BUTTON(ACTION,TEXT,ALIGN) PUSH("<a href=\"/(ACTION)"+(o?o->path(1):"/")+"?"+(bar++)+"\"><img border=0 hspacing=0 vspacing=0 src=/auto/button/"+replace(TEXT," ","%20")+" alt=\""+TEXT+"\""+(("ALIGN"-" ")=="left"?"":" align="+("ALIGN"-" "))+"></a>")

inline string shutdown_restart(string save, int compact,void|object o)
{
  return /*"<br clear=all>"*/"";
}

string default_head(string h, string|void save)
{
  return ("<title>"+h+"</title>"+ BODY);
}

object find_node(string l)
{ 
  array tmp = l/"/"-({""});
  object o;
  if(!sizeof(tmp)) return root;
  for(o=root; sizeof(tmp) && (o=o->descend(tmp[0],1)); tmp=tmp[1..1000]);
  if(!o) return 0;
  roxen->current_configuration = o->config();
  return o;
}

mapping file_image(string img)
{
  object o;
  o=open("roxen-images/"+img, "r");
  if (!o)  return 0;
  return ([ "file":o, "type":"image/" + ((img[-1]=='f')?"gif":"jpeg"), ]);
}

#define CONFIG_URL roxen->config_url()

mapping save_it(object id, object o)
{
  id->referer = ({ CONFIG_URL + o->path(1) });
  root->save();
  if(roxen->do_fork_it())
  {
    roxen->update_supports_from_roxen_com();
    roxen->initiate_configuration_port( 0 );
  }
  else
    throw(-1);
}

mapping stores( string s )
{
  return 
    ([
      "data":replace(s, "$docurl", roxen->docurl),
      "type":"text/html",
      "extra_heads":
      ([
	"Title":"Roxen Challenger maintenance",
	"Expires":http_date(time(1)+2),
	"Pragma":"no-cache",
	"Last-Modified":http_date(time(1)),
	])
      ]);
}

object find_module(string name)
{
  mapping mod;
  object o;
  string s;
  int i;
  name = lower_case(name);
  if(!sscanf(name, "%s#%d", name, i))
  {
#ifdef MODULE_DEBUG
#if defined(DEBUG) && (DEBUG > 1000)
    perror("Modulename not in short form: "+name+"\n");
#endif
#endif
    foreach(values(roxen->current_configuration->modules), mod)
    {
      if(mod->copies)
      {
	foreach(values(mod->copies), o)
	  if(lower_case(s=name_of_module(o)) == name)
	    return o;
      } else 
	if(mod->enabled && (lower_case(s=name_of_module(mod->enabled))==name))
	  return mod->enabled; 
    }
  } else {
    mapping modules;
#ifdef MODULE_DEBUG
#if defined(DEBUG) && (DEBUG > 1000)
    perror("Modulename in short form: "+name+"#"+i+"\n");
#endif
#endif
    modules = roxen->current_configuration->modules;
    if(modules[name])
    {
      if(modules[name]->copies)
	return modules[name]->copies[i];
      else 
	if(modules[name]->enabled)
	  return modules[name]->enabled;
    }
  }
  return 0;
}

mixed decode_form_result(string var, int type, object node, mapping allvars)
{
  switch(type)
  {
  case TYPE_MODULE_LIST:
    return map_array(var/"\000", find_module);

  case TYPE_MODULE:
    return find_module(var);

  case TYPE_PORTS:  
   /*
     Encoded like this:

     new_port    --> Add a new port
     ok[_<ID>]   --> Save the value for all or one port
     delete_<ID> --> Delete a port

     ---- { A port is defined by:
     port_<ID> == INT
     protocol_<ID> == STRING
     ip_number_<ID> == STRING
     arguments_<ID> == STRING
     } ---- 
    */
   if(allvars->new_port)
     return node->data[VAR_VALUE] + ({ ({ 80, "http", "ANY", "" }) });

   array op = copy_value(node->data[VAR_VALUE]);
   int i;
   for(i = 0; i<sizeof(op); i++)
   {
     if(!allvars["delete_"+i])
     {
       if(allvars["other_"+i] && (allvars["other_"+i] != op[i][2]))
       {
	 allvars["ip_number_"+i] = allvars["other_"+i];
	 ip_number_list += ({ allvars["other_"+i] });
       }
       op[i][0] = (int)allvars["port_"+i]||op[i][0];
       op[i][1] = allvars["protocol_"+i]||op[i][1];
       op[i][2] = allvars["ip_number_"+i]||op[i][2];
       op[i][3] = allvars["arguments_"+i]||op[i][3];
     } else  // Delete this port.
       op[i]=0;
   }
   return op  - ({ 0 });

   case TYPE_DIR_LIST:
    array foo;
    foo=map_array((var-" ")/",", lambda(string var, object node) {
      if (!strlen( var ) || file_size( var ) != -2)
      {
	if(node->error)	
	  node->error += ", " +var + " is not a directory";
	else
	  node->error = var + " is not a directory";
	return 0;
      }
      if(var[-1] != '/')
	return var + "/";
      return var;
    }, node);
    
    if(sizeof(foo-({0})) != sizeof(foo))
      return 0;
    return foo;
    
   case TYPE_DIR:
    if (!strlen( var ) || file_size( var ) != -2)
    {
      node->error = var + " is not a directory";
      return 0;
    }
    if(var[-1] != '/')
      return var + "/";
    return var;
    
   case TYPE_TEXT_FIELD:
    var -= "\r";
   case TYPE_STRING:
   case TYPE_FILE:
   case TYPE_LOCATION:
    return var;
    
   case TYPE_PASSWORD:
    return crypt(var);
    
   case TYPE_FLAG:
    return lower_case(var) == "yes";
    
   case TYPE_INT:
    int tmp;
    
    if (!sscanf( var, "%d", tmp ))
    {
      node->error= var + " is not an integer";
      return 0;
    }
    return tmp;
    
   case TYPE_FLOAT:
    float tmp;
    
    if (!sscanf( var, "%f", tmp ))
    {
      node->error= var + " is not a arbitary precision floating point number";
      return 0;
    }
    return tmp;
    
   case TYPE_INT_LIST:
    if(node->data[VAR_MISC])
      return (int)var;
    else
      return map_array((var-" ")/",", lambda(string s){ 
	return (int)s;
      });
    
    
   case TYPE_STRING_LIST:
    if(node->data[VAR_MISC])
      return var;
    else
      return (var-" ")/",";
    
   case TYPE_COLOR:
    int red, green, blue;
    
    if (sscanf( var, "%d:%d:%d", red, green, blue ) != 3
	|| red < 0 || red > 255 || green < 0 || green > 255
	|| blue < 0 || blue > 255)
    {
      node->error = var + " is not a valid color specification";
      return 0;
    }
    return (red << 16) + (green << 8) + blue;
  }
  error("Unknown type.\n");
}

mapping std_redirect(object o, object id)
{
  string loc, l2;

  if(!o)  o=root;
  
  if(id && sizeof(id->referer))
    loc=((((((id->referer*" ")/"#")[0])/"?")[0])+"?"+(bar++)
	 +"#"+o->path(1));
  else
    loc = CONFIG_URL+o->path(1)[1..10000]+"?"+bar++;
  
  if(sscanf(loc, "%s/(%*s)%s",l2, loc) == 3)
    loc = l2 + loc;		// Remove the prestate.

//  http://www:22020//Configuration/ -> http://www:22202/Configurations/

  loc = replace(replace(replace(loc, "://", ""), "//", "/"), "", "://");

  return http_redirect(http_decode_string(loc));
}

string configuration_list()
{
  string res="";
  object o;
  foreach(roxen->configurations, o)
    res += "<option>Copy of '"+o->name+"'";
  return res;
}

string new_configuration_form()
{
  return replace(read_bytes("etc/newconfig.html"), ({"$COPIES","$configurl"}), 
		 ({configuration_list(),CONFIG_URL})) +
    "\n\n<hr noshade><p align=right><a href=http://www.roxen.com/>"+
    roxen->real_version +"</a></body>";
}

mapping module_nomore(string name, int type, object conf)
{
  mapping module;
  object o;
// perror("Module: "+name+"\n");
  if((module = conf->modules[name])
    && (!module->copies && module->enabled))
    return module;
  if(((type & MODULE_DIRECTORIES) && (o=conf->dir_module))
//   || ((type & MODULE_AUTH)  && (o=conf->auth_module))
//   || ((type & MODULE_TYPES) && (o=conf->types_module))
     || ((type & MODULE_MAIN_PARSER)  && (o=conf->parse_module)))
    return conf->modules[conf->otomod[o]];
}

mixed new_module_copy(object node, string name, object id)
{
  object orig;
  int i;
  mapping module;
  module = node->config()->modules[name];
  switch(node->type)
  {
   default:
    error("Foo? Illegal node in new_module_copy\n");
    
   case NODE_MODULE_COPY:
    node=node->up;
    
   case NODE_MODULE_MASTER_COPY:
   case NODE_MODULE:
    node=node->up;
    
   case NODE_CONFIGURATION:
  }
  
  if(module) if(module->copies) while(module->copies[i])  i++;
  roxen->enable_module(name+"#"+i);
  module = node->config()->modules[name];

  if(!module) return http_string_answer("This module could not be enabled.\n");
    
  node = node->descend(module->name);
  // Now it is the (probably unbuilt) module main node...
  
  node->data = module;
  node->describer = describe_module;
  node->type = NODE_MODULE;
  build_module(node);
  
  //  We want to see the new module..
  node->folded=0; 
  
  // If the module have copies, select the actual copy added..
  if(module->copies) node = node->descend((string)i, 1); 
  
  // Now it is the module..
  // We want to see this one immediately.
  node->folded = 0;
  
  // Mark the node and all its parents as modified.
  node->change(1);
  
  return std_redirect(root, id);
}

mixed new_module_copy_copy(object node, object id)
{
  roxen->current_configuration = node->config();
  return new_module_copy(node, node->data->sname, id);
}

string new_module_form(object id, object node)
{
  int i;
  mixed a,b;
  string q;
  array mods;
  array (string) res;
  
  if(!roxen->allmodules || sizeof(id->pragma))
  {
   perror("CONFIG: Rescanning modules.\n");
   roxen->rescan_modules();
   perror("CONFIG: Done.\n");
  }
  
  a=roxen->allmodules;
  mods=sort_array(indices(a), lambda(string a, string b, mapping m) { 
    return m[a][0] > m[b][0];
  }, a);
  
  res = ({default_head("Add a module")+"\n\n"+
	  "<table width=500><tr><td width=500>"
  "<h2>Select a module to add from the list below</h2>" });
  
  foreach(mods, q)
  {
    if(b = module_nomore(q, a[q][2], node->config()))
    {
      if(b->sname != q)
	res += ({("<p>"+
		  (roxen->QUERY(BS)?"<h2>"+a[q][0]+"</h2>":
		  "<img alt=\""+a[q][0]+"\" src=/auto/module/"+
		   q+" width=500>")+ "<br>"+a[q][1] + "<p>"
		  "<i>A module of the same type is already enabled ("+ b->name
		  + "). <a href=\"/(delete)" + node->descend(b->name, 1)->path(1)
		  + "?"+(bar++)+
		  "\">Disable that module</a> if you want this one insted</i>"
		  "\n<p><br><p>")});
    } else {
      res += ({"<p><a href=/(newmodule)"+node->path(1)+"?"+q+"=1>"+
		 (roxen->QUERY(BS)?"<h2>"+a[q][0]+"</h2>":
		  "<img border=0 alt=\""+a[q][0]+"\" src=/auto/module/"+
					q+" width=500>")+
		 "</a><br>"+a[q][1]+"<p><br><p>"});
    }
  }

  return res*""+"</td></tr></table>";
}

mapping new_module(object id, object node)
{
  string varname;
  
  if(!sizeof(id->variables))
    return stores(new_module_form(id, node));
  
  varname=indices(id->variables)[0];
  
  return new_module_copy(node, varname, id);
}

int low_enable_configuration(string name, string type)
{
  object node;
  
  if(strlen(name) && name[-1] == '~')
    name = "";

  if(search(name, "/")!= -1)
    return 0;
  
  foreach(roxen->configurations, node)
    if(node->name == name) 
      return 0;

  switch(name)
  {
   case "":
   case " ":
   case "\t":
   case "CVS":
   case "Global Variables":
   case "global variables":
   case "Global variables":
    return 0;
    break;
    
   default:
    object o, confnode;
    
    switch(lower_case((type/" ")[0]))
    {
     default: /* Minimal configuration */
       roxen->enable_configuration(name);
      break;
      
     case "standard":
      roxen->enable_configuration(name);
      roxen->enable_module("cgi#0");
      roxen->enable_module("contenttypes#0");
      roxen->enable_module("ismap#0");
      roxen->enable_module("lpcscript#0");
      roxen->enable_module("htmlparse#0");
      roxen->enable_module("directories#0");
      roxen->enable_module("userdb#0");
      roxen->enable_module("userfs#0"); // I _think_ we want this.
      roxen->enable_module("filesystem#0");
      break;
      
     case "ipp":
      roxen->enable_configuration(name);
      roxen->enable_module("contenttypes#0");
      roxen->enable_module("ismap#0");
      roxen->enable_module("htmlparse#0");
      roxen->enable_module("directories#0");
      roxen->enable_module("filesystem#0");
      break;
      
     case "proxy":
      roxen->enable_configuration(name);
      roxen->enable_module("proxy#0");
      roxen->enable_module("gopher#0");
      roxen->enable_module("ftpgateway#0");
      roxen->enable_module("contenttypes#0");
      roxen->enable_module("wais#0");
      break;
      
     case "copy":
      string from;
      mapping tmp;
      sscanf(type, "%*s'%s'", from);
      tmp = roxen->copy_configuration(from, name);
      if(!tmp) error("No configuration to copy from!\n");
      tmp["spider#0"]->LogFile = "../logs/"
	+roxen->short_name(name)+"/Log";
      roxen->save_it(name);
      roxen->enable_configuration(name);
    }    
    confnode = root->descend("Configurations");
    node=confnode->descend(name);

    node->describer = describe_configuration;
    node->saver = save_configuration;
    node->data = roxen->configurations[-1];
    node->type = NODE_CONFIGURATION;
    build_configuration(node);
    node->folded=0;
    node->change(1);
    
    if(o = node)
    {
      if(o=o->descend( "Global", 1 ))
      {
	o->folded = 0;
	if(o->descend( "Server URL", 1 ))
	{
	  o->descend( "Server URL"  )->folded = 0;
	  o->descend( "Server URL"  )->change(1);
	}
	if(o->descend( "Listen ports", 1  ))
	{
	  o->descend( "Listen ports"  )->folded = 0;
	  o->descend( "Listen ports"  )->change(1);
	}
      }
    }
    if(lower_case((type/" ")[0])=="standard" && (o=node))
    {
      if(o=o->descend( "Filesystem", 1 ))
      {
	o->folded=0;
	if(o=o->descend( "0", 1))
	{
	  o->folded=0;
	  if(o=o->descend( "Search path", 1))
	  {
	    o->folded=0;
	    o->change(1);
	  }
	}
      }
    }
  }
  return 1;
}

mapping new_configuration(object id)
{
  if(!sizeof(id->variables))
    return stores(new_configuration_form());

  if(!id->variables->name)
    return stores(default_head("Bad luck")+
		  "<h1>No configuration name?</h1>"
		  "Either you entered no name, or your WWW-browser "
		  "failed to include it in the request");
  
  id->variables->name=(replace(id->variables->name,"\000"," ")/" "-({""}))*" ";
  if(!low_enable_configuration(id->variables->name, id->variables->type))
    return stores(default_head("Bad luck") +
		  "<h1>Illegal configuration name</h1>"
		  "The name of the configuration must contain characters"
		  " other than space and tab, it should not end with "
		  "~, and it must not be 'CVS', 'Global Variables' or "
		  "'global variables', nor the name of an existing "
		  "configuration, and the character '/' cannot be included");
  return std_redirect(root->descend("Configurations"), id);
}

int conf_auth_ok(mixed auth)
{
  if(!(auth && sizeof(auth)>1))
    return 0;
  
  if(sscanf(auth[1], "%s:%s", auth[0], auth[1]) < 2)
    return 0;
  
  if((auth[0] == roxen->QUERY(ConfigurationUser))
     && crypt(auth[1], roxen->QUERY(ConfigurationPassword)))
    return 1;
}

mapping initial_configuration(object id)
{
  object n2;
  string res, error;
  
  if(id->prestate->initial && id->variables->pass)
  {
    error="";
    if(id->variables->pass != id->variables->pass2)
      error = "You did not type the same password twice.\n";
    if(!strlen(id->variables->pass))
      error += "You must specify a password.\n";
    if(!strlen(id->variables->user))
      error += "You must specify a username.\n";
    if(!strlen(error))
    {
      object node;
/*    build_root(root);*/
     
      // Should find the real node instead of assuming 'Globals'...
      node = find_node("/Globals");
      node->folded=0;
      node->change(1);
      
      if(!node)
	return stores("Fatal configuration error, no 'Globals' node found.\n");
      
      roxen->QUERY(ConfigurationPassword) = crypt(id->variables->pass);
      roxen->QUERY(ConfigurationUser) = id->variables->user;

      n2 = node->descend("Configuration interface", 1)->descend("Password", 1);
      n2->data[VAR_VALUE]=roxen->QUERY(ConfigurationPassword);
      n2->change(1);	

      n2 = node->descend("Configuration interface", 1)->descend("User", 1);
      n2->data[VAR_VALUE] = roxen->QUERY(ConfigurationUser);
      n2->change(1);	
	
      root->save();
      return std_redirect(root, id);
    }
  }
  
  res = default_head("Welcome to Roxen Challenger") + "<hr noshade>";

  res += read_bytes("etc/welcome.html");
  if(error && strlen(error))
    res += "\n<p><b>"+error+"</b>";
  
  res += ("<pre>"
	  "<font size=+1>"
	  "<form action=/(initial)/Globals/>"
	  " User name <input name=user type=string>\n"
	  "  Password <input name=pass type=password>\n"
	  "     Again <input name=pass2 type=password>\n"
//   Avoid this trap for people that likes to shoot themselevs in the foot.
//   /Peter
//	  "IP-pattern <input name=pattern type=string>\n"
	  "           <input type=submit value=\"Use these values\">\n"
	  "</form></font></pre>");
  
  return stores(res);
}

object module_of(object node)
{
  while(node)
  {
    if(node->type == NODE_MODULE_COPY)
      return node->data;
    if(node->type == NODE_MODULE_MASTER_COPY)
      return node->data->master;
    node = node->up;
  }
  return roxen;
}

string extract_almost_top(object node)
{
  if(!node) return "";
  for(;node && (node->up!=root);node=node->up);
  if(!node) return "";
  return node->path(1);
}




string tablist(array(string) nodes, array(string) links, int selected)
{
  array res = ({});
  for(int i=0; i<sizeof(nodes); i++)
    if(i!=selected)
      PUSH("<a href=\""+links[i]+"\"><img alt=\""+nodes[i]+"  \" src=/auto/unselected/"+replace(nodes[i]," ","%20")+" border=0></a>");
    else
      PUSH("<a href=\""+links[i]+"\"><img alt=\""+nodes[i]+"  \" src=/auto/selected/"+replace(nodes[i]," ","%20")+" border=0></a>");
  PUSH("<br>");
  return res*"";
}

mapping (string:string) selected_nodes =
([
  "Configurations":"/Configurations",
  "Globals":"/Globals",
  "Status":"/Status",
  "Errors":"/Errors",
]);

constant tabs = ({
  "Configurations",
  "Globals",
  "Status",
  "Errors",
});

constant tab_names = ({
 "Virtual servers", 
 "Global variables",
 "Status info",
 "Error log",
});
		

string display_tabular_header(object node)
{
  string p, s;
  
  s = extract_almost_top(node) - "/";
  selected_nodes[s] = node->path(1);

  array links = ({
    selected_nodes[tabs[0]]+"?"+(bar++),
    selected_nodes[tabs[1]]+"?"+(bar++),
    selected_nodes[tabs[2]]+"?"+(bar++),
    selected_nodes[tabs[3]]+"?"+(bar++),
  });
  return tablist(tab_names, links, search(tabs,s));
}

// Return the number of unfolded nodes on the level directly below the passed
// node.

int nunfolded(object o)
{
  int i;
  if(o = o->down)
    do { i+=!o->folded; } while(o=o->next);
  return i;
}


object module_font = Font()->load("base_server/config/font");
object button_font = module_font;

mapping auto_image(string in, object id)
{
  string key, value;
  array trans = ({ (int)("0x"+dR),(int)("0x"+dG),(int)("0x"+dB) });
  mapping r;
  mixed e;
  object i;

  if(!id->pragma["no-cache"] && (r=cache_lookup("config_images", in)))
    return r;
  if(!sscanf(in, "%s/%s", key, value))
    key=in;

  switch(key)
  {
   case "module":
    i = draw_module_header(roxen->allmodules[value][0],
			   roxen->allmodules[value][2],
			   module_font);
    break;
    
   case "button":
    i=draw_config_button(value,button_font);
    break;

   case "fold":
   case "fold2":
    i = draw_fold((int)reverse(key));
    break;
    
   case "unfold":
   case "unfold2":
    i = draw_unfold((int)reverse(key));
    break;

   case "back":
    i = draw_back((int)reverse(key));
    break;
    
   case "selected":
    i=draw_selected_button(value,button_font);
    break;

   case "unselected":
    i=draw_unselected_button(value,button_font);
    break;
  }
  if(i) r = http_string_answer(i->togif(128,@trans),"image/gif");
  i=0;
  cache_set("config_images", in, r);
  return r;
}


mapping configuration_parse(object id)
{
  array (string) res=({});
  string tmp;
  // Is it an image?
  if(sscanf(id->not_query, "/image/%s", tmp))
    return file_image(tmp) || (["data":"No such image"]);
  
  object o;
  int i;

  id->since = 0; // We do not want 'get-if-modified-since' to work here.


  // Permisson denied by address?
  if(id->remoteaddr)
    if(strlen(roxen->QUERY(ConfigurationIPpattern)) &&
       !glob(roxen->QUERY(ConfigurationIPpattern),id->remoteaddr))
      return stores("Permission denied.\n");
  
  // Permission denied by userid?
  if(!id->misc->read_allow)
  {
    if(!(strlen(roxen->QUERY(ConfigurationPassword))
	 && strlen(roxen->QUERY(ConfigurationUser))))
      return initial_configuration(id); // Never configured before
    else if(!conf_auth_ok(id->auth))
      return http_auth_failed("Roxen server maintenance"); // Denied
  } else {
    id->prestate = aggregate_multiset(@indices(id->prestate)
                                      &({"fold","unfold"}));

    if(sizeof(id->variables)) // This is not 100% neccesary, really.
      id->variables = ([ ]);
  }

  if(sscanf(id->not_query, "/auto/%s", tmp))
    return auto_image(tmp,id) || (["data":"No such image"]);

  o = find_node(id->not_query); // Find the requested node (from the filename)

  if(!o) // Bad node, perhaps an old bookmark or something.
  {
    id->referer = ({ });
    return std_redirect(0, id);
  } else if(o == root) {
    // The URL is http://config-url/, not one of the top nodes, but
    // _above_ them. This is supposed to be some nice introductory
    // text about the configuration interface...
    return http_string_answer(default_head("")+display_tabular_header(root)+read_bytes("etc/config.html"),"text/html");
  }
  
  if(sizeof(id->prestate))
  {
    switch(indices(id->prestate)[0])
    {
      // It is possible to mark variables as 'VAR_EXPERT', this
      // will make it impossible to configure them whithout the
      // 'expert' mode. It can be useful.
    case "expert":   expert_mode = 1;  break;
    case "noexpert": expert_mode = 0;  break;
      
      // Fold and unfold nodes, this is _very_ simple, once all the
      // supporting code was writte.
    case "fold":     o->folded=1;      break;
    case "unfold":   o->folded=0;      break;

    case "foldall":
      o->map(lambda(object o) {	o->folded=1; });
      break;


    case "unfoldmodified":
      o->map(lambda(object o) { if(o->changed) o->folded=0; });
      break;


      // There is no button for this in the configuration interface,
      // the results are quite horrible, especially when applied to
      // one of the top nodes.
    case "unfoldall":
      o->map(lambda(object o) { o->folded=0; });
      break;

      
      // And now the actual actions..
      
      // Re-read a module from disk
      // This is _not_ as easy as it sounds, since quite a lot of
      // caches and stuff has to be unvalidated..
    case "refresh":
    case "reload":
      object mod;
      string name, modname;
      mapping cmod;
      
      mod = module_of(o);
      if(!mod || mod==roxen)
	error("This module cannot be updated.\n");
      name = module_short_name(mod);
      if(!name)
	error("This module cannot be updated");
      sscanf(name, "%s#%*s", modname);
      roxen->current_configuration = o->config();
      if(!(cmod = o->config()->modules[ modname ]))
 	error("This module cannot be updated");
      
      o->save();
      cache_remove("modules", modname);
      _master->set_inhibit_compile_errors(1);
      
      if(!roxen->load_module(modname))
      {
	mapping rep;
	rep = http_string_answer("The reload of this module failed.\n"
				 "This is (probably) the reason:\n<pre>"
				 + _master->errors + "</pre>" );
	_master->set_inhibit_compile_errors(0);
	return rep;
      }
      object mod;
      if(!roxen->disable_module(name)) error("Failed to disable module.\n");
      if(!(mod=roxen->enable_module(name)))error("Failed to enable module.\n");
      
      o->clear();
      roxen->fork_it();
      
      if(mappingp(o->data))
      {
	o->data = o->config()->modules[modname];
	build_module(o);
      } else {
	object n = o->up;
	n->clear();
	n->data = n->config()->modules[modname];
	build_module(n);
      }
      break;
      
      /* Shutdown Roxen... */
    case "shutdown":	
      return roxen->shutdown();
      
      /* Restart Roxen, somewhat more nice. */
    case "restart":	
       return roxen->restart();
      
       /* Rename a configuration. Not Yet Used... */
    case "rename":
      if(o->type == NODE_CONFIGURATION)
      {
	mv("configurations/"+o->data->name, 
	   "configurations/"+id->variables->name);
	o->data->name=id->variables->name;
      }
      break;
      
      /* This only asks "do you really want to...", it does not delete
       * the node */

    case "delete":	
     PUSH(default_head("Roxen Configuration"));
//     PUSH("<hr noshade>");
      
      switch(o->type)
      {
       case NODE_CONFIGURATION:
	PUSH("<font size=+2>Do you really want to delete the configuration "+
	     o->data->name + ", all its modules and their copies?"
	     "\n\n<p></font>");
	break;
	
       case NODE_MODULE_MASTER_COPY:
       case NODE_MODULE:
	PUSH("<font size=+2>Do you really want to delete the module "+
	     o->data->name + ", and its copies?\n\n<p></font>");
	break;
	
       case NODE_MODULE_COPY_VARIABLES:
	
       case NODE_MODULE_COPY:
	PUSH("<font size=+2>Do you really want to delete this copy "
	     " of the module "+ o->up->data->name + "?\n\n<p></font>");
	break;
	
       case NODE_CONFIGURATIONS:
	return stores("You don't want to do that...\n");
      }
      PUSH("<font size=+2><i>This action cannot be undone.\n\n<p></font>"+
	   TABLEP("<table>", "") +"<tr><td><form action="+
	   o->path(1)+">"
	   "<input type=submit value=\"No, I do not want to delete it\"> "
	   "</form></td><td><form action=/(really_delete)"+o->path(1)+
	   "><input type=submit value=\"Go ahead\"></form></td></tr> "
	   "</table>");
      
      return stores(res*"");
      break;
      
      /* When this has been called, the node will be * _very_ deleted
       * The amount of work needed to delete a node does vary
       * depending on the node, since there is no 'zap' function in
       * the nodes at the moment. I will probably move this code into
       * function-pointers in the nodes.
       */

    case "really_delete":
      id->referer = ({ CONFIG_URL + o->up->path(1) });
      
      switch(o->type)
      {
       case NODE_CONFIGURATION:
	object oroot;
	
	for(i=0; i<sizeof(roxen->configurations); i++)
	  if(roxen->configurations[i] == o->data)
	    break;
	
	if(i==sizeof(roxen->configurations))
	  error("Configuration not found.\n");
	
	roxen->remove_configuration(o->data->name);

	if(roxen->configurations[i]->ports_open)
	  map_array(values(roxen->configurations[i]->ports_open), destruct);
	destruct(roxen->configurations[i]);
	
	roxen->configurations = 
	  roxen->configurations[..i-1] + roxen->configurations[i+1..];
	
	o->change(-o->changed);
	o->dest();
	break;
	
       case NODE_MODULE_COPY_VARIABLE:
       case NODE_MODULE_COPY_VARIABLES:
	// Ehum? Lets zap the module instead of it's variables...
	o=o->up;
	
       case NODE_MODULE_COPY:
	string name;
	object n;
	
	name = module_short_name(o->data);
	roxen->disable_module(name);
	// Remove the suitable part of the configuration file.
	roxen->remove(name);
	o->change(-o->changed);
	n=o->up;
	o->dest();
	
	if(!objectp(n))
	{
	  o=root; 
	  // Error, really, no parent module for this module class.
	} else {
	  if(!sizeof(n->data->copies))
          {
	    // No more instances in this module, let's zap the whole class.
	    /* 
	       object hmm=n->config();
	       if(!hmm) error("Cannot find configuration node for module.\n");
	       */

	    // The configuration node. n->config() seems to be 
	    // n->up->data...
	    o=n->up; 
	    
	    n->change(-n->changed);
	    n->dest();
	    build_configuration(o);
	    return std_redirect(o, 0); 
	    // Bugs and returns to the top if id is set...
	  } else
	    o = n;
	}
	break;
	
       case NODE_MODULE_MASTER_COPY:
       case NODE_MODULE:
	 // A 'one of a kind' module.
	if(o->data->copies)
	{
	  if(sizeof(o->data->copies))
	  {
	    int i;
	    array a,b;
	    a=indices(o->data->copies);
	    b=values(o->data->copies);
	    name=o->config()->otomod[b[0]];
	    i=sizeof(a);
	    while(i--) 
	    {
	      roxen->disable_module(name+"#"+a[i]);
	      roxen->remove(name+"#"+a[i]);
	    }
	  } else if(o->data->master) {
	    name=o->config()->otomod[o->data->enabled];
	  } 
	} else if(o->data->enabled) {
	  name=o->config()->otomod[o->data->enabled];
	  roxen->disable_module(name+"#0");
	  roxen->remove(name+"#0");
	}
	o->change(-o->changed);
	o->dest();
	break;
      }
      break;


      // Create a new configuration. All the work is done in another
      // function.. This _should_ be the case with some of the other
      // actions too.
     case "newconfig":
       id->referer = ({ CONFIG_URL + o->path(1) });
       return new_configuration(id);


       // Save changes done to the node 'o'. Currently 'o' is the root
       // node most of the time, thus saving _everything_.
     case "save":
      if(save_it(id, o))
	return 0;
      break;


      // Set the password and username, the first time, or when
      // the action 'changepass' is requested.
     case "initial":
     case "changepass":
      return initial_configuration(id);
      

      // Hmm. No idea, really. Beats me :-)  /Per
    case "new":
      o->new();
      break;

      // Add a new module to the current configuration.
    case "newmodule":
      id->referer = ({ CONFIG_URL + o->path(1) });
      return new_module(id,o);


      // Add a new copy of the current module to the current configuration.
     case "newmodulecopy":
      id->referer = ({ CONFIG_URL + o->path(1) });
      new_module_copy_copy(o, id);
      break;


      // Set a variable to a new (or back to an old..) value.
     case "set":
      mixed tmp;
      o->error = 0;
      if(sizeof(id->variables))
	tmp=decode_form_result(values(id->variables)[0],
			       o->data[VAR_TYPE], o, id->variables);
      else
	tmp=0;
      if(!module_of(o)) perror("No module for this node.\n");
      if(!o->error && module_of(o) 
	 && module_of(o)->check_variable)
	o->error = module_of(o)->check_variable(o->data[VAR_SHORTNAME], tmp);
	
      if(!o->error)
	if(!equal(tmp, o->data[VAR_VALUE]))
	{
	  if(!o->original)
	    o->original = o->data[VAR_VALUE];
	  o->data[VAR_VALUE]=tmp;
	  if(equal(o->original, tmp))
	    o->change(-1);
	  else if(!o->changed)
	    o->change(1);
	} 
      break;
    }
    return std_redirect(o, id);
  }
  
  PUSH(default_head("Roxen server configuration", root->changed?o->path(1):0));
  PUSH("\n"+display_tabular_header( o )+"\n<br>\n");
//  PUSH("<img src=/image/roxen-rotated.gif alt=\"\"  align=right>");

  PUSH("<dl>\n");

  if(o->up != root && o->up)
    PUSH("<a href=\""+ o->up->path(1)+"?"+(bar++)+"\">"
	 "<img src=/auto/back alt='[Up]' align=left hspace=0 border=0></a> ");

  if(i=o->folded) o->folded=0;
  PUSH(o->describe(1));
  o->folded=i;
  
  PUSH("</dl>");
//  PUSH("<nobr><img height=15 src=/auto/button/ width=100% align=right>");
  PUSH("<br clear=all>");
  PUSH("<table width=100%><tr><td bgcolor=#"+bdR+bdG+bdB+">");
  PUSH("<img src=/auto/button/>");
  
  if(o->type == NODE_CONFIGURATIONS)
    BUTTON(newconfig, "New virtual server", left);
  
  if(o->type == NODE_CONFIGURATION)
    BUTTON(newmodule, "New module", left);
  
  if(o->type == NODE_MODULE)
  {
    BUTTON(delete, "Delete", left);
    if(o->data->copies)
      BUTTON(newmodulecopy, "Copy module", left);
  }

  i=0;
  if(o->type == NODE_MODULE_MASTER_COPY || o->type == NODE_MODULE_COPY 
     || o->type == NODE_MODULE_COPY_VARIABLES)
  {
    BUTTON(delete, "Delete", left);
    BUTTON(refresh, "Reload", left);
  }
  
  if(o->type == NODE_CONFIGURATION)
    BUTTON(delete,"Remove virtual server", left);

  if(nunfolded(o))
    BUTTON(foldall, "Close all",left);
  if(o->changed)
    BUTTON(unfoldmodified, "Open all modified", left);

  if((o->changed||root->changed))
    BUTTON(save, "Save changes", left);
  BUTTON(restart, "Restart", left);
  BUTTON(shutdown,"Shutdown", left);

  
  PUSH("<img src=/auto/button/%20>");
  PUSH("</nobr><br clear=all>");
  PUSH("</td></tr></table>");
  PUSH("<p align=right><a href=$docurl>"+roxen->real_version +"</a></body>");
  return stores(res*"");
}





