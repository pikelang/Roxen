// This is a roxen module. Copyright © 2000 - 2001, Roxen IS.
//

#include <module.h>
inherit "module";

constant thread_safe=1;

constant cvs_version = "$Id: check_spelling.pike,v 1.19 2004/05/27 18:28:44 _cvs_stephen Exp $";

constant module_type = MODULE_TAG;
constant module_name = "Tags: Spell checker";
constant module_doc = 
#"Checks for misspelled words inside the <tt>&lt;spell&gt;</tt> tag.";

mapping find_internal(string f, RequestID id)
{
  switch(f) {
  case "red.gif":
    return Roxen.http_string_answer("GIF89a\5\0\5\0\200\0\0\0\0\0\267\0\0,\0\0\0\0\5\0\5\0\0\2\7\204\37i\31\253g\n\0;","image/gif");
  case "green.gif":
    return Roxen.http_string_answer("GIF89a\5\0\5\0\200\0\0\2\2\2\0\267\14,\0\0\0\0\5\0\5\0\0\2\7\204\37i\31\253g\n\0;","image/gif");
  default:
    return 0;
  }
}

void create() {
  defvar("spellchecker","/usr/bin/ispell",
	 "Spell checker", TYPE_STRING,
         "Spell checker program to use.");

  defvar("dictionary", "american", "Default dictionary", TYPE_STRING,
         "The default dictionary used, when not specified in the tag.");

  defvar("report", "popup", "Default report type", TYPE_STRING_LIST,
         "The default report type used, when not specified in the tag.",
         ({ "popup","table" }) );

  defvar("prestate", "", "Prestate",TYPE_STRING,
         "If specified, only check spelling when this prestate is present.");

}

string render_table(array spellreport) {
  string ret="<table bgcolor=\"#000000\" border=\"0\" cellspacing=\"0\" cellpadding=\"1\">\n"
    "<tr><td><table border=\"0\" cellspacing=\"0\" cellpadding=\"4\">\n"
    "<tr bgcolor=\"#112266\">\n"
    "<th align=\"left\"><font color=\"#ffffff\">Word</font></th><th align=\"left\"><font color=\"#ffffff\">Suggestions</th></tr>\n";

  int row=0;
  foreach(spellreport,array word) {
    row++;
    ret+="<tr bgcolor=\"#"+(row&1?"ffffff":"ddeeff")+"\"><td align=\"left\">"+word[0]+"</td><td align=\"left\">"+word[1]+"</td></tr>\n";
  }
  return ret+"</table></td></tr>\n</table>";
}


