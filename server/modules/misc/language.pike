#include <module.h>
inherit "module";
inherit "roxenlib";

string cvsid = "$Id: language.pike,v 1.7 1997/08/15 17:50:25 peter Exp $";

array register_module()
{
  return ({ MODULE_DIRECTORIES | MODULE_URL | MODULE_PARSER, 
	      "Language module",
	      "Handles documents in different languages. "
	      "<p>Is also a directory module that generates no directory "
	      "listings. It must be a directory module to work, though it "
	      "could of course be fixed to make directory listings."
	      "The module works by using appropriate magic to find out what "
	      "language the user wants and then finding a file in that "
	      "language. What language a file is in is specified with an "
	      "extra extension. index.html.sv would be a file in swedish "
	      "while index.html.en would be one in english. "
	      "<p>The module also defines three new tags. "
	      "<br><b>&lt;language&gt;</b> that tells which language the "
	      "current page is in. "
	      "<br><b>&lt;available_languages&gt;</b> gives a list of other "
	      "languages the current page is in, with links to them. "
	      "<br><b>&lt;unavailable_language&gt;</b> shows the language "
	      "the user wanted, if the page was not available in that "
	      "language. "
	      "<p>All tags take the argument type={txt,img}. ",
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
	 "be used in case the chosen language is unavailable. To find a "
	 "page with a suitable language the languages is tried as follows. "
	 "<ol><li>The selected language, stored as a prestate"
	 "<li>The user agent's accept-headers (ok it doesn't do this at the moment)"
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
	 "<dt>language-code.dir.available.gif"
	 "<dd>Shown as a link to the dir-entry translated to that language."
	 */
	 "</dl>"
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

*/  
  defvar("indexfiles", ({ "index.html", "Main.html", "welcome.html" }), 
	 "Directory index files", 
	 TYPE_STRING_LIST,
	 "If any of these files are present in a directory, they will be "+
	 "returned instead of the actual directory.");
  defvar( "configp", 1, "Use config (uses prestate otherwise).",
          TYPE_FLAG,
          "If set the users chooen language will be stored using Roxens "
          "which in turn will use a Cookie stored in the browser, if "
          "possible. Unfortunatly Netscape may not reload the page when the "
          "language is changed using Cookies, which means the end-users "
          "may have to manually reload to see the page in the new language. "
          "Prestate does not have this problem, but on the other hand "
          "they will not be remembered over sessions." );

  defvar( "textonly", 0, "Text only", TYPE_FLAG,
	  "If set the tags type argument will default to txt instead of img" );
}

mapping parse_directory( object id )
{
  string file;
  mixed result;
  string not_query;

  if (id->not_query[-1] == '.' && id->not_query[-2]=='/')
    return http_redirect(id->not_query[..strlen(id->not_query)-2], id);

  if (id->not_query[-1] != '/')
    return http_redirect(id->not_query+"/", id);

  not_query = id->not_query;
  id->misc[ "index_file" ] = 1;
  foreach (query( "indexfiles" ), file)
  {
    id->not_query = not_query + file;
    result = roxen->get_file( id );
    if (result)
      return result;
  }
  return result;
}

// language part

mapping (string:mixed) language_data = ([ ]);
array (string) language_order = ({ });
#define LANGUAGE_DATA_NAME 0
#define LANGUAGE_DATA_NEXT_LANGUAGE 1
multiset (string) language_list;
string default_language, flag_dir;
int textonly;

mixed fnord(mixed what) { return what; }

void start()
{
  string tmp;
  array (string) tmpl;

  //  key = "file:" + roxen->current_configuration->name;

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
  textonly = query( "textonly" );
  //  flag_dir = query( "flag_dir" );
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
  string chosen_language, prestate_language, extension;
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
    redirect_url = add_pre_state( redirect_url, (id->prestate - language_list)+
				  (< extension >) );
    redirect_url = id->conf->query( "MyWorldLocation" ) +
      redirect_url[1..17000000];
    
    return http_redirect( redirect_url );
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
  if ( accept_language = id->misc["accept-language"] )
    ;
    else
      accept_language = ({ });
  perror("1:%O", accept_language);  
  /*  accept_language &= indices( language_list ); //remove later */
  // This looks funny, but it's nessesary to keep the order of the languages.
  accept_language = accept_language -
    ( accept_language - indices(language_list) );
  perror("2:%O\n", accept_language);

  if (query( "configp" ))
    lang_tmp = language_list & id->config;
  else
    lang_tmp = language_list & id->prestate;

#ifdef MODULE_DEBUG  
  if( sizeof(accept_language) )
    perror("Header-choosen language: %O\n", accept_language[0]);
#endif
  
  if (sizeof( lang_tmp ))
    chosen_language = prestate_language = indices( lang_tmp )[0];
  else if (sizeof( accept_language ))
    chosen_language = accept_language[0];
  else
    chosen_language = default_language;

  if (found_languages[ chosen_language ])
    found_language = chosen_language;
  else if (sizeof( accept_language & indices( found_languages ) ))
    found_language = chosen_language
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
  id->misc[ "chosen_language" ] = chosen_language;
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

string tag_unavailable_language( string tag, mapping m, object id )
{
  if (!id->misc[ "chosen_language" ] || !id->misc[ "language" ]
      || !id->misc[ "language_data" ])
    return "";
  if (id->misc[ "chosen_language" ] == id->misc[ "language" ])
    return "";
  if (m[ "type" ] == "txt" || textonly && m[ "type" ] != "img")
    return id->misc[ "language_data" ][ id->misc[ "chosen_language" ] ];
  else
    return "<img src=" + query( "flag_dir" ) + id->misc[ "chosen_language" ]
            + ".unavailable.gif alt=\""
            + id->misc[ "language_data" ][ id->misc[ "chosen_language" ] ][0]
            + "\">";
}

string tag_language( string tag, mapping m, object id )
{
  if (!id->misc[ "language" ] || !id->misc[ "language_data" ]
      || !id->misc[ "language_list" ])
    return "";
  if (m[ "type" ] == "txt" || textonly && m[ "type" ] != "img")
    return id->misc[ "language_data" ][ id->misc[ "language" ] ][0];
  else
    return "<img src=" + query( "flag_dir" ) + id->misc[ "language" ]
            + ".selected.gif alt=\""
            + id->misc[ "language_data" ][ id->misc[ "language" ] ][0]
            + "\">";
}

string tag_available_languages( string tag, mapping m, object id )
{
  string result, lang;
  int c;
  array available_languages;

  if (!id->misc[ "available_languages" ] || !id->misc[ "language_data" ]
      || !id->misc[ "language_list" ])
    return "";
  result = "";
  available_languages = indices( id->misc["available_languages"] );
  for (c=0; c < sizeof( available_languages ); c++)
  {
    if (query( "configp" ))
      result += "<aconf ";
    else
      result += "<apre ";
    foreach (indices( id->misc[ "language_list" ]
		      - (< available_languages[c] >) ), lang)
      result += "-" + lang + " ";
    if (query( "configp" ))
      result += "+" + available_languages[c]
	 + (id->misc[ "index_file" ] ? " href=\"\" >" : ">");
    else
      result += available_languages[c]
	 + (id->misc[ "index_file" ] ? " href=\"\" >" : ">");
    if (m[ "type" ] == "txt" || textonly && m[ "type" ] != "img")
      result += ""+id->misc[ "language_data" ][ available_languages[c] ][0];
    else
      result += "<img src=" + query( "flag_dir" ) + available_languages[c]
            + ".available.gif alt=\""
  	    + id->misc[ "language_data" ][ available_languages[c] ][0]
            + "\">";
    if (query( "configp" ))
      result += "</aconf>\n";
    else
      result += "</apre>\n";
    }
  return result;
}

mapping query_tag_callers()
{
  return ([ "unavailable_language" : tag_unavailable_language,
            "language" : tag_language,
            "available_languages" : tag_available_languages ]);
}
