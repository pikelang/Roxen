// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.
//

#include <module.h>

inherit "module";

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_FIRST | MODULE_TAG;
constant module_name = "Preferred Language Analyzer";
constant module_doc  = "Determine the clients preferred language based on \"accept-language\", prestates and cookies and more.";


array action_list(string prefs) {
  return map(prefs/"\n", `/, "\t");
}

string encode_action_list(array l) {
  return map(l, `*, "\t")*"\n";
}


class LanguagePrefs
{
  inherit Variable.Variable;
  constant type="LanguagePrefs";

  protected void create() {
    set_flags( VAR_INITIAL );
    _initial = "prestate\nroxen-config\naccept-language";
    __name = "Language sources";
    __doc =
#"<p>List of sources used for building the list of preferred languages.
Languages added from sources on top of the list will have a higher priority.</p>
<ul>
  <li><b>Accept-Language header</b> will add languages from the browser settings.</li>
  <li><b>Prestate</b> will add languages from prestates.</li>
  <li><b>Cookie</b> will add languages from a specified cookie.</li>
  <li><b>Variable</b> will add languages from a specified variable.</li>
  <li><b>Match host name</b> will add a specified list of languages if the host name
matches a given pattern. This can be used to select languages based on the URL,
such as using Swedish for roxen.se and English for roxen.com.</li>
  <li><b>Match path</b> will add languages based on the path.</li>
</ul>
<p>The <code>&lt;emit source=\"languages\"&gt;</code> tag can be used to easily build a language
selector which will change prestates and the roxen config cookie.</p>
<p>Note that the <b>\"Valid 'Prestate' and 'Config cookie' languages\"</b> setting determines
which prestates and which entries in the Roxen config cookie that are actually treated
as language settings.</p>";
  }

  string make_input_tag(string name, string value, int size) {
    string res = "<input name=\""+name+"\" size=\""+size+"\"";
    res += " value=";
    if(!has_value(value, "\"")) res += "\""+value+"\"";
    else if(!has_value(value, "'")) res += "'"+value+"'";
    else res += "\""+replace(value, "'", "&#39;")+"\"";
    return res + " />";
  }

  protected int _current_count = time()*100+(gethrtime()/10000);
  void set_from_form(RequestID id)
  {
    int rn, do_goto;
    array l = action_list(query());
    mapping vl = get_form_vars(id);
    // first do the assign...
    if( (int)vl[".count"] != _current_count )
      return;
    _current_count++;

    foreach( indices( vl ), string vv ) {

      if( sscanf( vv, ".set.%d.arg1%*s", rn ) == 2 )
      {
        m_delete( id->variables, path()+vv );
        l[rn][1] = vl[vv];
        m_delete( vl, vv );
      }
      if( sscanf( vv, ".set.%d.arg2%*s", rn ) == 2 )
      {
        m_delete( id->variables, path()+vv );
        l[rn][2] = vl[vv];
        m_delete( vl, vv );
      }


    }
    // then the move...
    foreach( indices(vl), string vv )
      if( sscanf( vv, ".up.%d.x%*s", rn ) == 2 )
      {
        do_goto = 1;
        m_delete( id->variables, path()+vv );
        m_delete( vl, vv );
        l = l[..rn-2] + l[rn..rn] + l[rn-1..rn-1] + l[rn+1..];
      }
      else  if( sscanf( vv, ".down.%d.x%*s", rn )==2 )
      {
        do_goto = 1;
        m_delete( id->variables, path()+vv );
        l = l[..rn-1] + l[rn+1..rn+1] + l[rn..rn] + l[rn+2..];
      }
    // then the possible add.
    if( vl[".new.x"] )
    {
      do_goto = 1;
      m_delete( id->variables, path()+".new.x" );
      switch(vl[".newtype"]) {
      case "accept-language":
	 l += ({ ({ "accept-language" }) });
	 break;
      case "prestate":
	 l += ({ ({ "prestate" }) });
	 break;
      case "roxen-config":
	l += ({ ({ "roxen-config" }) });
	break;
      case "cookie":
	l += ({ ({ "cookie","Language" }) });
	break;
      case "variable":
	l += ({ ({ "variable","Language" }) });
	break;
      case "hostmatch":
	l += ({ ({ "hostmatch","*.se","sv" }) });
	break;
      case "pathmatch":
	l += ({ ({ "pathmatch","/*","en" }) });
	break;
      }
    }

    // .. and delete ..
    foreach( indices(vl), string vv )
      if( sscanf( vv, ".delete.%d.x%*s", rn )==2 )
      {
        do_goto = 1;
        m_delete( id->variables, path()+vv );
        l = l[..rn-1] + l[rn+1..];
      }
    if( do_goto )
    {
      if( !id->misc->do_not_goto )
	{
	  id->misc->moreheads = ([
	    "Location":
	    id->raw_url+"?random="+
	    random(4949494)+
	    "&section="+
	    Roxen.http_encode_url (id->variables->section) +
	    "#" + Roxen.http_encode_url (path()),
	  ]);
	  if( id->misc->defines )
	    id->misc->defines[ " _error" ] = 302;
      }
    }
    set( encode_action_list(l) );
  }

