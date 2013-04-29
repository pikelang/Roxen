// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.
//

#include <module.h>
inherit "module";

constant thread_safe=1;

constant cvs_version = "$Id$";

constant module_type = MODULE_TAG|MODULE_PROVIDER;
constant module_name = "Tags: Spell checker";
constant module_doc = 
#"Checks for misspelled words using the <tt>&lt;emit#spellcheck&gt;</tt> or
<tt>&lt;spell&gt;</tt> tags.";

array(string) query_provides()
{
  return ({ "spellchecker" });
}


mapping(string:function) query_action_buttons()
{
  return ([ "Rebuild Custom Dictionaries" :
	    lambda() { sync_extra_dicts(1); } ]);
}


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
  defvar("spellchecker",
#ifdef __NT__
	 lambda() {
	   catch {
	     // RegGetValue() throws if the key isn't found.
	     return replace(RegGetValue(HKEY_LOCAL_MACHINE,
					"SOFTWARE\\Aspell",
					"Path") + "\\aspell.exe", "\\", "/");
	   };
	   // Reasonable default.
	   return "C:/Program Files/Aspell/bin/aspell.exe";
	 }(),
#else
	 "/usr/bin/aspell",
#endif
	 "Spell checker", TYPE_STRING,
         "Spell checker program to use.");

  defvar("dictionary", "american", "Default dictionary", TYPE_STRING,
         "The default dictionary used, when not specified in the "
	 "&lt;spell&gt; tag.");

  defvar("extra_dicts", ({ }), "Custom dictionaries",
	 TYPE_FILE_LIST,
	 "Paths to custom dictionary files. These should be plain-text "
	 "files with one word on each line. NOTE: Filenames must include "
	 "a valid language code before the file suffix, e.g. "
	 "<tt>mywords.en.txt</tt> or <tt>mywords.en_US.txt</tt>. "
	 "The plain-text files must also use UTF-8 encoding if you enable "
	 "the UTF-8 support in the setting below.");
  
  defvar("report", "popup", "Default report type", TYPE_STRING_LIST,
         "The default report type used, when not specified in the "
	 "&lt;spell&gt; tag.",
         ({ "popup","table" }) );

  defvar("prestate", "", "Prestate",TYPE_STRING,
         "If specified, only check spelling in the &lt;spell&gt; tag "
	 "when this prestate is present.");

  defvar("use_utf8", 1, "Enable UTF-8 support",
	 TYPE_FLAG,
	 "If set takes advantage of UTF-8 support in Aspell. NOTE: Requires "
	 "Aspell version 0.60 or later.");

}


string status()
{
  //  Sync dictionaries and list status
  sync_extra_dicts();
  array(string) ed_res = ({ });
  foreach (get_extra_dicts(); string ed_path; string pd_path) {
    ed_res +=
      ({ "<li>" + Roxen.html_encode_string(ed_path) +
	 " <span style='color: #888'>&ndash;</span> " +
	 (pd_path ?
	  "<span style='color: green'>OK</span>" :
	  "<span style='color: red'>Error</span>") +
	 "</li>" });
  }
  if (sizeof(ed_res)) {
    return
      "<p><b>Custom dictionaries</b></p>"
      "<ul>" + (sort(ed_res) * "\n") + "</ul>";
  }
  return "";
}


void start(int when, Configuration conf)
{
  sync_extra_dicts();
}


string get_processed_dict_path(string extra_dict)
{
  //  Hash the external path and return a corresponding item in $VARDIR
  string ed_hash =
    lower_case(String.string2hex(Crypto.MD5()->hash(extra_dict)));
  return
    combine_path(getcwd(),
		 roxen_path("$VARDIR/check_spelling/" + ed_hash + ".dict"));
}

string|void get_extra_dict_language(string ed_path)
{
  //  Only accept filenames structured as mywords.en.txt. We require
  //  at least two "." and a non-empty language code.
  string ed_name = basename(ed_path);
  array(string) ed_segments = ed_name / ".";
  return
    (sizeof(ed_segments) > 2) && sizeof(ed_segments[-2]) && ed_segments[-2];
}


mapping(string:string) get_extra_dicts(void|int(0..1) include_empty)
{
  mapping(string:string) res = ([ ]);
  foreach (query("extra_dicts"), string ed_path) {
    //  Only accept files that follow required naming convention
    res[ed_path] = 0;
    if (!get_extra_dict_language(ed_path))
      continue;
    
    if (file_stat(ed_path)) {
      //  Processed dictionary
      string pd_path = get_processed_dict_path(ed_path);
      if (Stdio.Stat pd_stat = file_stat(pd_path)) {
	//  Don't include zero-byte placeholders that we only keep to
	//  avoid re-converting broken source files unless caller wants
	//  them.
	if (pd_stat->size || include_empty)
	  res[ed_path] = pd_path;
      } else if (include_empty) {
	//  Not yet processed but a valid candidate
	res[ed_path] = pd_path;
      }
    }
  }
  return res;
}


