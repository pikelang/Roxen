// This is a roxen module. Copyright © 1999-2000, Roxen IS.
//

//---------------- Module registration ----------------------

#include <module.h>

inherit "module";

constant thread_safe = 1;
constant cvs_version = "$Id: wml.pike,v 1.10 2000/08/22 20:08:08 nilsson Exp $";

constant module_type = MODULE_PARSER;
constant module_name = "WAP WML helper";
constant module_doc  = 
#"This module processes the <tag>&lt;wml&gt;</tag> tag in order to help
produce WML that suits different WAP clients.";

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"wml":#"<desc cont>
 Processes the wml tag and adapts the contents to better suit the
 client. The contents is always preparsed. No attributes are required.
</desc>

<attr name=from value=1.0|1.1>
 Tells what version of wml is used. Default is 1.1
</attr>

<attr name=to value=1.0|1.1>
 Force conversion to this version of wml
</attr>

<attr name=noheader>
 If used, no xml and doctype tags will be added to the document
</attr>

<attr name=mime value=string>
 Sets the mime-type of the document.
</attr>"]);
#endif

//--------------- Define converter classes ------------------

class wap_1_1 {
  constant mime=(["wml":"text/vnd.wap.wml",
	       "wbmp":"image/vnd.wap.wbmp"]);
  constant header="<?xml version=\"1.0\"?>"
  "<!DOCTYPE WML PUBLIC \"-//WAPFORUM//DTD WML 1.1//EN\" \"http://www.wapforum.org/DTD/wml_1.1.xml\">";

  string convert_up(string wml, void|RequestID id) {
    object xp = spider.XML();
    string ret=xp->parse(wml, parse_up, id);
    if(id) {
      string ua=id->client*" ";
      ret=character_encode(ret,ua);
      ret=client_kludge(ret,ua);
    }
    return ret;
  }

  string|int parse_up(string type, string t, mapping m, string|array c)
  {
    switch (type) {
    case "<>":
      m=m_up(m);
      if(t=="VAR") t=="setvar";
      if(t=="TAB") return "&nbsp;";  //This might need a better fix...
      return RXML.t_xml->format_tag(lower_case(t),m);
    case "":
      if(c!="") return c;
      return 0;
    case ">":
      c=c*"";
      m=m_up(m);
      return RXML.t_xml->format_tag(lower_case(t),m,c);
    default:
      return 0;
    }
  }

  //FIXME: empty strings shouldn't
  constant conv_att_up=(["postdata":"",
			 "default":"",
			 "ikey":"iname",
			 "onclick":"onpick",
			 "idefault":"ivalue",
			 "user-agent":"",
			 "key":"",
			 "public":"",
			 "style":"ordered",
			 "url":"href"
  ]);
  constant conv_arg_up=(["list":"",
			 "onclick":"onpick",
			 "set":""
  ]);
  constant case_arg_up=(<
    "ACCEPT",
    "BOTTOM",
    "CENTER",
    "CLEAR",
    "DELETE",
    "FALSE",
    "GET",
    "HELP",
    "LEFT",
    "LIST",
    "MIDDLE",
    "NOWRAP",
    "ONCLICK",
    "ONENTERBACKWARD",
    "ONENTERFORWARD",
    "ONTIMER",
    "OPTIONS",
    "PASSWORD",
    "PREV",
    "RESET",
    "RIGHT",
    "TOP",
    "TRUE",
    "POST",
    "SET",
    "TEXT",
    "UNKNOWN",
    "WRAP",
  >);

  mapping m_up(mapping m) {
    mapping n=([]);
    string att,arg;
    foreach(indices(m), string tmp) {
      att=lower_case(tmp);
      if(conv_att_up[att]!="") {
        arg=case_arg_up[m[tmp]]?lower_case(m[tmp]):m[tmp];
        if(att=="style" && arg=="list") arg="true";
        if(att=="style" && arg=="set") arg="false";
        if(conv_att_up[att]) att=conv_att_up[att];
        if(conv_arg_up[arg]) arg=conv_arg_up[arg];
        n[att]=arg;
      }
    }
    return n;
  }

  string add_wml(string c, mapping m) {
    return RXML.t_xml->format_tag("wml",m,c);
  }

  array char_from=({});
  array char_to=({});

  void create() {
    for(int i=128; i<256; i++) {
      char_from+=({" "});
      char_from[-1][0]=i;
      char_to+=({"&#"+i+";"});
    }
  }

  string character_encode(string c, string ua) {
    //FIXME: Also make sure that only the entities
    // quot, amp, apos, lt, gt, nbsp and shy is used
    return replace(c,char_from,char_to);
  }

  string client_kludge(string c, string ua) {
    return c;
  }

}

class wap_1_0 {
  constant mime=(["wml":"text/x-wap.wml",
	       "wbmp":"image/x-wap.wbmp"]);
  constant header="<?xml version=\"1.0\"?>"
  "<!DOCTYPE WML PUBLIC \"-//WAPFORUM//DTD WML 1.0//EN\" \"http://www.wapforum.org/DTD/wml.xml\">";