  string render_form( RequestID id, void|mapping additional_args )
  {
    string prefix = path()+".";
    int i;

    string res = "<a name='"+path()+"'>\n</a><table class='auto rxn-var-list'>\n"
    "<input type='hidden' name='"+prefix+"count' value='"+_current_count+"' />\n";


    foreach( action_list(query()) , array _action )
    {
      string action = _action[0];

      res += "<tr>\n<td style='width:100%'>";

       switch(action) {
       case "accept-language":
	 res+= "<b>Use Accept-Language header</b>";
	 break;
       case "prestate":
	 res+= "<b>Use prestates</b>";
	 break;
       case "roxen-config":
	 res+= "<b>Use Roxen config cookie</b>";
	 break;
       case "cookie":
	 res+= "<b>Use cookie:</b> " + make_input_tag(prefix+"set."+i+".arg1",_action[1] ,8);
	 break;
       case "variable":
	 res+= "<b>Use variable:</b> " + make_input_tag(prefix+"set."+i+".arg1",_action[1],8);
	 break;
       case "hostmatch":
	 res+= "<b>Add languages:</b> " + make_input_tag(prefix+"set."+i+".arg2",_action[2],8) +
	   " if host matches glob: " + make_input_tag(prefix+"set."+i+".arg1",_action[1],8);
	 break;
       case "pathmatch":
	 res+= "<b>Add languages:</b> " + make_input_tag(prefix+"set."+i+".arg2",_action[2],8) +
	   " if the path matches glob: " + make_input_tag(prefix+"set."+i+".arg1",_action[1],8);
       }

       res += "</td>\n";

#define BUTTON(X,Y) ("<submit-gbutton2 name='"+X+"'>"+Y+"</submit-gbutton2>")
#define REORDER(X,Y) ("<submit-gbutton2 name='"+X+"' type='"+Y+"'></submit-gbutton2>")
      if( i )
        res += "\n<td>"+
            REORDER(prefix+"up."+i, "up")+
            "</td>";
      else
        res += "\n<td><disabled-gbutton type='up'/></td>";
      if( i != sizeof( query()/"\n")- 1 )
        res += "\n<td>"+
            REORDER(prefix+"down."+i, "down")
            +"</td>";
      else
        res += "\n<td><disabled-gbutton type='down'/></td>";
      res += "\n<td>"+
            BUTTON(prefix+"delete."+i, "Delete" )
          +"</td>";
          "</tr>";

      i++;
    }
    res +=
      "\n<tr><td colspan='2'>"+
      "<select name=\""+prefix+"newtype\">\n"+
      "<option value=\"accept-language\">Accept-Language header</option>\n"+
      "<option value=\"roxen-config\">Roxen config cookie</option>\n"+
      "<option value=\"prestate\">Prestate</option>\n"+
      "<option value=\"cookie\">Cookie</option>\n"+
      "<option value=\"variable\">Variable</option>\n"+
      "<option value=\"hostmatch\">Match host name</option>\n"+
      "<option value=\"pathmatch\">Match path</option>\n"+
      "</select> "+
      BUTTON(prefix+"new", "Add")+
      "</td></tr></table>\n<hr>\n";

    return res;
  }
}


void create() {
  defvar("actionlist", LanguagePrefs() );

  defvar( "propagate", 0, "Propagate language", TYPE_FLAG,
	  "Should the most preferred language be propagated into the page.theme_language variable, "
	  "which in turn will control the default language of all multilingual RXML tags." );

  defvar( "defaults", ({}), "Present Languages", TYPE_STRING_LIST,
	  "A list of all languages present on the server. An empty list means no restrictions." );

  defvar("iso639", Variable.StringChoice("ISO 639", ({ "ISO 639", "Starting with $" }), 0,
	 "Valid 'Prestate' and 'Config cookie' languages",
	 "When ISO 639 is selected, prestates and the Roxen config cookie entries mathing valid "
	 "ISO 639 language codes are considered to be language settings. Otherwise entries "
	 "starting with $ are used for selecting language. Note that this option affects which "
	 "prestates and config cookie entries that are removed when using "
         "&lt;emit source=\"languages\"&gt; to switch language.\n"));
}


