/* $Id: low_describers.pike,v 1.12 1997/08/19 07:03:28 per Exp $ */
// These do _not_ use any nodes, instead, they are called from the node
// describers (which are called from the nodes)
object this = this_object();

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
   case TYPE_MODULE:
    return "(Module)";

   case TYPE_CUSTOM:
   case TYPE_TEXT_FIELD:
    return "";

   case TYPE_FONT:
    return "(Existing font)";

   case TYPE_STRING:
    return "";

   case TYPE_LOCATION:
    return "(Location in the virtual filesystem)";

   case TYPE_FILE:
    return "(File name)";

   case TYPE_DIR:
    return "(Directory name of existing directory)";

   case TYPE_FLOAT:
    return "(Floating point decimal number)";

   case TYPE_INT:
    return "(Integer number)";

   case TYPE_STRING_LIST:
    if(!flag)
      return "(Commaseparated list of strings)";
    break;

   case TYPE_DIR_LIST:
    if(!flag)
      return "(Commaseparated list of directories)";
    break;

   case TYPE_PASSWORD:
    return "(A password, characters will not be echoed)";

   case TYPE_INT_LIST:
    if(!flag)
      return "(Commaseparated list of integers)";
    break;


   case TYPE_PORTS:
    if(!flag)
      return
	("This is a list of ports. "
	 "<p> The first field for each port is the actual port number, the "
	 "second is the protocol used and the third is the interface to bind "
	 "to.");
    break;

   case TYPE_FLAG:
    break;

   case TYPE_COLOR:
    if(!flag)
      return 
	("(A colon separated color specification with red:green:blue where "
	 "red, green and blue are numbers ranging from 0 to 255. 0:0:0 "
	 "is black, 255:0:0 red and 255:255:255 white)");
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
    return "None";

  if((name=m->query("_name")) && strlen(name))
    ;
  else if(m->query_name) 
    name = m->query_name();
  else 
    name = m->register_module()[1];
  
  return strip_html(name);
}

string describe_variable_as_text(array var, int|void verbose)
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
     return sizeof(var[VAR_VALUE])+ " port"+ 
       (sizeof(var[VAR_VALUE]) == 1 ? "": "s")+" configured";

   case TYPE_TEXT_FIELD:
    array f;
    f=var[VAR_VALUE]/"\n" - ({ "" });
    if(!sizeof(f)) return "Empty";
    if(verbose)
      return "<pre>"+replace(var[VAR_VALUE], ({ "<", ">", "&" }), 
		     ({ "&lt;", "&gt;", "&amp;" }))+"</pre>";
    return sizeof(f) + " lines";
    
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
      return (string)var[VAR_VALUE];
    if(arrayp(var[VAR_VALUE]))
      return map(var[VAR_VALUE],lambda(mixed a){
	return replace((string)a,({"<",">","&"}),({"&lt;","&gt;","&amp;"}));
      }) * ", ";
    else 
      return "";
    
   case TYPE_FLAG:
    if(var[VAR_VALUE])
      return "Yes";
    return "No";
    
   case TYPE_COLOR:
    return "Color";
  }
  return "Unknown";
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
  string ifconfig = find_one("/usr/sbin/ifconfig", "/etc/ifconfig",
                             "/sbin/ifconfig", "/bin/ifconfig",
                             "/usr/bin/ifconfig");  
  string aliasesfile;
 
  ip_number_list = ({ "ANY",  });
 
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
        ip_number_list |= ({ to_hostname(data) });
      }
    }
  }

  // Most others
  string ips = popen(ifconfig+" -a 2>/dev/null");
  if(!ips || !strlen(ips))
    ; // No output from the 'ifconfig' call.
  else   
  {
    string ip;
    while(sscanf(ips, "%*sinet %[^ ]%s", ip, ips)>2)
    {
      while(sscanf(ip, "%*s:%s", ip));
      // Only add it if it was not there before
      ip_number_list |= ({ to_hostname(ip) });
    }
  }
    
  sort(ip_number_list);
  if(sizeof(ip_number_list) == 2)
    ip_number_list = 0;
}
 

