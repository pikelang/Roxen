// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.
//
inherit "module";

constant cvs_version = "$Id$";
constant thread_safe = 1;
#include <module.h>

#ifdef LANGUAGE_DEBUG
# define LANGUAGE_WERR(X) werror("Language: "+X+"\n")
#else
# define LANGUAGE_WERR(X)
#endif

constant module_type = MODULE_URL | MODULE_TAG;
constant module_name = "DEPRECATED: Language module";
constant module_doc  = "Handles documents in different languages. "
	      "What language a file is in is specified with an "
	      "extra extension. index.html.sv would be a file in swedish "
	      "while index.html.en would be one in english. <b>Note: needs "
              "'Old RXML Compatibility Module' in order for available_languages and "
              "unavailable_language to work.</b> "
	      "<p>The module also defines three new tags. "
	      "<br><b>&lt;language/&gt;</b> that tells which language the "
	      "current page is in. "
	      "<br><b>&lt;available_languages/&gt;</b> gives a list of other "
	      "languages the current page is in, with links to them. "
	      "<br><b>&lt;unavailable_language/&gt;</b> shows the language "
	      "the user wanted, if the page was not available in that "
	      "language. "
              "<p>All tags take the argument type={txt,img}.</p>";
constant module_unique = 1;

void create()
{
  defvar( "default_language",
	  Variable.String( "en", 0, "Default language",
			   "The default language for this server. Is used when trying to "
			   "decide which language to send when the user hasn't selected any. "
			   "Also the language for the files with no language-extension.")
	  );

  defvar( "languages", "en	English\nde	Deutch		en\n"
	  "sv	Svenska		en", "Languages", TYPE_TEXT_FIELD,
	  "The languages supported by this site. One language on each row. "
	  "Syntax: "
	  "<br>language-code language-name optional-next-language-codes"
	  "<br>For example:\n"
	  "<pre>sv	Svenska		en de\n"
	  "en	English		de\n"
	  "de	Deutch		en\n"
	  "</pre><p>"
	  "The next-language-code is used to determine what language should "
	  "be used in case the chosen language is unavailable. To find a "
	  "page with a suitable language the languages is tried as follows. "
	  "<ol><li>The selected language, stored as a prestate"
	  "<li>The user agent's accept-headers"
	  "<li>The selected languages next-languages-codes if any"
	  "<li>The default language"
	  "<li>If there were no selected language, the default language's "
	  "next-language-codes"
	  "<li>All languages, in the order they appear in this text-field"
	  "</ol>"
	  "<p>Empty lines, lines beginning with # or // will be ignored."
	  " Lines with errors may be ignored, or execute a HCF instruction." );

  defvar( "flag_dir", "/icons/", "Flag directory", TYPE_STRING,
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
	  "</dl>"
	  "<p>It is of course not necessary to have all this pictures if "
	  "their use is not enabled in this module nor the header module.</p>" );

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


// language part

mapping (string:mixed) language_data = ([ ]);
array (string) language_order = ({ });
#define LANGUAGE_DATA_NAME 0
#define LANGUAGE_DATA_NEXT_LANGUAGE 1
multiset (string) language_list;
string default_language, flag_dir;
int textonly;

void start()
{
  string tmp;
  array (string) tmpl;

  foreach (query( "languages" ) / "\n", tmp)
    if (strlen( tmp ) > 2 && tmp[0] != '#' && tmp[0..1] != "//")
    {
      tmp = replace( tmp, "\t", " " );
      tmpl = tmp / " " - ({ "" });
      if (sizeof( tmpl ) >= 2)
      {
	language_data[ lower_case(tmpl[0]) ] = ({ tmpl[1], tmpl[2..] });
	language_order += ({ lower_case(tmpl[0]) });
      }
    }
  language_list = aggregate_multiset( @indices( language_data ) );
  foreach (indices( language_data ), tmp)
    language_data[ tmp ][ LANGUAGE_DATA_NEXT_LANGUAGE ] &= indices( language_list );
  default_language = query( "default_language" );
  textonly = query( "textonly" );
}


multiset (string) find_files( string url, RequestID id )
{
  string filename, basename, extension;
  multiset (string) files = (< >);
  multiset result = (< >);
  array tmp;

  filename = reverse( (reverse( url ) / "/")[0] );
  basename = reverse( (reverse( url ) / "/")[1..] * "/" ) + "/";
  tmp = id->conf->find_dir( basename, id );
  if (tmp)
    files = aggregate_multiset( @tmp );
  foreach (indices( language_list ), extension)
    if (files[ filename + "." + extension ])
      result[ extension ] = 1;
  if (files[ filename ])
    result[ "" ] = 1;
  return result;
}

mixed remap_url( RequestID id, string url )
{
  string chosen_language, prestate_language, extension;
  string found_language;
  multiset (string) lang_tmp, found_languages, found_languages_orig;
  array (string) accept_language;

  if(id->misc->language || id->misc->in_language)
    return 0;

  id->misc->in_language=1;

  extension = lower_case(reverse( (reverse( url ) / ".")[0] ));
  if (language_list[ extension ])
  {
    string redirect_url;

    redirect_url = reverse( (reverse( url ) / ".")[1..] * "." );
    if (id->query)
      redirect_url += "?" + id->query;
    redirect_url = Roxen.add_pre_state( redirect_url, (id->prestate - language_list)+
				  (< extension >) );
    redirect_url = id->conf->query( "MyWorldLocation" ) +
      redirect_url[1..];

    id->misc->in_language=0;
    return Roxen.http_redirect( redirect_url );
  }
  found_languages_orig = find_files( url, id );
  found_languages = copy_value( found_languages_orig );
  if (sizeof( found_languages_orig ) == 0)
  {
    id->misc->in_language=0;
    return 0;
  }
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

  LANGUAGE_WERR(sprintf("Wish:%O", accept_language));
  // This looks funny, but it's nessesary to keep the order of the languages.
  accept_language = accept_language -
    ( accept_language - indices(language_list) );
  LANGUAGE_WERR(sprintf("Negotiated:%O\n", accept_language));

  if (query( "configp" ))
    lang_tmp = language_list & id->config;
  else
    lang_tmp = language_list & id->prestate;

#ifdef LANGUAGE_DEBUG
  if( sizeof(accept_language) )
    LANGUAGE_WERR(sprintf("Header-choosen language: %O\n", accept_language[0]));
#endif

  if (sizeof( lang_tmp ))
    chosen_language = prestate_language = indices( lang_tmp )[0];
  else if (sizeof( accept_language ))
    chosen_language = accept_language[0];
  else
    chosen_language = default_language;

  LANGUAGE_WERR(sprintf("Presented language: %O\n", chosen_language));

  if (found_languages[ chosen_language ])
    found_language = chosen_language;
  else if (sizeof( accept_language & indices( found_languages ) ))
    found_language = chosen_language
      = (accept_language & indices( found_languages ))[0];
  else if (prestate_language
	   && sizeof( language_data[ prestate_language ]
		     [ LANGUAGE_DATA_NEXT_LANGUAGE ]
		      & indices( found_languages ) ))
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

  if (found_languages_orig[ found_language ])
    id->extra_extension += "." + found_language;
  // We don't change not_query incase it was a file without
  // extension that were found.

  id->misc->in_language=0;
  return id;
}

string tag_unavailable_language( string tag, mapping m, RequestID id )
{
  if (!id->misc[ "chosen_language" ] || !id->misc[ "language" ]
      || !id->misc[ "language_data" ])
    return "";

  if (id->misc[ "chosen_language" ] == id->misc[ "language" ])
    return "";

  if (m[ "type" ] == "txt" || textonly && m[ "type" ] != "img")
    return id->misc[ "language_data" ][ id->misc[ "chosen_language" ] ];

  return "<img src=\"" + query( "flag_dir" ) + id->misc[ "chosen_language" ]
    + ".unavailable.gif\" alt=\""
    + id->misc[ "language_data" ][ id->misc[ "chosen_language" ] ][0]
    + "\" />";
}

string tag_language( string tag, mapping m, RequestID id )
{
  if (!id->misc[ "language" ] || !id->misc[ "language_data" ]
      || !id->misc[ "language_list" ])
    return "";

  if (m[ "type" ] == "txt" || textonly && m[ "type" ] != "img")
    return id->misc[ "language_data" ][ id->misc[ "language" ] ][0];

  return "<img src=\"" + query( "flag_dir" ) + id->misc[ "language" ]
    + ".selected.gif\" alt=\""
    + id->misc[ "language_data" ][ id->misc[ "language" ] ][0]
    + "\" />";
}

string tag_available_languages( string tag, mapping m, RequestID id )
{
  if (!id->misc[ "available_languages" ] || !id->misc[ "language_data" ]
      || !id->misc[ "language_list" ])
    return "";

  string result="", lang;
  array available_languages = indices( id->misc["available_languages"] );

  for (int c=0; c < sizeof( available_languages ); c++)
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
      result += "<img src=\"" + query( "flag_dir" ) + available_languages[c] +
	".available.gif\" alt=\"" +
	id->misc[ "language_data" ][ available_languages[c] ][0] +
	"\" border=\"0\" />";

    if (query( "configp" ))
      result += "</aconf>\n";
    else
      result += "</apre>\n";
    }

  return result;
}

mapping query_tag_callers() {
  return (["available_language":tag_available_languages,
	   "available_languages":tag_available_languages,
	   "unavailable_languages":tag_unavailable_language,
	   "language":tag_language
  ]);
}