constant alias = ({
  "ca",
  "catala",
  "es_CA",
  "cs",
  "cz",
  "cze",
  "czech",
  "de",
  "deutsch",
  "german",
  "en",
  "english",
  "fi",
  "finnish",
  "fr",
  "fr-be",
  "français",
  "french",
  "hr",
  "cro",
  "croatian",
  "hu",
  "magyar",
  "hungarian",
  "it",
  "italiano",
  "italian",
  "kj",
  "kanji",
  "jp",
  "japanese",
  "nihongo",
  "\62745\63454\105236",
  "mi",
  "maori",
  "maaori",
  "du",
  "nl",
  "nl-be",
  "ned",
  "dutch",
  "no",
  "norwegian",
  "norsk",
  "pl",
  "po",
  "polish",
  "pt",
  "port",
  "portuguese",
  "ru",
  "russian",
  "\2062\2065\2063\2063\2053\2051\2052",
  "si",
  "svn",
  "slovenian",
  "es",
  "esp",
  "spanish",
  "sr",
  "ser",
  "serbian",
  "sv",
  "se",
  "sve",
  "swedish",
  "svenska"
});

constant language_low=roxen->language_low;
array(string) languages;
array(string) defaults;
int iso639;
array compose_list_script = ({ });
void start() {
  languages =
    roxen->list_languages() + alias  +
    indices(Standards.ISO639_2.list_languages()) +
    indices(Standards.ISO639_2.list_639_1());
  defaults=[array(string)]query("defaults")&languages;
  iso639 = (query("iso639") == "ISO 639");
  compose_list_script = action_list(query("actionlist"));
}

array(string) get_config_langs(RequestID id) {
  array config = indices([multiset(string)]id->config);
  if(iso639)
    return config & languages;
  return map(config & Array.filter(config, lambda(string s) { return s[0..0] == "$";}),
	     lambda(string s) {return s[1..];});
}

array(string) get_prestate_langs(RequestID id) {
  array prestate =  indices([multiset(string)]id->prestate);
  if(iso639)
    return prestate & languages;
  return map(prestate & Array.filter(prestate, lambda(string s) { return s[0..0] == "$";}),
	     lambda(string s) {return s[1..];});
}

RequestID first_try(RequestID id) {
  array delayed_vary_actions = ({ });
  array(string) lang = ({ });
  PrefLanguages pl = id->misc->pref_languages;

  foreach(compose_list_script, array action) {
    switch(action[0]) {
    case "accept-language":
      array(string) accept_languages = pl->get_languages();
      lang += accept_languages;
      delayed_vary_actions += ({ ({ "accept-language", accept_languages }) });
      break;

    case "prestate":
      array(string) prestate_langs = get_prestate_langs(id);
      lang += prestate_langs;
      delayed_vary_actions += ({ ({ "prestate", prestate_langs }) });
      break;

    case "roxen-config":
      array(string) config_langs = get_config_langs(id);
      lang += config_langs;
      delayed_vary_actions += ({ ({ "cookie", "RoxenConfig", config_langs }) });
      break;

    case "cookie":
      if(sizeof(action) > 1) {
	//  Use id->real_cookies to avoid registering dependency right now
	string cookie_name = action[1];
	if (!id->real_cookies)
	  id->init_cookies();
	string cookie_value;
	if (cookie_value = id->real_cookies[cookie_name]) {
	  lang += ({ cookie_value });
	}
	delayed_vary_actions += ({ ({ "cookie", cookie_name,
				      cookie_value && ({ cookie_value }) }) });
      }
      break;

    case "variable":
      if(sizeof(action) > 1) {
	string var_name = action[1];
	if (array(string) var_value = id->real_variables[var_name]) {
	  lang += ({ var_value[0] });
	  delayed_vary_actions += ({ ({ "variable", var_name,
					({ var_value[0] }) }) });
	}
      }
      break;

    case "hostmatch":
      if(sizeof(action) > 2) {
	//  Ignore port number if present. Will not handle IPv6 addresses
	//  in numeric form but those are rather pointless for this filter
	//  anyway.
	string host = ((id->misc->host || "") / ":")[0];
	if(glob(action[1], host)) {
	  array(string) host_langs = map(action[2]/",",String.trim_all_whites);
	  lang += host_langs;
	  delayed_vary_actions += ({ ({ "host", host_langs }) });
	} else {
	  delayed_vary_actions += ({ ({ "host", 0 }) });
	}
      }
      break;

    case "pathmatch":
      if(sizeof(action) > 2)
	if(glob(action[1], id->raw_url || "")) {
	  array(string) path_langs = map(action[2]/",",String.trim_all_whites);
	  lang += path_langs;
	  delayed_vary_actions += ({ ({ "path", path_langs }) });
	}
      break;
    }
  }

  lang = Array.uniq(lang);
  lang -= ({ "" });

  if(sizeof(defaults))
    lang=lang&defaults;

  if(query("propagate") && sizeof(lang)) {
    if(!id->misc->defines) id->misc->defines=([]);
    ([mapping(string:mixed)]id->misc->defines)->theme_language=lang[0];
  }

  pl->set_sorted(lang);
  pl->delayed_vary_actions = delayed_vary_actions;
  return 0;
}

