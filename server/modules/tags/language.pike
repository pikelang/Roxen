// This is a roxen module. (c) Informationsvvarna AB 1996.

// Written by Mattias Wingstedt <wing@infovav.se>, contact him for
// more info.

string cvs_version = "$Id: language.pike,v 1.4 1996/11/27 14:05:28 per Exp $";
#include <module.h>
inherit "module";
inherit "roxenlib";

#define WATCH(b,a) (perror( sprintf( b + ":%O\n", (a) ) ), (a))

/************** Generic module stuff ***************/

array register_module()
{
  return ({ /*MODULE_DIRECTORIES |*/ MODULE_URL, 
	    "Language module",
	    "Handles documents in different languages. "
	    "<br>Is also a directory module with nifty flags "
	    "if the file exists in more than one langauge.",
	    ({ }), 
	    1
         });
}

void create()
{
  defvar( "default_language", "en", "Default language", TYPE_STRING,
	 "The default language for this server. Is used when trying to "
	 "decide which language to send when the user hasn't selected any. "
	 "Also the language for the files with no language-extension." );

  defvar( "languages", "en	English\nde	Deutch		en\nsv	Svenska		en",
	 "Languages", TYPE_TEXT_FIELD,
	 "The languages supported by this site. One language on each row. "
	 "Syntax: "
	 "<br>language-code language-name optional-next-language-codes"
	 "<br>For example:\n"
	 "<pre>sv	Svenska		en de\n"
	 "en	English		de\n"
	 "de	Deutch		en\n"
	 "</pre>"
	 "<p>The next-language-code is used to determine what language should "
	 "be used in case the choosen language is unavailable. To find a "
	 "page with a suitable language the languages is tried as follows. "
	 "<ol><li>The selected language, stored as a prestate"
	 "<li>The user's agent's accept-headers"
	 "<li>The selected languages next-languages-codes if any"
	 "<li>The default language"
	 "<li>If there were no selected language, the default language's "
	 "next-language-codes"
	 "<li>All languages, in the order they appear in this text-field"
	 "</ol>"
	 "<p>Empty lines, lines beginning with # or // will be ignored. Lines "
	 "with errors may be ignored, or execute a HCF instruction." );

  defvar( "flag_dir", "/icons", "Flag directory", TYPE_STRING,
	 "A directory with small pictures of flags, or other symbols, "
	 "representing the various languages. Each flag should exist in the "
	 "following versions:"
	 "<dl><dt>language-code.selected.gif"
	 "<dd>Shown to indicate that the page is in that selected language, "
	 "usually by the header-module."
	 "<dt>language-code.available.gif"
	 "<dd>Shown as a link to the page in that language. Will of course "
	 "only be used if the page exists in that language."
	 "<dt>language-code.unavailable.gif"
	 "<dd>Shown to indicate that the user has selected an language that "
	 "this page hasn't been translated to."
/*	 "<dt>language-code.dir.selected.gif"
	 "<dd>Shown to indicate that the dir-entry will be shown in that "
	 "language."
	 "<dt>language-code.dir.avalable.gif"
	 "<dd>Shown as a link to the dir-entry translated to that language."
*/	 "</dl>"
	 "<p>It is of course not necessary to have all this pictures if "
	 "their use is not enabled in this module nor the header module." );

/*  defvar( "flags_or_text", 1, "Flags in directory lists", TYPE_FLAG,
	 "If set, the directory lists will include cute flags to indicate "
	 "which language the entries exists in. Otherwise it will be shown "
	 "with not-so-cure text. " );

  defvar( "readme", 1, "Include readme files", TYPE_FLAG,
	 "If set, include readme files in directory listings");


  defvar("directories", 1, "Directory parsing", TYPE_FLAG, 
	 "If you set this flag to on, a directories will be "+
	 "parsed to a file-list, if no index file is present. "+
	 "If not, a 'No such file or directory' response will be generated.");

  defvar("indexoverride", 1, "Directory indexfile override enabled", TYPE_FLAG,
	 "If set, requests ending with /. will always return a listing of "+
	 "the contents of the directory, even if there is an indexfile "+
	 "present.");

  defvar("no_tilde", 1, "Exclude backupfiles from directorylistings", 
	 TYPE_FLAG,
	 "If set, all files ending with '~' or '#' or '.bak' will "+
	 "be excluded from directory listings, since they are considered "+
	 "backups.");

  defvar("indexfiles", ({ "index.html", "Main.html", "welcome.html", 
			  "Welcome.html" }), 
	 "Directory index files", 
	 TYPE_STRING_LIST,
	 "If any of these files are present in a directory, they will be "+
	 "returned instead of the actual directory.");
*/
}