//  Returns tuple < encoding, chars to skip > if the given data string
//  starts with a BOM, and zero otherwise.
array(string|int) get_encoding_from_bom(string data)
{
  //  We only care about UTF-8 and UTF-16 BE/LE:
  //
  //    EF BB BF   - UTF-8
  //    FE FF      - UTF-16 big-endian
  //    FF FE      - UTF-16 little-endian
  if (sizeof(data) >= 3) {
    if (data[0] == 0xEF && data[1] == 0xBB && data[2] == 0xBF)
      return ({ "utf-8", 3 });
  }
  if (sizeof(data) >= 2) {
    if (data[0] == 0xFE && data[1] == 0xFF)
      return ({ "utf-16", 2 });
    if (data[0] == 0xFF && data[1] == 0xFE)
      return ({ "utf-16le", 2 });
  }
  return 0;
}


int process_extra_dict(string ed_path, string pd_path)
{
  //  Make sure destination directory exists
  mkdirhier(dirname(pd_path) + "/");
  
  //  Convert the extra_dict source file (plain-text file) in ed_path
  //  and write it to the processed dictionary at pd_path.
  string aspell_binary = query("spellchecker");
  if (!Stdio.exist(aspell_binary))
    return -1;
  
  int use_utf8 = query("use_utf8");
  array(string) args =
    ({ aspell_binary, "--lang", get_extra_dict_language(ed_path) }) +
    (use_utf8 ? ({ "--encoding", "utf-8" }) : ({ }) ) +
    ({ "create", "master", pd_path });
  report_notice("Spell Checker: Converting dictionary %s... ", ed_path);

  //  Aspell doesn't like MS-DOS line endings so write a clean temp file.
  //  We also heed any BOM that we find.
  string in_data = Stdio.read_bytes(ed_path);
  if (!in_data) {
    report_notice("Error reading dictionary: %s\n", ed_path);
    return -1;
  }
  if (array bom_data = get_encoding_from_bom(in_data)) {
    //  Skip BOM bytes and recode to UTF-8 if currently in a different format
    in_data = in_data[bom_data[1]..];
    if (bom_data[0] != "utf-8") {
      if (object dec = Locale.Charset.decoder(bom_data[0]))
	in_data = string_to_utf8(dec->feed(in_data)->drain());
    }
  }
  in_data = replace(in_data, ({ "\r\n", "\r" }), ({ "\n", "\n" }) );
  string ed_cleaned_path = ed_path + ".tmp";
  if (mixed err = catch {
      Stdio.write_file(ed_cleaned_path, in_data);
    }) {
    report_notice("Error writing temp file: %s\n", ed_cleaned_path);
    return -1;
  }
  
  Stdio.File in_file = Stdio.File(ed_cleaned_path);
  Process.Process p = Process.Process(args, ([ "stdin": in_file ]) );
  in_file->close();
  int err = p->wait();
  rm(ed_cleaned_path);
  report_notice((err ? "Error" : "OK") + "\n");
  return err;
}


