// Copyright © 2000, Roxen IS.
// By Martin Nilsson

#define CLEAN_CYCLE 60*60

// project_name:project_path
private mapping(string:string) projects;
// language:(project_name:project)
private mapping(string:mapping(string:object)) locales;

void create() {
  projects=([]);
  locales=([]);
  call_out(clean_cache, CLEAN_CYCLE);
}

void register_project(string name, string path, void|string path_base)
  //! Make a connection between a project name and where its
  //! localization files can be found. The mapping from project
  //! name to locale file is stored in projects.
{
  if(path_base) {
    array tmp=path_base/"/";
    path_base=tmp[..sizeof(tmp)-2]*"/"+"/";
    path=combine_path(path_base, path);
  }
#ifdef LOCALE_DEBUG
  if(projects[name] && projects[name]!=path)
    werror("Changing project %s from %s to %s\n",
	   name, projects[name], path);
#endif
  projects[name]=path;
}

array(string) list_languages(string project) {
  if(!projects[project]) return ({});
  string pattern=replace(projects[project], "%%", "%");
  string dirbase=(pattern/"%L")[0];
  if(dirbase[-1]!='/') {
    array split=dirbase/"/";
    dirbase=split[..sizeof(split)-2]*"/"+"/";
  }
  string s_patt;
  if(search(pattern, "/", sizeof(dirbase))==-1)
    s_patt=pattern;
  else
    s_patt=pattern[sizeof(dirbase)..search(pattern, "/", sizeof(dirbase))-1];
  s_patt=replace(s_patt, "%L", "%3s");

  array list=({});
  foreach(get_dir(dirbase), string path) {
    string lang;
    if(!sscanf(path, s_patt, lang)) continue;
    if(!file_stat(replace(pattern, "%L", lang))) continue;
    list+=({ lang });
  }
  return list;
}

class LocaleObject {

  // key:string
  private mapping(string:string) bindings;
  // key:function
  private mapping(string:function) functions;
  int timestamp;

  void create(mapping(string:string) _bindings,
	      void|mapping(string:function) _functions) {
    bindings=_bindings;
    if(_functions)
      functions=_functions;
    else
      functions=([]);
    timestamp=time(1);
  }

  string translate(string key) {
    return bindings[key];
  }

