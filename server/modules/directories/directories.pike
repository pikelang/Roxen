// This is a Roxen module. Copyright © 1996 - 2000, Roxen IS.
//
// Directory listings mark 3
//
// Per Hedbor 2000-05-16
//
// TODO:
//  o Perhaps add <fl> to default template?
//  o Add readme support
//  o More stuff in the emit variables
//

constant cvs_version = "$Id: directories.pike,v 1.82 2000/09/19 08:38:52 per Exp $";
constant thread_safe = 1;

#include <stat.h>
#include <module.h>
inherit "module";

array(string) readme, indexfiles;
string template;
int override;

constant module_type = MODULE_DIRECTORIES;
constant module_name = "Directory Listings";
constant module_doc = "This module pretty prints a list of files.";

void set_template()
{
  set( "template", template );
}

string status()
{
  if( query("default-template") && query("template") != template )
    return 
#"The directory list template is not the same as the default template, but
  the default template is used. This might be a residue from an old configuration
  file, or intentional.";
}

mapping query_action_buttons()
{
  if(query("default-template") && query("template") != template )
    return ([ "Reset template to default"  : set_template ]);
  return ([]);
}

void create()
{
  defvar("indexfiles",
         ({ "index.html", "index.xml", "index.htm", "index.pike",
            "index.cgi" }),
	 "Index files", TYPE_STRING_LIST|VAR_INITIAL,
	 "If one of these files is present in a directory, it will "
	 "be returned instead of the directory listing.");

  defvar("override", 0, "Allow directory index file overrides",
         TYPE_FLAG,
	 "If this variable is set, you can get a listing of all files "
	 "in a directory by appending '.' to the directory name. It is "
	 "<em>very</em> useful for debugging, but some people regard "
	 "it as a security hole.");

  defvar("default-template", 1, "Use the default template",
         TYPE_FLAG,
         "If true, use the default directory layout template" );

  defvar("template", "", "Directorylisting template", TYPE_TEXT,
         "The template for directory list generation.", 0,
         lambda(){ return query("default-template"); } );
}

void start(int n, Configuration c)
{
  if( c )
  {
    indexfiles = query("indexfiles")-({""});
    override = query("override");
    if( query("default-template" ) )
      template =
#"
<if not='' variable='form.sort'>
  <set variable='form.sort' value='name' />
</if>

<html>
  <head><title>Listing of &page.virtfile;</title></head>
  <body bgcolor='white' text='black' link='#ae3c00' vlink='#ae3c00'>
     <roxen align='right' size='small' />
    <font size='+3'>
   <emit source='path'>
     <a href='&_.path;'> &_.name; <font color='black'>/</font></a>
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
          <td align='left'><a href='&_.path;'><img src='&_.type-img;' border='0' /></a></td>
          <td align='left'><a href='&_.path;'>&_.name;</a> &nbsp;</td>
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
    else
      template = query("template");

    if( !(c->enabled_modules["sitebuilder_tags#0"] ||
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

  if(f == "" )
    return Roxen.http_redirect(id->not_query + "/", id);

  if(f[-1]!='/' && f[-1]!='.')
    return Roxen.http_redirect(f+"/", id);

  if(f[-1]=='.' && override)
    return Roxen.http_redirect(f[..sizeof(f)-2], id);

  // If the pathname ends with '.', and the 'override' variable
  // is set, a directory listing should be sent instead of the
  // indexfile.

  if(f[-1] == '/') /* Handle indexfiles */
  {
    foreach(indexfiles, string file)
    {
      array s;
      if((s = id->conf->stat_file(f+file, id)) && (s[ST_SIZE] > 0))
      {
	id->not_query = f + file;
	mapping got = id->conf->get_file(id);
	if (got)
	  return got;
      }
    }
    // Restore the old query.
    id->not_query = f;
  }

  array dir=id->conf->find_dir(f, id, 1)||({});
  if(!sizeof(dir) || !dir[0])
    foreach(dir[1..], string file) 
    {
      string lock=id->conf->try_get_file(f+file, id);
      if(lock) 
      {
	if(sizeof(lock)) 
          return Roxen.http_string_answer(lock)+(["error":403]);
	return Roxen.http_redirect(f[..sizeof(f)-3], id);
      }
    }
  return Roxen.http_rxml_answer( template, id );
}