/*  Module specific stuff */


#define TYPE_MP  "    Module location"
#define TYPE_DIR "    Directory"


inline string image(string f) 
{ 
  return ("<img border=0 src="+(f)+" alt=>"); 
}

inline string link(string a, string b) 
{ 
  return ("<a href="+replace(b, ({ "//", "#" }), ({ "/", "%23" }))
	  +">"+a+"</a>"); 
}

string find_readme(string path, mapping id)
{
  string rm, f;
  object n;
  foreach(({ "README.html", "README" }), f)
  {
    rm=roxen->try_get_file(path+f, id);
    if(rm) if(f[-1] == 'l')
      return "<hr noshade>"+rm;
    else
      return "<pre><hr noshade>"+
	replace(rm, ({"<",">","&"}), ({"&lt;","&gt;","&amp;"}))+"</pre>";
  }
  return "";
}

string head(string path,mapping id)
{
  string rm="";

  if(QUERY(readme)) 
    rm=find_readme(path,id);
  
  return ("<h1>Directory listing of "+path+"</h1>\n<p>"+rm
	  +"<pre>\n<hr noshade>");
}

string describe_dir_entry( string path, string filename, array stat )
{
  string type, icon;
  int len;
  
  if (!stat)
    return "";

  switch (len=stat[1])
  {
   case -3:
    type = TYPE_MP;
    icon = "internal-gopher-menu";
    filename += "/";
    break;
      
   case -2:
    type = TYPE_DIR;
    filename += "/";
    icon = "internal-gopher-menu";
    break;
      
   default:
    array tmp;
    tmp = roxen->type_from_filename(filename, 1);
    if(!tmp)
      tmp = ({ "Unknown", 0 });
    type = tmp[0];
    icon = image_from_type( type );
    if(tmp[1])  type += " " + tmp[1];
  }
  
  return sprintf("%s %s %8s %-20s\n", 	
		 link(image(icon), http_encode_string(path + filename)),
		 link(sprintf("%-35s", filename[0..34]), 
		      http_encode_string(path + filename)),
		 sizetostring(len), type);
}

string key;

string new_dir(string path, mapping id)
{
  int i;
  array files;
  string fname;

  files = roxen->find_dir(path, id);
  if(!files) return "<h1>There is no such directory.</h1>";
  files = sort_array(files);

  for(i=0; i<sizeof(files) ; i++)
  {
    fname = replace(path+files[i], "//", "/");
    files[i] = describe_dir_entry(path,files[i],roxen->stat_file(fname, id));
  }
  return files * "";
}

mapping parse_directory( mapping id )
{
  string f;
  string dir;

  f = id->not_query;

  if (id->pragma[ "no-cache" ] || !(dir = cache_lookup( key, f )))
    cache_set( key, f, dir=new_dir( f, id ));
  return http_string_answer( head( f, id ) + dir);
}

// language part

mapping (string:mixed) language_data = ([ ]);
array (string) language_order = ({ });
#define LANGUAGE_DATA_NAME 0
#define LANGUAGE_DATA_NEXT_LANGUAGE 1
multiset (string) language_list;
string default_language, flag_dir;


mixed fnord(mixed what) { return what; }

void start()
{
  string tmp;
  array (string) tmpl;

  key = "file:" + roxen->current_configuration->name;

  foreach (query( "languages" ) / "\n", tmp)
    if (strlen( tmp ) > 2 && tmp[0] != '#' && tmp[0..1] != "//")
    {
      tmp = replace( tmp, "\t", " " );
      tmpl = tmp / " " - ({ "" });
      if (sizeof( tmpl ) >= 2)
      {
	language_data[ tmpl[0] ] = ({ tmpl[1], tmpl[2..17000] });
	language_order += ({ tmpl[0] });
      }
    }
  language_list = aggregate_multiset( @indices( language_data ) );
  foreach (indices( language_data ), tmp)
    language_data[ tmp ][ LANGUAGE_DATA_NEXT_LANGUAGE ] &= indices( language_list );
  default_language = query( "default_language" );
  flag_dir = query( "flag_dir" );
}