void sync_extra_dicts(void|int force_rebuild)
{
  //  Stat each of the configured extra dictionaries and check whether our
  //  compressed versions are out-of-date.
  foreach (get_extra_dicts(1); string ed_path; string pd_path) {
    //  Skip invalid filenames
    if (!pd_path)
      continue;
    
    if (Stdio.Stat ed_stat = file_stat(ed_path)) {
      //  Compare to stat of our derived file
      Stdio.Stat pd_stat = file_stat(pd_path);
      if (force_rebuild || !pd_stat || (ed_stat->mtime >= pd_stat->mtime)) {
	int err = process_extra_dict(ed_path, pd_path);
	if (err) {
	  //  Write a zero-byte file in case of failed conversion. This
	  //  means we can avoid re-converting it but still skip it when
	  //  we gather all extra dictionaries.
	  rm(pd_path);
	  Stdio.write_file(pd_path, "");
	}
      }
    }
  }
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

  string text=Parser.parse_html_entities (content, 1);

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
      return "<img src=\""+query_absolute_internal_location(id)+"green.gif\">"+content;

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

function getRecursiveLeft(o) {
  if(o.tagName == \"BODY\")
    return o.offsetLeft;
  return o.offsetLeft + getRecursiveLeft(o.offsetParent);
}

function getRecursiveTop(o) {
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

function checkPopupCoord(e) {
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

    ret+= "<a href=\"\" onMouseOver='if(isNav4) showPopup(\""+popupid+"\",event);else showPopup(\""+popupid+"\");'><img border=0 src=\""+query_absolute_internal_location(id)+"red.gif\"></a>"+content;

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

string run_spellcheck(string|array(string) words, void|string dict)
// Returns 0 on failure.
{
  //  Sync any custom dictionaries in case they have been edited, and
  //  fetch a list of valid ones to add in this run.
  sync_extra_dicts();
  mapping(string:string) extra_dicts = get_extra_dicts();
  array(string) ed_args = ({ });
  foreach (extra_dicts; string ed_path; string pd_path) {
    if (pd_path)
      ed_args += ({ "--add-extra-dicts", pd_path });
  }
  
  object file1=Stdio.File();
  object file2=file1->pipe();
  object file3=Stdio.File();
  object file4=file3->pipe();
  string spell_res;
  int use_utf8 = query("use_utf8");

  if(stringp(words))
    words = replace(words, "\n", " ");
  if(!Stdio.exist(query("spellchecker")))
  {
    werror("check_spelling: Missing binary in %s\n", query("spellchecker"));
    return 0;
  }
  Process.Process p =
    Process.Process(({ query("spellchecker"), "-a", "-C" }) +
		    (use_utf8 ? ({ "--encoding=utf-8" }) : ({ }) ) +
		    (stringp(words) ? ({ "-H" })         : ({ }) ) +
		    (dict           ? ({ "-d", dict })   : ({ }) ) +
		    ed_args,
		    ([ "stdin":file2,"stdout":file4 ]));

  string text = stringp(words) ?
               " "+words /* Extra space to ignore aspell commands
                            (potential security problem), compensated
                            below. */ :
               " "+words*"\n "+"\n" /* Compatibility mode. */;

  //  Aspell 0.60 or later understands UTF-8 encoding natively
  if (use_utf8)
    text = string_to_utf8(text);
  else
    text = Locale.Charset.encoder("iso-8859-1", "\xa0")->feed(text)->drain();
  
  Stdio.sendfile(({ text }), 0, 0, -1, 0, file1,
                 lambda(int bytes) { file1->close(); });

  file2->close();
  file4->close();
  spell_res=file3->read();
  file3->close();
  
  if (use_utf8 && spell_res)
    catch { spell_res = utf8_to_string(spell_res); };
  
  return p->wait() == 0 ? spell_res : 0;
}

array spellcheck(array(string) words,string dict)
{
  array res=({ });

  array ispell_data = (run_spellcheck(words, dict) || "")/"\n";

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

class TagEmitSpellcheck {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "spellcheck";

  mapping(string:RXML.Type) req_arg_types = ([
      "text" : RXML.t_text(RXML.PEnt),
    ]);
  
  array get_dataset(mapping args, RequestID id)
  {
    array(mapping(string:string)) entries = ({});

    string dict = args["dict"];
    string text = args["text"];
    if(text)
    {
      string s = run_spellcheck(text, dict);
      if(!s)
      {
	if(args["error"])
	  RXML.user_set_var(args["error"], "checkfailed");
	return ({});
      }
      foreach(s/"\n", string line)
      {
	line -= "\r";   // Needed for aspell on Windows.
	if(!sizeof(line))
	  continue;

	switch(line[0])
	{
	  case '*':
	    // FIXME: Optimisation: Make aspell not send this!
	    continue;
	    
	  case '&':
	    if(sscanf(line, "& %s %*d %d: %s", string word, int offset, string suggestions) == 4)
	      entries += ({ ([ "word":word,
			       "offset":offset-1 /* For extra space (see above)! */,
			       "suggestions":suggestions ]) });
	    continue;
	    
	  case '#':
	    if(sscanf(line, "# %s %d", string word, int offset) == 2)
	      entries += ({ ([ "word":word,
			       "offset":offset-1 /* For extra space (see above)! */ ]) });
	    continue;
	}
      }
    }

    return entries;
  }
}


TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"emit#spellcheck":({ #"<desc type='plugin'><p><short>
  Lists from a text words that are not found in a
  dictionary using aspell.</short></p>
</desc>

<attr name='text' value='string'><p>The text to be spell checked. Tags are allowed in the text.</p></attr>

<attr name='dict' value='string'><p>Optionally select a dictionary.</p></attr>

<attr name='error' value='string'><p>Variable to set if an error occurs.</p></attr>
",
 ([
   "&_.word;":#"<desc type='entity'><p>The word not found in the dictionary.</p></desc>",
   "&_.offset;":#"<desc type='entity'><p>Character offset to the word in the text.</p></desc>",
   "&_.suggestions;":#"<desc type='entity'><p>If present, a comma and space separated list of suggested word replacements.</p></desc>"
 ])
}),

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