string all_ip_numbers_as_selection(int id, string sel)
{
  if(ip_number_list && sizeof(ip_number_list))
    return ("<select name=ip_number_"+id+">\n"
	    + (map(ip_number_list, lambda(string s, string q) {
  	        return "  <option"+(q==s?" selected":"")+">"+s+"\n";
   	       }, sel)*"")
	    + "</select>\nOther IP-number: <input type=string name=other_"
            + id+" value=\""+sel+"\">\n");
  else
    return "<input type=string name=ip_number_"+id+" value='"+sel+"'>\n";
}

array protocols()
{
  return map(filter(get_dir("protocols"), lambda(string s) {
    return ((search(s,".pike") == search(s,".")) &&
	    (search(s,".")!=-1) && s[-1]!="~");
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
  return ("<input type=reset value=\"Reset to last entered\"><br>"
	  "\n<font color=red><input type=submit name=delete_"+id+
	  " value=\"Delete this port\"></font>");
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
  if(lower_case(port[1])=="ssl3")
  {
    string cf, kf;
    sscanf(port[3], "%*scert-file %s\n", cf);
    sscanf(port[3], "%*skey-file %s\n", kf);
    res += ("<tr><td colspan=3>"
	    "<table width=100% cellspacing=0  border=0 bgcolor=#f0f0ff>\n"
	    "<tr width=100%><td colspan=2 width=100%><b>SSL Options</b></td></tr>\n");
    res += ("<tr><td>Certificate file:</td> <td><input size=30,1 "
	    "name=cert_"+id+" value=\""+html_encode_string(cf||"")+
	    "\"></td></tr>\n"
	    "<tr><td>Key file: (OPTIONAL)</td><td><input size=30,1 "
	    "name=key_"+id+"  value=\""+html_encode_string(kf||"")+
	    "\"></td></tr>\n");
    res += "</table></td></tr>\n";
  }
  return res +
    ("</table></td><td height=100% valign=top>\n"
     "<table bgcolor=#e0e0ff height=100% cellspacing=0 cellpadding=0 "
     "border=0>\n"+
     "<tr height=100%><td height=100%>"+port_buttons(port,id)+"</td></tr>\n"
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
    "<table width=100% bgcolor=#f0f0ff border=0 cellpadding=0 cellspacing=0><tr><td>\n"+
    (sizeof(from)?"<input type=submit name=ok value=\"Use these values\">":"")+
    "<input type=submit name=new_port value=\"Configure a new port\">"
    "</tr></table></td></tr>";
  return res+"</table>";
}

int module_wanted(mapping mod_info, object module, function check)
{
  if(!check) return 1;
  return check(module, mod_info);
}

string describe_variable_low(mixed *var, mixed path, int really_short,
			     string|void name)
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
		    ?" selected":"")+">" + name_of_module(o)+ "</option>" });
    if(var[VAR_TYPE] == TYPE_MODULE)
      res = ("<select name="+path+">\n"+
	     rs*"\n"+"\n</select>\n<input type=submit value=Ok>");
    else
      res = ("<select multiple name="+path+">\n"+
	     rs*"\n"+"\n</select>\n<input type=submit value=Ok>");
    break;

   case TYPE_PORTS:
    res = encode_ports(var[VAR_VALUE]);
    break;

    
   case TYPE_TEXT_FIELD:
    res="<textarea name="+path+" cols=50 rows=10>"
      + html_encode_string(var[VAR_VALUE])
      + "</textarea><br><input type=submit value=Ok>\n";
    break;
    
   case TYPE_PASSWORD:
    res="<input name=\""+path+"\" type=password size=30,1><input type=submit value=Ok>";
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
    res += "</select><input type=submit value=Ok>";
    break;

   case TYPE_STRING:
    res=input(path, var[VAR_VALUE], 30)+"<input type=submit value=Ok>";
    break;
    
   case TYPE_LOCATION:
    res=input(path, var[VAR_VALUE], 30)+"<input type=submit value=Ok>";
    break;
    
   case TYPE_FILE:
    res=input(path, var[VAR_VALUE], 30)+"<input type=submit value=Ok>";
    break;
    
   case TYPE_DIR:
    res=input(path, var[VAR_VALUE], 30)+"<input type=submit value=Ok>";
    break;
    
   case TYPE_INT:
    res=input(path, var[VAR_VALUE], 10)+"<input type=submit value=Ok>";
    break;
    
   case TYPE_FLOAT:
    res=input(path, sprintf("%.4f", var[VAR_VALUE]), 10)
      +"<input type=submit value=Ok>";
    break;
    
   case TYPE_DIR_LIST:
   case TYPE_STRING_LIST:
   case TYPE_INT_LIST:
    if(var[VAR_MISC])
    {
      string tmp;
      mixed *misc;
      int i;
      
      tmp="<select name="+path+">  ";
      misc=var[VAR_MISC];
      
      for(i=0; i<sizeof(misc); i++)
      {
	if(misc[i]==var[VAR_VALUE])
	  tmp+="  <option selected> "+misc[i]+" ";
 	else
	  tmp+="  <option> "+misc[i]+"  ";
      }
      res=tmp+"</select><input type=submit value=Ok>";
    } else {
      
      if(!arrayp(var[VAR_VALUE]))
	var[VAR_VALUE]=({});
      
      res="<input name="+path+" size=30,1 value=\""+
	(map(var[VAR_VALUE], lambda(mixed s){ return ""+s; })*", ")+
	  "\">"+"<input type=submit value=Ok>";
    }
    break;
    
   case TYPE_FLAG:
    res = "<select name="+path+"> ";
    if(var[VAR_VALUE])
      res +=  "<option selected>Yes<option>No";
    else
      res +=  "<option>Yes<option selected>No";
    res +=  "</select><input type=submit value=Ok>";
    break;
    
   case TYPE_COLOR:
    if (!intp( var[ VAR_VALUE ] ))
      var[ VAR_VALUE ] = 0;	// Black.. maybe not the best default color...
    res = "<input name=" + path + " size=12 value= "
          + ((var[ VAR_VALUE ] >> 16) & 255)
	  + ":" + ((var[ VAR_VALUE ] >> 8) & 255)
	  + ":" + (var[ VAR_VALUE ] & 255) 
	  + ">"+"<input type=submit value=Ok>";
  }
  if(really_short) return res;

  /* Now in res: <input ...> */
  
  res = (name||var[VAR_NAME]) + "<br><dd>" + res;
  if(roxen->QUERY(DOC))
    return res + "<br>" + "<p>" + var[VAR_DOC_STR] + "<p>" 
      + describe_type(var[VAR_TYPE], var[VAR_MISC]) + "<p>";
  return res;
}