multiset (string) find_files( string url, object id )
{
  string filename, basename, extension;
  multiset (string) files = (< >);
  multiset result = (< >);
  array tmp;

  filename = reverse( (reverse( url ) / "/")[0] );
  basename = reverse( (reverse( url ) / "/")[1..17000] * "/" ) + "/";
  tmp = roxen->find_dir( basename, id );
  if (tmp)
    files = aggregate_multiset( @tmp );
  foreach (indices( language_list ), extension)
    if (files[ filename + "." + extension ])
      result[ extension ] = 1;
  if (files[ filename ])
    result[ "" ] = 1;
  return result;
}

mixed remap_url( object id, string url )
{
  string choosen_language, prestate_language, extension;
  string found_language;
  multiset (string) lang_tmp, found_languages, found_languages_orig;
  array (string) accept_language;

  if(id->misc->language)
    return 0;

  extension = reverse( (reverse( url ) / ".")[0] );
  if (language_list[ extension ])
  {
    string redirect_url;

    redirect_url = reverse( (reverse( url ) / ".")[1..17000] * "." );
    if (id->query)
      redirect_url += "?" + id->query;
    redirect_url = add_pre_state( redirect_url, (id->prestate - language_list) + (< extension >) );
    WATCH( 1, redirect_url );
    
    return http_redirect( redirect_url, id );
  }		    
  found_languages_orig = find_files( url, id );
  found_languages = copy_value( found_languages_orig );
  if (sizeof( found_languages_orig ) == 0)
    return 0;
  if (found_languages_orig[ "" ])
  {
    found_languages[ "" ] = 0;
    found_languages[ default_language ] = 1;
  }
  // The file with no language extension is supposed to be in the default
  // language

  // fill the accept_language list
  accept_language = ({ });
  accept_language &= indices( language_list );
  
  lang_tmp = language_list & id->prestate;
  if (sizeof( lang_tmp ))
    choosen_language = prestate_language = indices( lang_tmp )[0];
  else if (sizeof( accept_language ))
    choosen_language = accept_language[0];
  else
    choosen_language = default_language;

  if (found_languages[ choosen_language ])
    found_language = choosen_language;
  else if (sizeof( accept_language & indices( found_languages ) ))
    found_language = choosen_language
      = (accept_language & indices( found_languages ))[0];
  else if (prestate_language 
	   && sizeof( fnord(language_data[ prestate_language ]
		     [ LANGUAGE_DATA_NEXT_LANGUAGE ]
		      & indices( fnord(found_languages) ) )))
    found_language
      = (language_data[ prestate_language ][ LANGUAGE_DATA_NEXT_LANGUAGE ]
	 & indices( found_languages ))[0];
  else if (found_languages[ default_language ])
    found_language = default_language;
  else if (!prestate_language 
    	   && sizeof( language_data[ default_language ]
		     [ LANGUAGE_DATA_NEXT_LANGUAGE ]
		     & indices( found_languages ) ))
    found_language
      = ((language_data[ default_language ][ LANGUAGE_DATA_NEXT_LANGUAGE ]
	 & indices( found_languages )))[0];
  else
    found_language = (language_order & indices( found_languages ))[0];

  id->misc[ "available_languages" ] = copy_value( found_languages );
  id->misc[ "available_languages" ][ found_language ] = 0;
  id->misc[ "choosen_language" ] = choosen_language;
  id->misc[ "language" ] = found_language;
  id->misc[ "flag_dir" ] = flag_dir;
  id->misc[ "language_data" ] = copy_value( language_data );
  id->misc[ "language_list" ] = copy_value( language_list );
//  id->prestate -= language_list;
//  id->prestate[ found_language ] = 1; // Is this smart?

//  id->url = url;
  if (found_languages_orig[ found_language ])
    id->extra_extension += "." + found_language;
  // We don't change not_query incase it was a file without
  // extension that were found.

  return id;
}

