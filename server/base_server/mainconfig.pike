inherit "config/builders";
string cvs_version = "$Id: mainconfig.pike,v 1.96 1998/02/20 11:16:34 per Exp $";
//inherit "roxenlib";

inherit "config/draw_things";

// import Array;
// import Stdio;

string status_row(object node);
string display_tabular_header(object node);
object get_template(string t);

/* Work-around for Simulate.perror */
#define perror roxen_perror

#include <confignode.h>
#include <module.h>

#define dR "ff"
#define dG "ff"
#define dB "ff"

#define bdR "00"
#define bdG "50"
#define bdB "90"


#define BODY "<body bgcolor=white text=black link=darkblue vlink=black alink=red>"

#define TABLEP(x, y) (id->supports->tables ? x : y)
#define PUSH(X) do{res+=({(X)});}while(0)

int bar=time(1);
multiset changed_port_servers;

class Node {
  inherit "struct/node";

  mixed original;
  int changed, moredocs;
  int bar=time();
  function saver;
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
      return ("<a name=\""+name+"\" href=\"/(unfold)" + name + "?"+(bar++)+
	      "\">\n<img border=0 align=baseline src=/auto/unfold"
	      +(changed?"2":"")+" alt=\""+(changed?"*-":"--")+"\">"
	      "</a>\n "+s+"\n");
    else
      return ("<a name=\""+name+"\" href=\"/(fold)" + name + "?"+(bar++)+
	      "\">\n<img border=0 src=/auto/fold"+(changed?"2":"")
	      +"  alt="+(changed?"**":"\"\\/\"")+">"
	      "</a>\n "+s+"\n");
  }

  mixed describe(int i, object id)
  {
    array (string) res=({""});
    object node,prevnode;
    mixed tmp;

    if(describer)
      tmp = describer(this_object(), id);
#ifdef NODE_DEBUG
    else
    {
      perror("No describer in node "+path(1)+"\n");
      return 0;
    }
#endif
    if(mappingp(tmp)) {
//      werror("Got mapping.\n");
      return tmp;
    }
    if(arrayp(tmp) && sizeof(tmp))
      PUSH(tmp[0] +  "<dt>" + (i?tmp[i]:show_me(tmp[1])) + "\n");
    else if(stringp(tmp) && strlen(tmp))
      PUSH("<dt>"+(i?tmp:show_me(tmp)) + "\n");
    else if(!tmp)
      return "";

    if(!folded)
    {
      PUSH("<dl><dd>\n");
      node = down;
      array node_desc = ({});
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
	node_desc += ({ prevnode->describe() });
      }
      PUSH(node_desc*"\n");
      PUSH("</dl>\n\n");
    }
    return res*"";
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
    if(changed && type == NODE_MODULE_COPY_VARIABLE &&
       data[VAR_TYPE] == TYPE_PORTS) {
      roxen->configuration_interface_obj->changed_port_servers[config()] = 1;
      // A port was changed in the current server...
    }
    if(saver) saver(this_object(), config());
    else  change(-changed);
  }
}

int restore_more_mode()
{
  return !!file_stat(".more_mode");
}

object root=Node();
int expert_mode, more_mode=restore_more_mode();

void save_more_mode()
{
  if(more_mode)
    open(".more_mode", "wct");
  else
    rm(".more_mode");
}


void create()
{
  build_root(root);
  init_ip_list();
  call_out(init_ip_list, 0);
}

// Note stringification of ACTION and ALIGN
#if 0
#define BUTTON(ACTION,TEXT,ALIGN) do{PUSH("<a href=\"/(ACTION)"+(o?o->path(1):"/")+"?"+(bar++)+"\"><img border=0 hspacing=0 vspacing=0 src=\"/auto/button/"+(lm?"lm/":"")+replace(TEXT," ","%20")+"\" alt=\""+(lm?"/ ":" ")+TEXT+" /\""+(("ALIGN"-" ")=="left"?"":" align="+("ALIGN"-" "))+"></a>");lm=0;}while(0)
#else

