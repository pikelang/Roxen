/*
 * $Id: forms_mailer.pike,v 1.4 1998/09/28 06:08:20 js Exp $
 *
 * AutoSite Forms Mailer module
 *
 * Johan Schön, September 1998
 * Partly based on code made by <mirar@mirar.org>
 */

constant cvs_version = "$Id: forms_mailer.pike,v 1.4 1998/09/28 06:08:20 js Exp $";

#include <module.h>
#include <roxen.h>

inherit "module";
inherit "roxenlib";


array register_module()
{
  return ({ MODULE_PARSER, "AutoSite Forms Mailer module",
	    "",0,1 });
}

void create(object conf)
{
}

string fill_in_input(string tag,mapping args,mapping vars)
{
  switch (args->type)
  {
   case "checkbox":
    if (vars[args->name])
      return "[x]";
    else
      return "[ ]";
    
   case "radio":
    if (vars[args->name]==args->value)
      return "(x)";
    else
      return "( )";
    
   case "select":
    return "··indent··"+(vars[args->name]/"\000")*"·\\n·"+"··/indent··";

   case "string":
    return vars[args->name];
  }
  return "<???>";
}

string fill_in_textarea(string tag,mapping args,string cont,mapping vars)
{
  cont=vars[args->name]||cont;
  return "··indent··"+replace(cont,"\n","·\\n·")+"··/indent··";
}

string empty(string tag,mapping args,string cont)
{
  return "";
}
string fill_in_form(string data,mapping vars)
{
  data = parse_html(data,
		    (["input":fill_in_input,
		      "table":empty,"/table":empty,
		      "tr":empty,"/tr":empty,
		      "td":empty,"/td":empty,
		      "font":empty,"/font":empty,
		      "b":empty,"/b":empty,
		      "i":empty,"/i":empty,
		      "img":empty
		    ]),
		    (["textarea":fill_in_textarea,
		      "form":lambda(string tag,mapping args,string cont) 
			     { return cont; }]),
		    vars);
  
  string res="";
  foreach (data/"\n",string a)
  {
    string b,c,d;
    if (sscanf(a,"%s··indent··%s··/indent··%s",c,d,b)==3)
      res+=c+(d/"·\\n·")*("\n"+c)+b+"\n";
    else
      res+=a+"\n";
  }
  return res;
}

string container_forms_mail(string tag_name, mapping args, string contents, object id)
{
  if(!args->to)
    return "No receiver specified.";
  if(!id->variables->do_send)
    return
      "<form method=post><input type=hidden name=do_send value=1>"+contents+
      "<input type=submit name=submit>"
      "</form>";
  else
  {
    string domain;
    
    Protocols.SMTP.client()->simple_mail(args->to,"Automatic form reply","postmaster",
			       fill_in_form(contents,id->variables));
    return "Sent.";
  }
}

mapping query_container_callers()
{
  return ([ "forms-mail" : container_forms_mail ]);
}
