/* $Id: low_describers.pike,v 1.29 1999/05/14 00:28:00 neotron Exp $ */
// These do _not_ use any nodes, instead, they are called from the node
// describers (which are called from the nodes)
object this = this_object();
#define LOCALE	LOW_LOCALE->config_interface

#include <roxen.h>
#include <module.h>
inherit "html";
inherit "roxenlib";

import String;
import Array;
import Stdio;

string describe_type(int type, mixed flag)
{
  switch(type)
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

string encode_ports(array from);

string strip_html(string from)
{
  string a, res="";
  foreach(from/"<", a)
  {
    sscanf(a, "%*s>%s", a);
    res+=a;
  }
  return res;
}

string name_of_module( object m )
{
  string name;
  if(!objectp(m))
    return "?";

  if((name=m->query("_name")) && strlen(name))
    ;
  else if(m->query_name) 
    name = m->query_name();
  else 
    name = m->register_module()[1];
  
  return strip_html(name);
}

string describe_variable_as_text(array var, int verbose, object node)
{
  switch(var[VAR_TYPE])
  {
    object m;
    string name;
    array tmp;
   case TYPE_CUSTOM:
    return var[VAR_MISC][0]( var, verbose );

   case TYPE_FONT:
    return var[VAR_VALUE];
    
   case TYPE_MODULE_LIST:
    tmp=({});
    foreach(var[VAR_VALUE], m)
      tmp += ({ name_of_module( m ) });
    return Simulate.implode_nicely(tmp);
   case TYPE_MODULE:
    name = name_of_module( var[VAR_VALUE] );
    return replace(name, ({ "<", ">", "&" }), ({ "&lt;", "&gt;", "&amp;" }));

   case TYPE_PORTS:
     return LOCALE->ports_configured(sizeof(var[VAR_VALUE]));

   case TYPE_TEXT_FIELD:
    array f;
    f=(var[VAR_VALUE]||"")/"\n" - ({ "" });
    if(!sizeof(f)) return "Empty";
    if(verbose)
      return "<pre>"+replace(var[VAR_VALUE], ({ "<", ">", "&" }), 
		     ({ "&lt;", "&gt;", "&amp;" }))+"</pre>";
    return LOCALE->lines(sizeof(f));
    
   case TYPE_PASSWORD:
    return "****";
    
   case TYPE_STRING:
   case TYPE_LOCATION:
   case TYPE_FILE:
   case TYPE_DIR:
    string s;
    if(!var[VAR_VALUE])
      return "UNDEF";
    if(!stringp(var[VAR_VALUE]))
      error(sprintf("Invalid value for variable: %O!\n", var[VAR_VALUE]));
    s = replace(var[VAR_VALUE],({"<",">","&"}),({"&lt;","&gt;","&amp;"}));
    if(!stringp(s))
      error("Bug in replace!\n");
    return s;
    
   case TYPE_INT:
    return (string)var[VAR_VALUE];
    
   case TYPE_FLOAT:
    return sprintf("%.4f", var[VAR_VALUE]);
    
   case TYPE_DIR_LIST:
   case TYPE_STRING_LIST:
   case TYPE_INT_LIST:
    if(var[VAR_MISC])
    {
      object module = node->module_object();
      if(LOW_LOCALE->module_doc_string(module, var[VAR_SHORTNAME], 2))
	return LOW_LOCALE->
	  module_doc_string(module, var[VAR_SHORTNAME], 2)[var[VAR_VALUE]];
      return (string)var[VAR_VALUE];
    }
    if(arrayp(var[VAR_VALUE]))
      return map(var[VAR_VALUE],lambda(mixed a){
	return replace((string)a,({"<",">","&"}),({"&lt;","&gt;","&amp;"}));
      }) * ", ";
    else 
      return "";
    
   case TYPE_FLAG:
    if(var[VAR_VALUE])
      return LOW_LOCALE->yes;
    return LOW_LOCALE->no;
    
   case TYPE_COLOR:
    return LOCALE->color();
  }
  return LOCALE->unkown_variable_type();
}

array ip_number_list;

string find_one(string ... of)
{
  string s;
  foreach(of, s) if(file_stat( s )) return s;
}

#define to_hostname roxen->blocking_ip_to_host

void init_ip_list()
{
#ifdef __NT__
  ip_number_list = ({ "ANY" });
#else
  string ifconfig = find_one("/usr/sbin/ifconfig", "/etc/ifconfig",
                             "/sbin/ifconfig", "/bin/ifconfig",
                             "/usr/bin/ifconfig");  
  string aliasesfile;
 
  array new_ip_number_list = ({ "ANY",  });
 
  if(!ifconfig) ifconfig = "ifconfig";

  // LINUX
  if(aliasesfile = find_one("/proc/net/aliases"))
  {
    string data = Stdio.read_bytes(aliasesfile);
    foreach((data/"\n")[1..], data) // Remove the header line..
    {
      if(strlen(data)) 
      {
        // Get the last entry on the line.
        data = (replace(data, "\t", " ")/" "-({""}))[-1];
        new_ip_number_list |= ({ to_hostname(data) });
      }
    }
  }

  // Most others
  string ips;
  catch { // AmigaOS gives error when doing popen (for now)
    ips = popen(ifconfig+" -a 2>/dev/null");
  };
  if(!ips || !strlen(ips))
    ; // No output from the 'ifconfig' call.
  else   
  {
    string ip;
    while(sscanf(ips, "%*sinet %[^ ]%s", ip, ips)>2)
    {
      while(sscanf(ip, "%*s:%s", ip));
      // Only add it if it was not there before
      new_ip_number_list |= ({ to_hostname(ip) });
    }
  }
    
  sort(new_ip_number_list);
  if(sizeof(new_ip_number_list) == 2)
    ip_number_list = 0;
  else
    ip_number_list = new_ip_number_list;
#endif
}
 

string all_ip_numbers_as_selection(int id, string sel)
{
  if(ip_number_list && sizeof(ip_number_list)) {
    string extra = "";
    int i;
    for (i = 0; i < sizeof(ip_number_list); i++) {
      if (ip_number_list[i] == sel)
	break;
    }
    if (i == sizeof(ip_number_list))
      extra = "  <option selected>"+sel+"\n";

    return ("<select name=ip_number_"+id+">\n" +
	    extra +
	    (map(ip_number_list,
		 lambda(string s, string q) {
		   return "  <option"+(q==s?" selected":"")+">"+s+"\n";
		 }, sel)*"") +
	    "</select>\n"+
	    LOCALE->other_ip_nummer()
	    +" <input type=string name=other_" +
            id + " value=\""+sel+"\">\n");
  } else {
    return "<input type=string name=ip_number_"+id+" value='"+sel+"'>\n";
  }
}

array protocols()
{
  array(string) files = get_dir("protocols");
  if (!files || !sizeof(files)) {
    error("No protocols available!\n");
  }
  return map(filter(files, lambda(string s) {
    return ((search(s,".pike") == search(s,".")) &&
	    (search(s,".")!=-1) && search(s,"#")==-1 && s[-1] != '~');
  }), lambda(string s) { return (s/".")[0]; });
}

string all_protocols_as_selection(int id, string sel)
{
  return ("<select name=protocol_"+id+">\n"
	  + (map(protocols(), lambda(string s, string q) {
	    return "  <option"+(q==s?" selected":"")+">"+s+"\n";
	  }, sel)*"")
	  + "</select>\n");
}

string port_buttons(array port, int id)
{
  return LOCALE->port_buttons(port, id);
}

string encode_one_port(array port, int id)
{
  string res;
  /* PortNo, Protocol, IP, options */
  res= "\n<tr height=100%><td>\n"
    "<table cellspacing=0 border=0 bgcolor=#e0e0ff>\n"
    "<tr>\n  <td><input size=5,1 name=port_"+id+" value="+
    port[0]+"></td>\n    <td>"+all_protocols_as_selection(id, port[1])+
    "</td>\n    <td>"+all_ip_numbers_as_selection(id, port[2])+"</td>\n"
    "</tr>\n";
  switch(lower_case(port[1]))
  {
   case "ssl3":
   case "https":
    string cf, kf;
    sscanf(port[3], "%*scert-file %s\n", cf);
    sscanf(port[3], "%*skey-file %s\n", kf);
    res += ("<tr><td colspan=3>"
	    "<table width=100% cellspacing=0  border=0 bgcolor=#f0f0ff>\n"
	    "<tr width=100%><td colspan=2 width=100%><b>"+
	    LOCALE->ssl_options()+"</b></td></tr>\n");
    res += LOCALE->ssl_variables(cf,kf,id);
    //    res += "</table></td></tr>\n";
    break;
  } 
  return res +
    ("</table></td><td height=100% valign=top>\n"
     "<table bgcolor=#e0e0ff height=100% cellspacing=0 cellpadding=0 "
     "border=0>\n"+
     "<tr height=100%><td height=100%>&nbsp;"+
     port_buttons(port,id)+"</td></tr>\n"
     "</table></td></tr>");
}

string encode_ports(array from)
{
  string res = "<table border=0 cellpadding=1 bgcolor=black cellspacing=1>\n";
  int i;
  if(ip_number_list)
  {
    remove_call_out(init_ip_list);
    call_out(init_ip_list, 10);
  } else {
    init_ip_list();
    call_out(init_ip_list, 1);
  }

  for(i=0; i<sizeof(from); i++)
  {
    if(arrayp(from[i]))
    {
      if(sizeof(from[i]) == 3)
	from[i] += ({ "" });
      if(sizeof(from[i]) == 4)
	res += encode_one_port( from[i], i );
    }
  }
  res += "<tr><td colspan=4>\n"
    "<table width=100% bgcolor=#f0f0ff border=0 cellpadding=0 cellspacing=0>"
    "<tr><td>\n"+LOCALE->port_top_buttons(from)+"</tr></table></td></tr>";
  return res+"</table>";
}

int module_wanted(mapping mod_info, object module, function check)
{
  if(!check) return 1;
  return check(module, mod_info);
}

string describe_variable_low(mixed *var, mixed path, string name, object node)
{
  string res;
  
  switch(var[VAR_TYPE])
  {
   case TYPE_CUSTOM:
    res=var[VAR_MISC][1]( var, path );
    break;

   case TYPE_MODULE:
   case TYPE_MODULE_LIST:
    array wanted = ({});
    mapping mod;
    object o;
    array (string) rs = ({});

    foreach(values(roxen->current_configuration->modules), mod)
    {
      if(mod->copies)
      {
	foreach(values(mod->copies), o)
	  if(module_wanted(mod, o, var[VAR_MISC]))
	    wanted += ({ o });
      } else 
	if(mod->enabled && module_wanted(mod, mod->enabled, var[VAR_MISC]))
	  wanted += ({ mod->master });
    }
    foreach(wanted, o)
      rs += ({ "<option value=\"" + this->module_short_name( o ) + "\""
		 + ((arrayp(var[VAR_VALUE])?
		     search(var[VAR_VALUE], o)!=-1:
		     var[VAR_VALUE]==o)
		    ?" selected":"")+">" + html_encode_string(name_of_module(o))+
	       "</option>" });
    if(var[VAR_TYPE] == TYPE_MODULE)
      res = ("<select name="+path+">\n"+
	     rs*"\n"+"\n</select>\n<input type=submit value="+
	     LOW_LOCALE->ok+">");
    else
      res = ("<select multiple name="+path+">\n"+
	     rs*"\n"+"\n</select>\n<input type=submit value="+
	     LOW_LOCALE->ok+">");
    break;

   case TYPE_PORTS:
    res = encode_ports(var[VAR_VALUE]);
    break;

    
   case TYPE_TEXT_FIELD:
    res="<textarea name="+path+" cols=50 rows=10>"
      + html_encode_string(var[VAR_VALUE]||"")
      + "</textarea><br><input type=submit value="+LOW_LOCALE->ok+">\n";
    break;
    
   case TYPE_PASSWORD:
    res="<input name=\""+path+"\" type=password size=30,1>"
      "<input type=submit value="+LOW_LOCALE->ok+">";
    break;
    

   case TYPE_FONT:
    array select_from;
    catch {
      select_from=roxen->available_fonts(0);
    };
    if(!select_from) 
      break;
    sort(select_from);
    
    res="<select name="+path+">  ";
    array a;
    foreach(select_from, string f)
    {
      f = replace(f, "_", " ");
      res += "<option"+(f == var[VAR_VALUE]?" selected>":">")+f+"\n";
    }
    res += "</select><input type=submit value="+LOW_LOCALE->ok+">";
    break;

   case TYPE_STRING:
    res=input(path, var[VAR_VALUE], 30)+
      "<input type=submit value="+LOW_LOCALE->ok+">";
    break;
    
   case TYPE_LOCATION:
    res=input(path, var[VAR_VALUE], 30)+
      "<input type=submit value="+LOW_LOCALE->ok+">";
    break;
    
   case TYPE_FILE:
    res=input(path, var[VAR_VALUE], 30)+
      "<input type=submit value="+LOW_LOCALE->ok+">";
    break;
    
   case TYPE_DIR:
    res=input(path, var[VAR_VALUE], 30)+
      "<input type=submit value="+LOW_LOCALE->ok+">";
    break;
    
   case TYPE_INT:
    res=input(path, var[VAR_VALUE], 10)+
      "<input type=submit value="+LOW_LOCALE->ok+">";
    break;
    
   case TYPE_FLOAT:
    res=input(path, sprintf("%.4f", var[VAR_VALUE]), 10)
      +"<input type=submit value="+LOW_LOCALE->ok+">";
    break;
    
   case TYPE_DIR_LIST:
   case TYPE_STRING_LIST:
   case TYPE_INT_LIST:
    if(var[VAR_MISC])
    {
      string tmp;
      mixed *misc;
      mapping translate;
      int i;
      
      tmp="<select name="+path+">  ";
      misc=var[VAR_MISC];
      translate = LOW_LOCALE->module_doc_string(node->module_object(), 
						var[VAR_SHORTNAME],2);
      if(!translate)
	translate = mkmapping(misc,misc);
      for(i=0; i<sizeof(misc); i++)
      {
	if(misc[i]==var[VAR_VALUE])
	  tmp+=("  <option value=\""+
		replace(misc[i],"\"","&quote;")
		+ "\" selected> "+
		translate[misc[i]]+" ");
 	else
	  tmp+=("  <option value=\""+
		replace(misc[i],"\"","&quote;")+ "\"> "+
		translate[misc[i]]+" ");
      }
      res=tmp+"</select><input type=submit value="+LOW_LOCALE->ok+">";
    } else {
      
      if(!arrayp(var[VAR_VALUE]))
	var[VAR_VALUE]=({});
      
      res="<input name="+path+" size=60,1 value=\""+
	(map(var[VAR_VALUE], lambda(mixed s){ return ""+s; })*", ")+
	  "\">"+"<input type=submit value="+LOW_LOCALE->ok+">";
    }
    break;
    
   case TYPE_FLAG:
    res = "<select name="+path+"> ";
    if(var[VAR_VALUE])
      res +=  ("<option value=Yes selected>"+LOW_LOCALE->yes+
	       "<option value=No>"+LOW_LOCALE->no);
    else
      res +=  ("<option value=Yes>"+LOW_LOCALE->yes+
	       "<option value=No selected>"+LOW_LOCALE->no);
    res +=  "</select><input type=submit value="+LOW_LOCALE->ok+">";
    break;
    
   case TYPE_COLOR:
    if (!intp( var[ VAR_VALUE ] ))
      var[ VAR_VALUE ] = 0;	// Black.. maybe not the best default color...
    res = "<input name=" + path + " size=12 value= "
          + ((var[ VAR_VALUE ] >> 16) & 255)
	  + ":" + ((var[ VAR_VALUE ] >> 8) & 255)
	  + ":" + (var[ VAR_VALUE ] & 255) 
	  + ">"+"<input type=submit value="+LOW_LOCALE->ok+">";
  }
  /* Now in res: <input ...> */

  object module = node->module_object();
  
  res = (name||
	 LOW_LOCALE->module_doc_string(module,var[VAR_SHORTNAME],0)) 
    + "<br><dd>" + res;
  if(roxen->QUERY(DOC))
    return res + "<br>" + "<p>" + 
      LOW_LOCALE->module_doc_string( module, var[VAR_SHORTNAME], 1 )
      + "<p>" 
      + describe_type(var[VAR_TYPE], var[VAR_MISC]) + "<p>";
  return res;
}