string do_spell(string q, mapping args, string content,RequestID id)
{
  string ret="";

  if(args->help) return register_module()[2]+"<p>";

  string dict=args->dictionary || query("dictionary");
  if(!sizeof(dict)) dict="american";

  string text=Protocols.HTTP.unentity(content);

  text=replace(text,({"\n","\r"}),({" "," "}));
  text=Array.everynth((replace(text,">","<")/"<"),2)*" ";
  text=replace(text,
	       ({ ".",",",":",";","\t","!","|","?","(",")","\"" }),
	       ({ "", "", "", "", "",  "", "", "", "", "", ""   }) );
  array(string) words=text/" ";
  words-=({"-",""});


  array result=spellcheck(words,dict);

  if(args->report||query("report")=="popup") {
    if(!sizeof(result))
      return "<imgs src=\""+query_absolute_internal_location(id)+"green.gif\" />"+content;

    if(!id->misc->__checkspelling) {
      id->misc->__checkspelling=1;

      ret+=#"<script language=\"javascript\">
var spellcheckpopup='';
var isNav4 = false;
if (navigator.appVersion.charAt(0) == \"4\" && navigator.appName == \"Netscape\")
    isNav4 = true;

function getObj(obj) {
  if (isNav4)
    return eval(\"document.\" + obj);
  else
    return eval(\"document.all.\" + obj);
}

function getRecursiveLeft(o)
{
  if(o.tagName == \"BODY\")
    return o.offsetLeft;
  return o.offsetLeft + getRecursiveLeft(o.offsetParent);
}

function getRecursiveTop(o)
{
  if(o.tagName == \"BODY\")
    return o.offsetTop;
  return o.offsetTop + getRecursiveTop(o.offsetParent);
}

function showPopup(popupid,e) {
  if(isNav4){
    getObj(popupid).moveTo(e.target.x,e.target.y);
  } else {
    getObj(popupid).style.pixelLeft=getRecursiveLeft(window.event.srcElement);
    getObj(popupid).style.pixelTop=getRecursiveTop(window.event.srcElement);
  }
  spellcheckpopup=popupid
  if(isNav4) {
    getObj(popupid).visibility=\"visible\";
    document.captureEvents(Event.MOUSEMOVE);
    document.onMouseMove = checkPopupCoord;
  } else {
    getObj(popupid).style.visibility=\"visible\";
    document.onmousemove = checkPopupCoord;
  }
}

function checkPopupCoord(e)
{
  p = getObj(spellcheckpopup);
  if(isNav4) {
    x=e.pageX;
    y=e.pageY;
    pw=p.clip.width;
    ph=p.clip.height;
    px=p.left;
    py=p.top;
  } else {
    x=window.event.clientX + document.body.scrollLeft;
    y=window.event.clientY + document.body.scrollTop;
    pw=p.offsetWidth;
    ph=p.offsetHeight;
    px=p.style.pixelLeft;
    py=p.style.pixelTop;
  }
  if(!((x > px && x < px + pw) && (y > py && y < py + ph))) {
    if(isNav4) {
      p.visibility=\"hidden\";
      document.releaseEvents(Event.MOUSEMOVE);
    } else {
      p.style.visibility=\"hidden\";
      document.onMouseMove = 0;
     }
    }
 }
</script>";

    }


    string popupid="spellreport"+sprintf("%02x",id->misc->__checkspelling);

    ret+="<style>#"+popupid+" {position:absolute; left:0; top:0; visibility:hidden}</style>";
    ret+="<div id=\""+popupid+"\">"+render_table(result)+"</div>";

    ret+= "<a href=\"\" onMouseOver='if(isNav4) showPopup(\""+popupid+"\",event);else showPopup(\""+popupid+"\");'><imgs border=0 src=\""+query_absolute_internal_location(id)+"red.gif\" /></a>"+content;

    id->misc->__checkspelling++;
    return ret;
  }


  return content + "<p><b>Spell checking report:</b><p>"+
    render_table(result);
}


class TagSpell {
  inherit RXML.Tag;
  constant name="spell";

  class Frame {
    inherit RXML.Frame;
     array do_return (RequestID id) {
       string _prestate=id->variables->prestate||query("prestate");
       if(sizeof(_prestate) && !id->prestate[_prestate])
         return ({ content });
       else
         return ({ do_spell("spell",args,content,id) });
     }

  }
}

array spellcheck(array(string) words,string dict) {
  array res=({ });

  object file1=Stdio.File();
  object file2=file1->pipe();
  object file3=Stdio.File();
  object file4=file3->pipe();
  string spell_res;

  Process.create_process( ({ query("spellchecker"),"-a","-d",dict }) ,(["stdin":file2,"stdout":file4 ]) );


  file1->write(" "+words*"\n "+"\n");
  file1->close();
  file2->close();
  file4->close();
  spell_res=file3->read();
  file3->close();

  array ispell_data=spell_res/"\n";

  if(sizeof(ispell_data)>1) {
    int i,row=0,pos=0,pos2;
    string word,suggestions;
    for(i=1;i<sizeof(ispell_data)-1 && row<sizeof(words);i++) {
      if(!sizeof(ispell_data[i])){ // next row
	row++;
	pos=0;
      }
      else {
        switch(ispell_data[i][0]) {
        case '&': // misspelled, suggestions
          sscanf(ispell_data[i],"& %s %*d %d:%s",word,pos2,suggestions);
	  res += ({ ({ words[row],suggestions }) });;
          pos=pos2-1+sizeof(word);
          break;
	case '#': //misspelled
	  sscanf(ispell_data[i],"# %s %d",word,pos2);
	  res += ({ ({ words[row],"-" }) });
	  pos=pos2-1+sizeof(word);
	  break;
	}
      }
    }
    return res;
  }
}


TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"spell":#"<desc type='cont'><p><short>
 Checks words for spelling problems.</short> The spellchecker uses the ispell dictionary.
</p></desc>

<attr name='dict' value='american,others'><p>
 Select dictionary to use in the spellchecking. American is default.</p>
</attr>

<attr name='prestate' value='string'><p>
 What prestate to use.</p>
</attr>

<attr name='report' value='popup,table'><p>
 Either recieve the spellreport as a popup-window when clicking on the
 misspelled word or as a table with all misspelled words.</p>
</attr>",


    ]);
#endif