#if constant(cpp)
#define BUTTON(ACTION,TEXT,ALIGN) do{buttons += ({({"<a href=\"/("#ACTION")"+(o?o->path(1):"/")+"?"+(bar++)+"\"><img border=0 hspacing=0 vspacing=0 src=\"/auto/button/"+(lm?"lm/":""),replace(TEXT," ","%20")+"\" alt=\""+(lm?"/ ":" ")+TEXT+" /\""+((#ALIGN-" ")=="left"?"":" align="+(#ALIGN-" "))+"></a>"})});lm=0;}while(0)
#else /* !constant(cpp) */
#define BUTTON(ACTION,TEXT,ALIGN) do{buttons += ({({"<a href=\"/(ACTION)"+(o?o->path(1):"/")+"?"+(bar++)+"\"><img border=0 hspacing=0 vspacing=0 src=\"/auto/button/"+(lm?"lm/":""),replace(TEXT," ","%20")+"\" alt=\""+(lm?"/ ":" ")+TEXT+" /\""+(("ALIGN"-" ")=="left"?"":" align="+("ALIGN"-" "))+"></a>"})});lm=0;}while(0)
#endif /* constant(cpp) */
#define PUSH_BUTTONS(CLEAR) do{if(sizeof(buttons)){buttons[-1][0]+="rm/";res+=`+(@buttons);if(CLEAR){PUSH("<br clear=all>");}}lm=1;buttons=({});}while(0)

#endif /* 0 */


string default_head(string h, string|void save)
{
  return ("<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Draft//EN\">"
	  "<head><title>"+h+"</title>\n<META HTTP-EQUIV=\"Expires\" CONTENT=\"0\">\n</head>\n"+ BODY+"\n");
}

object find_node(string l)
{ 
  array tmp = l/"/"-({""});
  object o;
  if(!sizeof(tmp)) return root;
  for(o=root; sizeof(tmp) && (o=o->descend(tmp[0],1)); tmp=tmp[1..]);
  if(!o) return 0;
  return o;
}

mapping file_image(string img)
{
  object o;
  o=open("roxen-images/"+img, "r");
  if (!o)  return 0;
  return ([ "file":o, "type":"image/" + ((img[-1]=='f')?"gif":"jpeg"), ]);
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
//      "Expires":http_date(time(1)+2),
//	"Pragma":"no-cache",
	"Last-Modified":http_date(time(1)),
	])
      ]);
}

#define CONFIG_URL roxen->config_url()

mapping verify_changed_ports(object id, object o)
{
  string res = default_head("Roxen Config: Setting Server URL") +
    ("<h1>Set the correct server URL</h1>"
     "As you have changed the open ports in one or more servers "
     "you might have to adjust the default server URL(s). Check the "
     "correct URL(s) below and modify it as needed. The server URLs are among "
     "other things used for redirects. "
     "<form action=\"/(modify_server_url)"+o->path(1)+"\">");
  foreach(indices(changed_port_servers), object server)
  {
    int glob;
    string name;
    if(!server) {
      glob = 1;
      server = roxen;
      name="Global Variables";
#if 0
      perror("Config Interface, URL %s, Ports %O\n",
	     GLOBVAR(ConfigurationURL), 
	     GLOBVAR(ConfigPorts));
#endif
    } else {
      glob = 0;
      name = server->name;
#if 0
      perror("Server %s, URL %s, Ports %O\n", server->name,
	     server->query("MyWorldLocation"),
	     server->query("Ports"));
#endif
    }
    
    string def;
    if(glob) {
      def = GLOBVAR(ConfigurationURL);
      res += "<h3>Select Configuration Interface URL: </h3>\n<pre>";
    } else {
      def = server->query("MyWorldLocation");
      res += sprintf("<h3>Select server URL for for %s: </h3>\n"
		     "<pre>", name);
    }
    
    foreach((glob ? GLOBVAR(ConfigPorts) : server->query("Ports")),
	     array port) {
      string prt;
      if(port[1] == "tetris")
	continue;
      switch(port[1][0..2])
      {
       case "ssl":
	prt = "https://";
	break;
	
       default:
	prt = port[1]+"://";
      }
      if(port[2] && port[2]!="ANY")
	prt += port[2];
#if efun(gethostname)
      else
	prt += (gethostname()/".")[0] + "." +
	  (glob ? roxen->get_domain() : server->query("Domain"));
#endif
      
      prt += ":"+port[0]+"/";
      if(prt != def)
	res += sprintf("     <input type=radio name=\"%s\" value=\"%s\">     %s\n",
		       name, prt, prt);

    }
      res += sprintf("     <input type=radio checked value=own name=\"%s\">     "
		     "<input size=70 name=\"%s->own\" "
		     "value=\"%s\">\n</pre><p>",
		     name, name, def);
  }
  changed_port_servers = (<>);
  return stores(res+"<input type=submit value=\"Continue...\"></form>");
}

mapping save_it(object id, object o)
{
  changed_port_servers = (<>);
  root->save();
  roxen->update_supports_from_roxen_com();
  roxen->initiate_configuration_port( 0 );
  id->referer = ({ CONFIG_URL + o->path(1) });
  if(sizeof(changed_port_servers))
    return verify_changed_ports(id, o);
}


