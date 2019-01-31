// This is a Roxen module. Copyright © 1996 - 2009, Roxen IS.
//
// Directory listings mark 3
//
// Per Hedbor 2000-05-16
//
// TODO:
//  o Perhaps add <fl> to default template?
//  o Add readme support
//

//<locale-token project="mod_directories">LOCALE</locale-token>
//<locale-token project="mod_directories">SLOCALE</locale-token>
#define SLOCALE(X,Y)	_STR_LOCALE("mod_directories",X,Y)
#define LOCALE(X,Y)	_DEF_LOCALE("mod_directories",X,Y)
// end locale stuff

constant cvs_version = "$Id$";
constant thread_safe = 1;

constant default_template= #"
<if not='' variable='form.sort'>
  <set variable='form.sort' value='name' />
</if>

<html>
  <head><title>Listing of &page.virtfile;</title></head>
  <body bgcolor='white' text='black' link='#ae3c00' vlink='#ae3c00'>
     <roxen align='right' size='small' />
    <font size='+3'>
   <emit source='path'>
     <a href='&roxen.path;&_.path:http;'> &_.name; <font color='black'>/</font></a>
   </emit> </font><br /><br />
    <table width='100%' cellspacing='0' cellpadding='2' border='0'>
      <tr>
        <td width='100%' height='1' colspan='5' bgcolor='#ce5c00'><img
          src='/internal-roxen-unit' width='100%' height='1' /></td>
      </tr>

    <define tag='mitem'>
      <th ::='&_.args;'>
         <if variable='form.reverse'>
          <cset variable='var.doreverse'>sort-reverse</cset>
          <if match='&form.sort; is &_.order;'>
            <img src='/internal-roxen-up' />
          </if>
          <else>
            <font size='-1'>&nbsp;</font>
          </else>
          <a href='?sort=&_.order;'><font color='black'>&_.title;</font></a> &nbsp;
         </if>
         <else>
         <if match='&form.sort; is &_.order;'>
          <img src='/internal-roxen-down' />
          <a href='?sort=&_.order;&reverse=1'><font color='black'>&_.title;</font></a> &nbsp;
        </if>
        <else>
          <font size='-1'>&nbsp;</font>
          <a href='?sort=&_.order;'><font color='black'>&_.title;</font></a> &nbsp;
        </else>
       </else>
      </th>
    </define>

      <tr bgcolor='#aaaaaa'>
        <th>&nbsp;</th>
        <mitem order='name' title='Name' align='left'/>
        <mitem order='size' title='Size' align='right' />
        <mitem order='type' title='Type' align='right'/>
        <mitem order='modified' title='Last modified' align='right'/>
      </tr>
      <tr>
        <td width='100%' height='1' colspan='5' bgcolor='#ce5c00'><img
          src='/internal-roxen-unit' width='100%' height='1' /></td>
      </tr>

      <emit source='dir'
            directory='&page.virtfile;'
            sort-order='&form.sort;'
            ::='&var.doreverse;'>
        <tr bgcolor='#eeeeee'>
          <td align='left'><a href='&_.name:url;'><img src='&_.type-img;' border='0' /></a></td>
          <td align='left'><a href='&_.name:url;'>&_.name;</a> &nbsp;</td>
          <td align='right'>&_.size; &nbsp;</td>
          <td align='right'>&_.type; &nbsp;</td>
          <td align='right'>&_.mtime; &nbsp;</td>
        </tr>
      </emit>
      <tr>
        <td width='100%' height='4' colspan='5' bgcolor='#ce5c00'><img
          src='/internal-roxen-unit' width='100%' height='1' /></td>
      </tr>
    </table>

  </body>
</html>
";


#include <stat.h>
#include <module.h>
inherit "module";

array(string) readme, indexfiles;
string template;
int override;

constant module_type = MODULE_DIRECTORIES|MODULE_TAG;
LocaleString module_name = LOCALE(1,"Directory Listings");
LocaleString module_doc =
  LOCALE(2,"This module pretty prints a list of files.");

void set_template()
{
  set( "template", default_template );
}

string status()
{
  if( query("default-template") && query("template") != template )
    return 
      LOCALE(3,"The directory list template is not the same as the default "
	     "template, but the default template is used. This might be a "
	     "residue from an old configuration file, or intentional.");
}

mapping query_action_buttons()
{
  if(query("default-template") && query("template") != default_template )
    return ([ LOCALE(4,"Reset template to default")  : set_template ]);
  return ([]);
}

void create()
{
  defvar("indexfiles",
         ({ "index.html", "index.xml", "index.htm", "index.pike",
            "index.cgi" }),
	 LOCALE(5,"Index files"), TYPE_STRING_LIST|VAR_INITIAL,
	 LOCALE(6,"If one of these files is present in a directory, it will "
		"be returned instead of the directory listing."));

  defvar("override", 0, LOCALE(7,"Allow directory index file overrides"),
         TYPE_FLAG,
	 LOCALE(8,"If this variable is set, you can get a listing of all "
		"files in a directory by appending '.' to the directory "
		"name. It is <em>very</em> useful for debugging, but some"
		" people regard it as a security hole."));

  defvar("default-template", 1, LOCALE(9,"Use the default template"),
         TYPE_FLAG,
         LOCALE(10,"If true, use the default directory layout template") );

  defvar("template", default_template, LOCALE(11,"Directorylisting template"),
	 TYPE_TEXT,
         LOCALE(12,"The template for directory list generation."),
	 0,
         lambda(){ return query("default-template"); } );
}

void start(int n, Configuration c)
{
  if( c )
  {
    indexfiles = query("indexfiles")-({""});
    override = query("override");
    if( query("default-template" ) ) {
      template = default_template;
      module_dependencies(c, ({ "rxmltags" }));
    }
    else
      template = query("template");

    if( !(c->enabled_modules["sbtags_2.0#0"] ||
          c->enabled_modules["sitebuilder#0"] ||
          c->enabled_modules["diremit#0"] ) )
        c->add_modules( ({ "diremit#0" }), 1 );
  }
}


mapping parse_directory(RequestID id)
{
  string f = id->not_query;

  // First fix the URL
  //
  // It must end with "/" or "/."

  if (!has_suffix(f, "/") && !has_suffix(f, "/."))
    return Roxen.http_redirect(f+"/", id);

  if(f[-1]=='.' && !override)
    return Roxen.http_redirect(f[..sizeof(f)-2], id);

  // If the pathname ends with '.', and the 'override' variable
  // is set, a directory listing should be sent instead of the
  // indexfile.

  array dir=id->conf->find_dir(f, id, 1)||({});
  if(f[-1] == '/') /* Handle indexfiles */
  {
    // Try index files that are visible in the directory listing first, then
    // fall back to the others (in case the directory isn't fully browsable).
    foreach((indexfiles & dir)|indexfiles, string file)
    {
      array s;
      if((s = id->conf->stat_file(f+file, id)) && (s[ST_SIZE] >= 0))
      {
	id->not_query = f + file;
	mixed got = id->conf->handle_request(id);
	if (got && mappingp(got))
	  return got;
      }
    }
    // Restore the old query.
    id->not_query = f;
  }

  if(!sizeof(dir) || !dir[0])
    foreach(dir[1..], string file) 
    {
      string lock=id->conf->try_get_file(f+file, id);
      if(lock) {
	if(!sizeof(lock)) {
	  lock =
	    "<html><head><title>Forbidden</title></head>\n"
	    "<body><h1>Forbidden</h1></body></html>\n";
	}
	return Roxen.http_string_answer(lock)+(["error":403]);
      }
    }
  return Roxen.http_rxml_answer( template, id );
}