string describe_module_type(int t)
{
  string res;
  int w;
  res="";
  
  if(t & MODULE_MAIN_PARSER)
    return "";
  
  if(t & MODULE_TYPES)
    return "This is the extension to contenttype mapping module";
  
  if(t & MODULE_DIRECTORIES)
    return "This is the directory parsing module";
  
  if((t & MODULE_EXTENSION) || (t & MODULE_FILE_EXTENSION))
  {
    res += "This is an extension module. ";
    w++;
  }
  
  if(t & MODULE_AUTH)
  {
    if(!w)
      res += "This is the authentification module. ";
    else
      res += "It is also the authentification module. ";
    w++;
  }
  
  if(t & MODULE_LOCATION)
  {
    switch(w)
    {
     case 0:
      res += "This is a location module. ";
      break;
     case 1:
      res += "It is also a location module. ";
      break;
     case 2:
      res += "And a location module. ";
    }
    w++;
  }
  
  if(t & MODULE_URL)
  {
    if(w)
      res += "It will also remap URL-s (internal redirects). ";
    else
      res += "This module remap URL-s (internal redirects). ";
  }  
  
  if(t & MODULE_FIRST)
  {
    if(w&1)
      res += ("And since it is also a module that will be run before all "
	      + "other modules, except other modules of the same type. ");
    else if(w)
      res += ("It is also a module that will be run before all "
	      + "other modules, except other modules of the same type. ");
    else
      res += ("This is a module that will be run before all "
	      +"other modules, except other modules of the same type. ");
    w++;
  }
  
  if(t & MODULE_LAST)
  {
    if(w)
      res += ("And since it is also a last resort module,"
	      +" it will be called if everything else fails. ");
    else
      res += ("This is a last resort module, which will only be called if "+
	      "everything else fails. ");
    w++;
  }
  
  if(t & MODULE_PARSER)
  {
    if(w)
      res += ("It also handles a few extensions to the HTML language. ");
    else
      res += ("This is a parse module, which adds one or more tags to "+
	      "the HTML language. ");
    w++;
  }
  
  if(!w) 
    return "";
  
  return res;
}