object find_module(string name, object in)
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
    foreach(values(in->modules), mod)
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
    modules = in->modules;
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
   case TYPE_CUSTOM:
    return node->data[ VAR_MISC ][2]( var, type, node, allvars );
    
  case TYPE_MODULE_LIST:
    return Array.map(var/"\000", find_module);

  case TYPE_MODULE:
   return find_module((var/"\000")[0], node->config());

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

       if(allvars["key_"+i] || allvars["cert_"+i])
	 op[i][3] =
	   (allvars["key_"+i]&&strlen(allvars["key_"+i])?
	    "key-file "+allvars["key_"+i]+"\n":"")+
	   (allvars["cert_"+i]&&strlen(allvars["cert_"+i])?
	    "cert-file "+allvars["cert_"+i]+"\n":"");
     } else  // Delete this port.
       op[i]=0;
   }
   return op  - ({ 0 });

   case TYPE_DIR_LIST:
    array foo;
    foo=Array.map((var-" ")/",", lambda(string var, object node) {
      if (!strlen( var ) || Stdio.file_size( var ) != -2)
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
    array st;
    if (!strlen( var ) || !(st = file_stat( var )) || (st[1] != -2))
    {
      node->error = var + " is not a directory";
      return 0;
    }
    if(var[-1] != '/')
      return var + "/";
    return var;
    
   case TYPE_TEXT_FIELD:
    var -= "\r";
   case TYPE_FONT:
   case TYPE_STRING:
   case TYPE_FILE:
   case TYPE_LOCATION:
    return (var/"\000")[0];
    
   case TYPE_PASSWORD:
    return crypt((var/"\000")[0]);
    
   case TYPE_FLAG:
    return lower_case((var/"\000")[0]) == "yes";
    
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
      return Array.map((var-" ")/",", lambda(string s){ 
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
    loc = CONFIG_URL+o->path(1)[1..]+"?"+bar++;
  
  if(sscanf(loc, "%s/(%*s)%s",l2, loc) == 3)
    loc = l2 + loc;		// Remove the prestate.

//  http://www:22020//Configuration/ -> http://www:22202/Configurations/

  loc = replace(replace(replace(loc, "://", ""), "//", "/"), "", "://");

  return http_redirect(http_decode_string(loc));
}

string configuration_list()
{
  string res="";
  /* FIXME
  object o;
  foreach(roxen->configurations, o)
    res += "<option>Copy of '"+o->name+"'\n";
  */
  return res;
}

string configuration_types()
{
  string res="";
  foreach(get_dir("server_templates"), string c)
  {
    array err;
    if (err = catch {
      if(c[-1]=='e' && c[0]!='#') {
	object o = get_template(c);
	if (o) {
	  res += sprintf("<option value=\"%s\"%s>%s\n",
			 c, (o->selected?" selected":""), o->name);
	}
      }
    }) {
      report_error(sprintf("Error initializing server template \"%s\"\n"
			   "%s\n", c, describe_backtrace(err)));
    }
  }
  return res;
}

string describe_config_modules(array mods)
{
  string res = "This configuration template adds the following modules:<p><ul>";
  if(!mods||!sizeof(mods)) return "This configuration template adds no modules";
  
  foreach(mods, string mod)
  {
    sscanf(mod, "%s#", mod);
    if(!roxen->allmodules)
    {
      werror("CONFIG: Rescanning modules (doc string).\n");
      roxen->rescan_modules();
      werror("CONFIG: Done.\n");
    }
    if(!roxen->allmodules[mod]) res += "<li>The unknown modules '"+mod+"'\n";
    else res += "<li>"+roxen->allmodules[mod][0]+"\n";
  }
  return res+"</ul>";
}

string configuration_docs()
{
  string res="";
  foreach(get_dir("server_templates"), string c)
  {
    perror("c[-1]: %O\n", c[-1]);
    if( c[-1]=='e' )
      res += ("<dt><b>"+get_template(c)->name+"</b>\n"+
	      "<dd>"+get_template(c)->desc+"<br>\n"+
	      describe_config_modules(get_template(c)->modules) + "\n");
  }
  return res;
}

string new_configuration_form()
{
  return (default_head("") + status_row(root) +
	  "<h2>Add a new virtual server</h2>\n"
	  "<table bgcolor=#000000><tr><td >\n"
	  "<table cellpadding=3 cellspacing=1 bgcolor=lightblue><tr><td>\n"
	  "<form>\n"
	  "<tr><td>Server name:</td><td><input name=name size=40,1>"
	  "</td></tr>\n"
	  "<tr><td>Configuration type:</td><td><select name=type>"+
	  configuration_types()+configuration_list()+"</select></tr>"
	  "</td>\n"
	  "<tr><td colspan=2><table><tr><td align=left>"
	  "<input type=submit name=ok value=\" Ok \"></td>"
	  "<td align=right>"
	  "<input type=submit name=no value=\" Cancel \"></td></tr>\n"
	  "</table></td></tr></table></td></tr>\n</table>\n" +
	  "<p>The only thing the type change is the initial "
	  "configuration of the server.\n"
	  "<p>The types are:<dl>\n" + configuration_docs() +
	  /* FIXME
	  "<dt><b>Copy of ...</b>:\n"
	  "<dd>Make an exact copy of the mentioned virtual server.\n"
	  "You should change at least the listen ports.<p>\n"
	  "This can be very useful, since you can make 'template' virtual "
	  "servers (servers without any open ports), that you can copy later "
	  "on.\n"
	  */
	  "</dl>\n</body>\n");
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
     || ((type & MODULE_AUTH)  && (o=conf->auth_module))
     || ((type & MODULE_TYPES) && (o=conf->types_module))
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
  orig = node->config()->enable_module(name+"#"+i);

  if(!orig) return http_string_answer("This module could not be enabled.\n");
    
  module = node->config()->modules[name];
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
  if(node)
  {
    node->folded = 0;
    // Mark the node and all its parents as modified.
    node->change(1);
  }
  return std_redirect(root, id);
}

mixed new_module_copy_copy(object node, object id)
{
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
    werror("CONFIG: Rescanning modules.\n");
    roxen->current_configuration = node->config();
    roxen->rescan_modules();
    roxen->current_configuration = 0;
    werror("CONFIG: Done.\n");
  }
  
  a=roxen->allmodules;
  mods=Array.sort_array(indices(a), lambda(string a, string b, mapping m) { 
    return m[a][0] > m[b][0];
  }, a);
  
  res = ({default_head("Add a module")+"\n\n"+
	  status_row(node)+
//	  display_tabular_header(node)+
	  "<table><tr><td>&nbsp;<td><h2>Select a module to add"
	  " from the list below, click on it's header to add it.</h2>" });
  
  foreach(mods, q)
  {
    if(b = module_nomore(q, a[q][2], node->config()))
    {
      if(b->sname != q)
	res += ({("<p><img alt=\""+a[q][0]+"\" src=\"/auto/module/" + a[q][2] +
		  "/"+ q+"\" height=24 width=500><br><blockquote>" + a[q][1] +
		  "<p><i>A module of the same type is already enabled (" +
		  b->name + "). <a href=\"/(delete)" +
		  node->descend(b->name, 1)->path(1) + "?" + (bar++) +
		  "\">Disable that module</a> if you want this one instead</i>"
		  "\n<p><br><p></blockquote>")});
    } else {
      res += ({"<p><a href=\"/(addmodule)"+node->path(1)+"?"+q+"=1\">"
		 "<img border=0 alt=\""+a[q][0]+"\" src=\"/auto/module/" +
		 a[q][2]+"/"+q+"\" height=24 width=500>"
		 "</a><blockquote><br>"+a[q][1]+"<p><br><p></blockquote>"});
    }
  }
  return res*""+"</table>";
}

mapping new_module(object id, object node)
{
  string varname;
  
  if(!sizeof(id->variables))
    return stores(new_module_form(id, node));
  
  varname=indices(id->variables)[0];
  
  return new_module_copy(node, varname, id);
}

string ot;
object oT;
object get_template(string t)
{
  t-=".pike";
  if(ot==t) return oT; ot=t;
  return (oT = compile_file("server_templates/"+t+".pike")());
}

int check_config_name(string name)
{
  if(strlen(name) && name[-1] == '~') name = "";
  if(search(name, "/")!= -1) return 1;
  
  foreach(roxen->configurations, object c)
    if(lower_case(c->name) == lower_case(name))
      return 1;

  switch(name) {
   case " ": case "\t": case "CVS":
   case "Global Variables": case "global variables": case "Global variables":
    return 1;
  }
  return !strlen(name);
}

int low_enable_configuration(string name, string type)
{
  object node;
  object o, o2, confnode;
  array(string) arr = replace(type,"."," ")/" ";
  object template;

  if(check_config_name(name)) return 0;
  
  if((type = lower_case(arr[0])) == "copy")
  {
    string from;
    mapping tmp;
    if ((sizeof(arr) > 1) &&
	(sscanf(arr[1..]*" ", "%*s'%s'", from) == 2) &&
	(tmp = roxen->copy_configuration(from, name)))
    {
      // FIXME: Should "../logs/" be hard-coded here?
      tmp["spider#0"]->LogFile =
	"../logs/" + roxenp()->short_name(name) + "/Log";
      roxenp()->save_it(name);
      roxen->enable_configuration(name);
    }
  } else
    (template = get_template(type))->enable(roxen->enable_configuration(name));

  confnode = root->descend("Configurations");
  node=confnode->descend(name);
  
  node->describer = describe_configuration;
  node->saver = save_configuration;
  node->data = roxen->configurations[-1];
  node->type = NODE_CONFIGURATION;
  build_configuration(node);
  node->folded=0;
  node->change(1);
  
  if(template && template->post)
    template->post(node);
  
  if(o = node->descend( "Global", 1 )) {
    o->folded = 0;
    if(o2 = o->descend( "Listen ports", 1 )) {
      o2->folded = 0;
      o2->change(1);
    }
  }
  
  if(o = node->descend( "Filesystem", 1 )) {
    o->folded=0;
    if(o = o->descend( "0", 1)) {
      o->folded=0;
      if(o2 = o->descend( "Search path", 1)) {
	o2->folded=0;
	o2->change(1);
      }
      if (o2 = o->descend("Handle the PUT method", 1)) {
	o2->folded = 0;
	o2->change(1);
      }
    }
  }
  return 1;
}

mapping new_configuration(object id)
{
  if(!sizeof(id->variables))
    return stores(new_configuration_form());
  if(id->variables->no)
    return http_redirect(roxen->config_url()+id->not_query[1..]+"?"+bar++);
  
  if(!id->variables->name)
    return stores(default_head("Bad luck")+
		  "<blockquote><h1>No configuration name?</h1>"
		  "Either you entered no name, or your WWW-browser "
		  "failed to include it in the request</blockquote>");
  
  id->variables->name=(replace(id->variables->name,"\000"," ")/" "-({""}))*" ";
  if(!low_enable_configuration(id->variables->name, id->variables->type))
    return stores(default_head("Bad luck") +
		  "<blockquote><h1>Illegal configuration name</h1>"
		  "The name of the configuration must contain characters"
		  " other than space and tab, it should not end with "
		  "~, and it must not be 'CVS', 'Global Variables' or "
		  "'global variables', nor the name of an existing "
		  "configuration, and the character '/' cannot be included</blockquote>");
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

  if(id->variables->nope)
    return std_redirect(root, id);
    
  
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
  
  res = default_head("Welcome to Roxen Challenger");

  res += Stdio.read_bytes("etc/welcome.html");
  if(error && strlen(error))
    res += "<blockquote>\n<p><b>"+error+"</b>";
  
  res += ("<table border=0 bgcolor=black><tr><td><table cellspacing=0 border=0 cellpadding=3 bgcolor=#e0e0ff>"
	  "<tr><td colspan=2><center><h1>Please complete this form.</h1></center>"
	  "</td></tr>"
	  "<form action=\"/(initial)/Globals/\">"
	  "<tr><td align=right>User name</td><td><input name=user type=string></td></tr>\n"
	  "<tr><td align=right>Password</td><td><input name=pass type=password></td></tr>\n"
	  "<tr><td align=right>Again</td><td><input name=pass2 type=password></td></tr>\n"
//   Avoid this trap for people who like to shoot themselves in the foot.
//   /Peter
//	  "IP-pattern <input name=pattern type=string>\n"
	  "<tr><td align=left><input type=submit value=\" Ok \">\n</td>"
	  "<td align=right><input type=submit name=nope value=\" Cancel \"></td></tr>\n"
	  "</form></table></table></blockquote>");
  
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
      PUSH("<a href=\""+links[i]+"\"><img alt=\"_/"+
          nodes[i][0..strlen(nodes[i])-1]+"\\__\" src=\"/auto/unselected/"+
          replace(nodes[i]," ","%20")+"\" border=0></a>");
    else
      PUSH("<a href=\""+links[i]+"\"><b><img alt=\"_/"+
          nodes[i][0..strlen(nodes[i])-1]+"\\__\" src=\"/auto/selected/"+
          replace(nodes[i]," ","%20")+"\" border=0></b></a>");
//PUSH("<br>");
  return res*"";
}

mapping (string:string) selected_nodes =
([
  "Configurations":"/Configurations",
  "Globals":"/Globals",
  "Errors":"/Errors",
  "Actions":"/Actions",
]);

array tabs = ({
  "Configurations",
  "Globals",
  "Errors",
  "Actions",
});

array tab_names = ({
 "Virtual Servers",
 "Global Variables",
 "Event Log",
 "Actions",
});
		

string display_tabular_header(object node)
{
  string p, s;
  
  array links = Array.map(tabs, lambda(string q) {
    return selected_nodes[q]+"?"+(bar++);
  });

  if(node != root)
  {
    s = extract_almost_top(node) - "/";
    selected_nodes[s] = node->path(1);

    links[search(tabs,s)]="/"+s+"/"+"?"+(bar++);
  }
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


object module_font = get_font("base_server/config/font",0,0,0,"left",1.0,1.0);
object button_font = get_font("base_server/config/button_font",0,0,0,"left",1.0,1.0);
mapping(string:object) my_colortable = ([]);

mapping auto_image(string in, object id)
{
  string key, value;
  array trans = ({ (int)("0x"+dR),(int)("0x"+dG),(int)("0x"+dB) });
  mapping r;
  mixed e;
  object i;

  string img_key = "auto/"+replace(in,"/","_")+".gif"-" ";
  
  if(e=file_image(img_key))
    return e;
  
  if(!sscanf(in, "%s/%s", key, value)) key=in;

  switch(key)
  {
   case "module":
     sscanf(value, "%*d/%s", value);
     i = draw_module_header(roxen->allmodules[value][0],
			    roxen->allmodules[value][2],
			    module_font);
     break;
    
   case "button":
     int lm,rm;
     if(sscanf(value, "lm/%s", value)) lm=1;
     if(sscanf(value, "rm/%s", value)) rm=1;
     i=draw_config_button(value,button_font,lm,rm);
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

  if (!i) return 0;

  object ct;

  if (!(ct=my_colortable[key]))
     ct=my_colortable[key]=Image.colortable(i,256,4,4,4);
//		  colortable(4,4,8,
//			     ({0,0,0}),({255,255,0}),16,
//			     ({0,0,0}),({170,170,255}),48,
//			     )
  object o = open("roxen-images/"+img_key,"wct"); 
  e=Image.GIF.encode(i,ct);
  i=0;
  if(o) { o->write(e); o=0; }
#ifdef DEBUG
  else {perror("Cannot open file for "+in+"\n");}
#endif
  return http_string_answer(e,"image/gif");
}


string remove_font(string t, mapping m, string c)
{
  return "<b>"+c+"</b>";
}


int nfolded(object o)
{
  int i;
  if(o = o->down)
    do { i+=!!o->folded; } while(o=o->next);
  return i;
}

int nfoldedr(object o)
{
  object node;
  int i;
  i = o->folded;
  node=o->down;
  while(node)
  {
    i+=nfoldedr(node);
    node=node->next; 
  }
  return i;
}

string dn(object node)
{
  if(!node) return "???";
  string s = sizeof(node->_path)?node->_path[-1]:" ";
  if(((string)((int)s))==s)
    return "Instance "+s;
  switch(s)
  {
   case "Globals":
    return "Global Variables";
   case "Configurations":
    return "Servers";
   case "Errors":
    return "Event Log";
  }
  return s;
}

string describe_node_path(object node)
{
  string q="", res="";
  int cnt;
  foreach(node->path(1)/"/", string p)
  {
    q+=p+"/";
    if(cnt>0)
    {
//      werror("q="+q+"\n");
      res += ("\n<b><a href=\""+q+"?"+bar+++"\">"+
	      dn(find_node(http_decode_string(q[..strlen(q)-2])))+
	      "</a></b> -&gt;\n");
    }
    else
      cnt++;
  }
  return res[0..strlen(res)-8];
}

string status_row(object node)
{
   return ("<table width=\"100%\" border=0 cellpadding=0"
	   " cellspacing=0>\n"
	   "<tr><td valign=bottom align=left><a href=\"$docurl"+
	   node->path(1)+"\">"
	   "<img border=0 src=\"/image/roxen-icon-gray.gif\" alt=\"\"></a>"
	   "</td>\n<td>&nbsp;</td><td  width=100% height=39>"
	   "<table cellpadding=0 cellspacing=0 width=100% border=0>\n"
	   "<tr width=\"100%\">\n"
	   "<td width=\"100%\" align=right valigh=center height=28>"
	   +describe_node_path(node)+"</td>"
	   "</tr><tr width=\"100%\">"
	   "<td bgcolor=\"#003366\" align=right height=12 width=\"100%\">"
	   "<font color=white size=-2>Administration Interface</font>"
	   "</td></tr></table></td>"
	   "\n</tr>\n</table><br>");
}

mapping logged = ([ ]);

void check_login(object id)
{
  if(logged[id->remoteaddr] + 1000 < time()) {
    report_notice("Administrator logged on from " +
		  roxen->blocking_ip_to_host(id->remoteaddr) + ".");
  }
  logged[id->remoteaddr] = time(1);
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

  // Automatically generated image?
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

    // We also need to determine wether this is the full or the
    // lobotomized international version.

    int full_version=0;
    catch {
      if (sizeof(indices(master()->resolv("_Crypto")))) {
	full_version = 1;
      }
    };

    return http_string_answer(default_head("Roxen Challenger")+
			      status_row(root)+
			      display_tabular_header(root)+
			      Stdio.read_bytes(full_version?"etc/config.html":
					 "etc/config.int.html"), "text/html");
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

    case "morevars":   more_mode = 1; save_more_mode(); break;
    case "nomorevars": more_mode = 0; save_more_mode(); break;
      
      // Fold and unfold nodes, this is _very_ simple, once all the
      // supporting code was writte.
    case "fold":     o->folded=1;      break;
    case "unfold":   o->folded=0;      break;

    case "moredocs":   o->moredocs=1;      break;
    case "lessdocs":   o->moredocs=0;      break;

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

     case "unfoldlevel":
      object node;
      node=o->down;
      while(node)
      {
	node->folded=0;
	node = node->next;
      }
      break;

      
      // And now the actual actions..
      
      // Re-read a module from disk
      // This is _not_ as easy as it sounds, since quite a lot of
      // caches and stuff have to be invalidated..
    case "refresh":
    case "reload":
      object mod;
      string name, modname;
      mapping cmod;
      
      mod = module_of(o);
      if(!mod || mod==roxen)
	error("This module cannot be updated.\n");
      name = module_short_name(mod, o->config());
      if(!name)
	error("This module cannot be updated");
      sscanf(name, "%s#%*s", modname);

      if(!(cmod = o->config()->modules[ modname ]))
 	error("This module cannot be updated");
      
      o->save();
      program oldprg = cache_lookup ("modules", modname);
      mapping oldprgs = copy_value (master()->programs);
      cache_remove("modules", modname);

      // Not useful since load_module() also does it.
      // _master->set_inhibit_compile_errors("");
      
      if(!o->config()->load_module(modname))
      {
	mapping rep;
	rep = http_string_answer("The reload of this module failed.\n"
				 "This is (probably) the reason:\n<pre>"
				 + roxen->last_error + "</pre>" );
	// _master->set_inhibit_compile_errors(0);
	return rep;
      }
      program newprg = cache_lookup ("modules", modname);
      // _master->set_inhibit_compile_errors(0);
      object mod;
      if(!o->config()->disable_module(name)) {
	mapping rep;
	rep = http_string_answer("Failed to disable this module.\n"
				 "This is (probably) the reason:\n<pre>"
				 + roxen->last_error + "</pre>" );
	return rep;
      }
      cache_set ("modules", modname, newprg); // Do not compile again in enable_module.
      if(!(mod=o->config()->enable_module(name))) {
	mapping rep;
	rep = http_string_answer("Failed to enable this module.\n"
				 "This is (probably) the reason:\n<pre>"
				 + roxen->last_error + "</pre>" );
	// Recover..
	master()->programs = oldprgs;
	cache_set ("modules", modname, oldprg);
#ifdef MODULE_DEBUG
	perror ("Modules: Trying to re-enable the old module.\n");
#endif
	o->config()->enable_module(name);
	return rep;
      }

      o->clear();
//    roxen->fork_it();
      
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
     PUSH(default_head("Roxen Configuration")+
	  status_row(o));
//     PUSH("<hr noshade>");
       
      switch(o->type)
      {
       case NODE_CONFIGURATION:
	PUSH("<font size=\"+2\">Do you really want to delete the configuration "+
	     o->data->name + ", all its modules and their copies?"
	     "\n\n<p></font>");
	break;
	
       case NODE_MODULE_MASTER_COPY:
       case NODE_MODULE:
	PUSH("<font size=\"+2\">Do you really want to delete the module "+
	     o->data->name + ", and its copies?\n\n<p></font>");
	break;
	
       case NODE_MODULE_COPY_VARIABLES:
	
       case NODE_MODULE_COPY:
	PUSH("<font size=\"+2\">Do you really want to delete this copy "
	     " of the module "+ o->up->data->name + "?\n\n<p></font>");
	break;
	
       case NODE_CONFIGURATIONS:
	return stores("You don't want to do that...\n");
      }
      PUSH("<blockquote><font size=\"+2\"><i>This action cannot be"
	   " undone.\n\n<p></font>"+ TABLEP("<table>", "")+
	   "<tr><td><form action=\""+ o->path(1)+"\">"
	   "<input type=submit value=\"No, I do not want to delete it\"> "
	   "</form></td><td><form action=\"/(really_delete)"+ o->path(1)+
	   "\"><input type=submit value=\"Go ahead\"></form></td></tr> "
	   "</table></blockquote>");
      
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
	  Array.map(values(roxen->configurations[i]->ports_open), destruct);
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
	
	name = module_short_name(o->data, o->config());
	o->config()->disable_module(name);
	// Remove the suitable part of the configuration file.
	roxen->remove(name, o->config());
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
	    o=n->up; 
	    
	    n->change(-n->changed);
	    n->dest();
	    build_configuration(o);
	    return std_redirect(o, 0); 
	  } else
	    o = n;
	}
	break;
	
       case NODE_MODULE_MASTER_COPY:
       case NODE_MODULE:
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
	      o->config()->disable_module(name+"#"+a[i]);
	      roxen->remove(name+"#"+a[i], o->config());
	    }
	  } else if(o->data->master) {
	    name=o->config()->otomod[o->data->enabled];
	  } 
	} else if(o->data->enabled) {
	  name=o->config()->otomod[o->data->enabled];
	  o->config()->disable_module(name+"#0");
	  roxen->remove(name+"#0", o->config());
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


       // When a port has been changed the admin are prompted to
       // change the server URL. This is where we come when we are
       // done.
       
     case "modify_server_url":

       string srv, url;
       object thenode;
       foreach(indices(id->variables), string var)
       {
	 if(sscanf(var, "%s->own", srv)) {
	   url = id->variables[srv] == "own" ?
	     id->variables[var] : id->variables[srv];
	   if(srv == "Global Variables")
	     thenode = find_node("/Globals/Configuration interface/URL");
	   else
	     thenode = find_node("/Configurations/"+srv+
				 "/Global/Server URL");
	   if(thenode) {
	     thenode->data[VAR_VALUE] = url;
	     thenode->change(1);
	     thenode->up->save();
	   } 

	 }
       }
       id->referer = ({ CONFIG_URL + o->path(1) });
      break;
      // Save changes done to the node 'o'. Currently 'o' is the root
      // node most of the time, thus saving _everything_.
     case "save":
      mapping cf;
      if(cf = save_it(id, o))
	return cf;
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
    case "newmodule": // For backward compatibility
    case "addmodule":
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

  check_login(id);
  
  PUSH(default_head("Roxen server configuration"));
//  PUSH("<table><tr><td>&nbsp;<td>"
  PUSH("<dl>\n");
  PUSH("\n"+status_row(o)+"\n"+display_tabular_header( o )+"\n");
  PUSH("<p>");
  if(o->up != root && o->up)
    PUSH("<a href=\""+ o->up->path(1)+"?"+(bar++)+"\">"
	 "<img src=/auto/back alt=\"[Up]\" align=left hspace=0 border=0></a>\n");

  if(i=o->folded) o->folded=0;
  mixed tmp = o->describe(1,id);
  if(mappingp(tmp)) return tmp;
  if(!id->supports->font)
    tmp = parse_html(tmp, ([]),(["font":remove_font, ]));
  PUSH("<dl><dt>");
  PUSH(tmp);
  PUSH("</dl>");
  o->folded=i;
  
  PUSH("<p><br clear=all>&nbsp;\n");

  int lm=1;
  array(mixed) buttons = ({});
  
  if(o->type == NODE_CONFIGURATIONS)
    BUTTON(newconfig, "New virtual server", left);
  
  if(o->type == NODE_CONFIGURATION)
    BUTTON(addmodule, "Add module", left);
  
  if(o->type == NODE_MODULE)
  {
    BUTTON(delete, "Delete module", left);
    if(o->data->copies)
      BUTTON(newmodulecopy, "Copy module", left);
  }

  i=0;
  if(o->type == NODE_MODULE_MASTER_COPY || o->type == NODE_MODULE_COPY 
     || o->type == NODE_MODULE_COPY_VARIABLES)
  {
    BUTTON(delete, "Delete module", left);
    if(more_mode)
      BUTTON(refresh, "Reload module", left);
  }
  
  if(o->type == NODE_CONFIGURATION)
    BUTTON(delete,"Delete this server", left);

  if(nunfolded(o))
    BUTTON(foldall, "Fold all",left);
  if(o->changed)
    BUTTON(unfoldmodified, "Unfold modified", left);

  if(nfolded(o))
    BUTTON(unfoldlevel, "Unfold level", left);
//  else if(nfoldedr(o))
//    BUTTON(unfoldall, "Unfold all", left);

  PUSH_BUTTONS(1);

  if(!more_mode)
    BUTTON(morevars, "More options", left);
  else
    BUTTON(nomorevars, "Fewer options", left);
    
  if((o->changed||root->changed))
    BUTTON(save, "Save", left);
//  BUTTON(restart, "Restart", left);
//  BUTTON(shutdown,"Shutdown", left);

  PUSH_BUTTONS(0);

//  PUSH("<br clear=all>");
//  PUSH("<p align=right><font size=-1 color=blue><a href=\"$docurl\"><font color=blue>"+roxen->real_version +"</font></a></font></p>");
//  PUSH("</table>");
  PUSH("</body>\n");
  return stores(res*"");
}