  string convert_down(string wml, void|RequestID id) {
    object xp = spider.XML();
    string ret=xp->parse(wml, parse_down);
    if(id) {
      string ua=id->client*" ";
      ret=character_encode(ret,ua);
      ret=client_kludge(ret,ua);
    }
    return ret;
  }

  string|int parse_down(string type, string t, mapping m, string|array c)
  {
    switch (type) {
    case "<>":
      m=m_down(m);
      if(t=="td") return RXML.t_xml->format_tag("TAB",m);
      if(t=="tr") return RXML.t_xml->format_tag("BR",m);
      if(t=="table") return "";
      if(t=="p") return RXML.t_xml->format_tag("BR",m);
      if(t=="postfield") return "";
      if(t=="setvar") t=="VAR";
      return RXML.t_xml->format_tag(upper_case(t),m);
    case "":
      if(c!="") return c;
      return 0;
    case ">":
      c=c*"";
      m=m_down(m);
      if(t=="td") return c+RXML.t_xml->format_tag("TAB",m);
      if(t=="tr") return c+RXML.t_xml->format_tag("BR",m);
      if(t=="table") return c;
      if(t=="p") return RXML.t_xml->format_tag("BR",m)+c+RXML.t_xml->format_tag("BR",m);
      if(t=="postfield") return c; //FIXME
      return RXML.t_xml->format_tag(upper_case(t),m,c);
    default:
      return 0;
    }
  }

  constant conv_att_down=(["INAME":"IKEY",
			 "ONPICK":"ONCLICK",
			 "IVALUE":"IDEFAULT",
			 "ORDERED":"STYLE",
			 "HREF":"URL",
			 "CLASS":"",
			 "COLUMNS":"",
			 "ID":"",
			 "FORUA":"",
			 "HTTP-EQUIV":""
  ]);
  constant conv_arg_down=(["ONPICK":"ONCLICK"
  ]);
  constant case_arg_down=(<
    "accept",
    "bottom",
    "center",
    "clear",
    "delete",
    "Content-Type",
    "Expires",
    "false",
    "get",
    "help",
    "left",
    "middle",
    "nowrap",
    "onpick",
    "onenterbackward",
    "onenterforward",
    "ontimer",
    "options",
    "password",
    "post",
    "prev",
    "reset",
    "right",
    "text",
    "top",
    "true",
    "unknown",
    "wrap"
  >);

  mapping m_down(mapping m) {
    mapping n=([]);
    string att,arg;
    foreach(indices(m), string tmp) {
      if(tmp!="xml:lang")
	att=upper_case(tmp);
      else
	att=tmp;
      arg=case_arg_down[m[tmp]]?upper_case(m[tmp]):m[tmp];
      if(att=="ORDERED" && arg=="TRUE") arg="LIST";
      if(att=="ORDERED" && arg=="FALSE") arg="SET";
      if(conv_att_down[att]) att=conv_att_down[att];
      if(conv_arg_down[arg]) arg=conv_arg_down[arg];
      n[att]=arg;
    }
    return n;
  }

  string add_wml(string c, mapping m) {
    return RXML.t_xml->format_tag("WML",m,c);
  }

  array char_from=({});
  array char_to=({});

  void create() {
    for(int i=128; i<256; i++) {
      char_from+=({" "});
      char_from[-1][0]=i;
      char_to+=({"&#"+i+";"});
    }
  }

  string character_encode(string c, string ua) {
    //FIXME: Also make sure that only the entities
    // quot, amp, apos, lt, gt, nbsp and shy is used
    return replace(c,char_from,char_to);
  }

  string client_kludge(string c, string ua) {
    return c;
  }

}

mapping wap=(["1.0":wap_1_0(),"1.1":wap_1_1()]);


//---------------- Stuff that really do something ----------------------

string simpletag_wml(string tag, mapping m, string|array(string) c, RequestID id) {

  //What do we have and where should we go?
  string from=m->from||"1.1";
  m_delete(m,"from");

  string to="1.1";
  if(m->to && wap[m->to]) to=m->to;
  else if(id->supports["wap1.1"]) to="1.1";
  else if(id->supports["wap1.0"]) to="1.0";
  m_delete(m,"to");

  //Convert images
  c=parse_html(c, ([]), (["img":
			lambda(string t, mapping m) {
			  if(id->supports->wbmp0)
			    m->format="wbf";
			  else
			    m->format="gif";
			  return RXML.t_xml->format_tag("cimg",m);
			}]));

  //Always preparse. Good/Bad?
  c=Roxen.parse_rxml(c,id);
  c=wap[from]->add_wml(c,m-(["noheader":1,"mime":1]));

  if(from!=to) {
    c=convert_wap(c,from,to,id);
    if(arrayp(c)) c=c*"";
   }
  else {
    string ua=id->client*" ";
    wap[to]->character_encode(c, ua);
    wap[to]->client_kludge(c, ua);
  }

  if(!m->noheader) c=wap[to]->header+c;

  return c;
}

//Here I had a nice OO model, but I gave it up for speed and efficency.
string convert_wap(string c, string from, string to, object id) {
  if(from=="1.0" && to=="1.1") return wap["1.1"]->convert_up(c,id);
  if(from=="1.1" && to=="1.0") return wap["1.0"]->convert_down(c,id);
  return c;
}