class TagEmitLanguages {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "languages";

  array get_dataset(mapping m, RequestID id) {
    array(string) langs;
    if(m->langs) {
      langs=([string]m->langs/",");
      if(iso639)
	langs &= languages;
    }
    else if( ([mapping(string:mixed)]id->misc->defines)->present_languages )
      langs=indices( [multiset(string)]([mapping(string:mixed)]id->misc->defines)->present_languages );
    else
      langs=defaults;

    object locale_obj =
      language_low(( [object(PrefLanguages)] id->misc->pref_languages)
		   ->get_language() || "eng");
    function(string:string) localized =
      locale_obj && [function(string:string)] locale_obj->language;

    string current_code = ( [object(PrefLanguages)] id->misc->pref_languages)
      ->get_language() || "";

    string url=Roxen.strip_prestate(Roxen.strip_config(id->raw_url));
    array(string) conf_langs=Array.map(get_config_langs(id),
			       lambda(string lang) { return "-"+(iso639?"":"$")+lang; } );

    array res=({});
    foreach(langs, string lang) {
      object locale_obj = [object] roxen->language_low(lang);
      array(string) lid =
	(locale_obj && [array(string)] locale_obj->id()) ||
	({ lang, "Unknown", "Unknown" });

      res+=({ (["code":lid[0],
		"current":current_code,
		"en": (lid[1] == "standard") ? "english" : lid[1],
		"local":lid[2],
		"preurl":Roxen.add_pre_state(url, id->prestate -
					     (iso639 ? aggregate_multiset(@languages) :
					      (multiset)map(get_prestate_langs(id), lambda(string s) {return "$"+s;})) +
					     (< (iso639?"":"$")+lang>)),
		"confurl":Roxen.add_config(url, conf_langs+({ (iso639?"":"$")+lang}), id->prestate),
		"localized": (localized && localized(lang)) || "Unknown" ]) });
    }
    return res;
  }
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([

  "emit#languages":({ #"<desc type='plugin'><p><short>Outputs language
descriptions.</short> It will output information associated to languages, such
as the name of the language in different languages. A list of languages that
should be output can be provided with the langs attribute. If no such attribute
is used a generated list of present languages will be used. If such a list could
not be generated the list provided in the Preferred Language Analyzer module
will be used.</p></desc>

<attr name='langs'><p>Should be a comma seperated list of language codes. The
languages associated with these codes will be emitted in that order.</p></attr>",
([
  "&_.code;"      : "<desc type='entity'><p>The language code.</p></desc>",
  "&_.current;"   : "<desc type='entity'><p>The code of the currently selected"
                    " language.</p></desc>",
  "&_.en;"        : "<desc type='entity'><p>The language name in english.</p>"
                    "</desc>",
  "&_.local;"     : "<desc type='entity'><p>The language name as written in "
                    "the language itself.</p></desc>",
  "&_.preurl;"    : "<desc type='entity'><p>A URL which makes this language "
                    "the used one by altering prestates.</p></desc>",
  "&_.confurl;"   : "<desc type='entity'><p>A URL which makes the language "
                    "the used one by altering the Roxen cookie.</p>"
                    "<note><p>The <tag>emit</tag> statement must be enclosed "
                    "in <tag>nocache</tag> to work correctly when this "
                    "entity is used.</p></note></desc>",
  "&_.localized;" : "<desc type='entity'><p>The language name as written in "
                    "the currently selected language.</p></desc>"
])
  })

]);
#endif