  mixed `() (string f, array ... args) {
    if(functionp(functions[f]))
      return functions[f](@args);
    else
      return functions[f];
  }

}

object get_object(string project, string lang) {

  // Is there such a project?
  if(!projects[project])
    return 0;

  // Any language?
  if(!lang)
    return 0;

  // Is there already a locale object?
  LocaleObject locale_object;
  if(!locales[lang]) {
    locales[lang]=([]);
  }
  else if(locale_object=locales[lang][project]) {
    locale_object->timestamp=time(1);
    return locale_object;
  }

  string filename=replace(projects[project],
			  ({ "%L", "%%" }),
			  ({ lang, "%" }) );
  Stdio.File file=Stdio.File();
  if(!(file->open(filename, "r")))
    return 0;
  string data=file->read();
  file->close();

  mapping(string:string) bindings=([]);
  mapping(string:function) functions=([]);
  function(string:string) decode=0;
  function t_tag = lambda(string t, mapping m, string c) {
		     if(m->id && m->id!="" && c!="") {
		       // Replace encoded entities
		       c = replace(c, ({"&lt;","&gt;","&amp;"}),
		                      ({ "<",   ">",    "&"  }));
		       if(decode && catch( c = decode(c) ))
			 // FIXME logging of decoding error?
			 return 0;
		       bindings[m->id]=c;
		     }
		     return 0;
		   };
  function pike_tag = lambda(string t, mapping m, string c) {
			// Replace encoded entities
			c = replace(c, ({"&lt;","&gt;","&amp;"}),
				       ({ "<",   ">",    "&"  }));
			if(decode && catch( c = decode(c) ))
			  // FIXME logging of decoding error?
			  return 0;
			mixed err;
			object gazonk;
			err = catch{ gazonk=compile_string("class gazonk {"+
							   c+"}")->gazonk(); };
			if(err) {
			  // FIXME logging of error?
			  return 0;
			}
			foreach(indices(gazonk), string name)
			  functions[name]=gazonk[name];
			return 0;
		      };

  Parser.HTML xml_parser = Parser.HTML();
  xml_parser->case_insensitive_tag(1);
  xml_parser->
    add_containers( ([ "t"         : t_tag,
		       "translate" : t_tag,
		       "pike"      : pike_tag, ]) );
  xml_parser->
    add_quote_tag("?xml",
		    lambda(object foo, string c) {
		      sscanf(c,"%*sencoding=\"%s\"",string encoding);
		      if(encoding && encoding!="") {
			switch(lower_case(encoding)) 
			  {
			  case "utf-8": case "utf8":
			    decode = 
			      lambda(string s) {
				return utf8_to_string(s);
			      };
			    break;

			  case "utf-16": case "utf16":
			  case "unicode":
			    decode = 
			      lambda(string s) {
				return unicode_to_string(s);
			      };
			    break;

			  default:
			    object dec;
			    if(catch(dec = Locale.Charset.decoder(encoding))) {
			      // FIXME logging of encoding error?
			      break;
			    }
			    decode =
			      lambda(string s) {
				return dec->clear()->feed(s)->drain();
			      };
			    break;

			  case "iso-8859-1":
			  // No decode needed
			  }
		      }
		      return 0;
		    },"?");
  xml_parser->feed(data)->finish();

  locale_object=LocaleObject(bindings, functions);
  locales[lang][project]=locale_object;
  return locale_object;
}

mapping(string:object) get_objects(string lang) {
  if(!lang)
    return 0;
  foreach(indices(projects), string project)
    get_object(project, lang);
  return locales[lang];
}

string translate(LocaleObject locale_object, string id,
		 string str)
  //! Does a translation with the given locale object.
{
  if(locale_object) {
    locale_object->timestamp=time(1);
    string t_str = locale_object->translate(id);
    if(t_str) return t_str;
  }
  return str;
}

static void clean_cache() {
  remove_call_out(clean_cache);
  int t=time(1)-CLEAN_CYCLE;
  foreach(indices(locales), string lang) {
    foreach(indices(locales[lang]), string proj) {
      if(locales[lang][proj]->timestamp < t)
	m_delete(locales[lang], proj);
    }
  }
  call_out(clean_cache, CLEAN_CYCLE);
}

class DeferredLocale
{
  static string project;
  static string key;
  static string fallback;
  function(void:LocaleObject) get_locale;
  void create(function(void:LocaleObject) get_locale_, string key_, string fallback_)
  {
    get_locale = get_locale_;
    key = key_;
    fallback = fallback_;
  }
  static inline string lookup()
  {
    return translate(get_locale(), key, fallback);
  }
  string _sprintf(int c)
  {
    switch(c) {
    case 's':
      return lookup();
    case 'O':
      return
	sprintf("%O", lookup());
    default:
      error(sprintf("Illegal formatting char '%c'\n", c));
    }
  }
  string `+(mixed x)
  {
    return lookup()+x;
  }
  string ``+(mixed x)
  {
    return x+lookup();
  }
  int _sizeof()
  {
    return sizeof(lookup());
  }
  int|string `[](int a,int|void b)
  {
    if (query_num_arg() < 2) {
      return lookup()[a];
    }
    return lookup()[a..b];
  }
  array(string) `/(string s)
  {
    return lookup()/s;
  }
  array(int) _indices()
  {
    return indices(lookup());
  }
  array(int) _values()
  {
    return values(lookup());
  }
  mixed cast(string to)
  {
    if(to=="string") return lookup();
    throw( ({ "Cannot cast DeferredLocale to "+to+".\n", backtrace() }) );
  }
  int _is_type(string type) {
    return type=="string";
  }
};
