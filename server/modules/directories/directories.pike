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

constant cvs_version = "$Id: directories.pike,v 1.64 2000/05/17 04:32:02 per Exp $";
constant thread_safe = 1;

#include <stat.h>
inherit "module";

array(string) readme, indexfiles;

constant module_type = MODULE_DIRECTORIES | MODULE_PARSER;
constant module_name = "Directory Listings";
constant module_doc = "This module pretty prints a list of files.";

void create()
{
  defvar("indexfiles",
         ({ "index.html", "index.xml", "index.htm", "index.pike",
            "index.cgi" }),
	 "Index files", TYPE_STRING_LIST|VAR_INITIAL,
	 "If one of these files is present in a directory, it will "
	 "be returned instead of the directory listing.");

// defvar("Readme", ({ "README.html", "README" }),
// "Include readme files", TYPE_STRING_LIST|VAR_INITIAL,
// "Include one of these readme files, if present, in directory listings");

  defvar("override", 0, "Allow directory index file overrides", 
         TYPE_FLAG|VAR_INITIAL,
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
  indexfiles = query("indexfiles")-({""});
  if( query("default-template" ) )
    set( "template", 
         #"
<html>
  <head><title>Listing of $DIR$</title></head>
  <body bgcolor='white' text='black' link='#ae3c00' vlink='#ae3c00'>
     <roxen align='right' size='small' />
    <h1>Directory listing of $DIR$</h1>
    <table width='100%' cellspacing='0' cellpadding='2' border='0'>
      <tr>
        <td width='100%' height='1' colspan='5' bgcolor='#ce5c00'><img 
          src='/internal-roxen-unit' width='100%' height='1' /></td>
      </tr>
      <tr bgcolor='#eeeeee'>
        <th align=left>&nbsp;</th>
        <th align=left><a href='?sort=name'>Filename</a></th>
        <th align=right><a href='?sort=size'>Size</a></th>
        <th align=right><a href='?sort=type'>Type</a></th>
        <th align=right><a href='?sort=modified'>Last modified</a></th>
      </tr>
      <tr>
        <td width='100%' height='1' colspan='5' bgcolor='#ce5c00'><img 
          src='/internal-roxen-unit' width='100%' height='1' /></td>
      </tr>
      <emit source='directory' directory='$DIR$' sort-order='&form.sort;'>
        <tr>
          <td align=left><a href='&_.path;'><img src='&_.icon;' border='0' /></a></td>
          <td align=left><a href='&_.path;'>&_.name;</a></td>
          <td align=right>&_.size;</td>
          <td align=right>&_.type;</td>
          <td align=right>&_.mtime;</td>
        </tr>
      </emit>
      <tr>
        <td width='100%' height='4' colspan='5' bgcolor='#ce5c00'><img 
          src='/internal-roxen-unit' width='100%' height='1' /></td>
      </tr>
    </table>

  </body>
</html>
");


}


local static array(mapping) get_directory_dataset( mapping args, RequestID id )
{
  // Now..

  string d = Roxen.fix_relative( args->directory, id ); 

  mapping a = id->conf->find_dir_stat( d, id );

  if( !a || !sizeof(a) )
    return ({});

  multiset opt = mkmultiset( (args->options||"")/"," - ({""}) );

  mapping get_datum( string file )
  {
    array st = a[ file ];

    mapping m = 
    ([
      "name":file,
      "filename":file,
      "dirname":d,
      "path":combine_path( d, file ),
      "atime-unix":st[ ST_ATIME ],
      "mtime-unix":st[ ST_MTIME ],
      "mtime-iso":Roxen.strftime( "%Y-%m-%d", st[ST_MTIME] ),
      "atime-iso":Roxen.strftime( "%Y-%m-%d", st[ST_ATIME] ),
      "mode-int":st[ ST_MODE ],
      "size-int":st[ ST_SIZE ],
      "mode":(Roxen.decode_mode( st[ ST_MODE ] )/"<tt>")[-1]-"</tt>",
    ]);

    if( args->timeformat )
    {
      m["mtime"] = Roxen.strftime( args->timeformat, st[ ST_MTIME ] );
      m["atime"] = Roxen.strftime( args->timeformat, st[ ST_ATIME ] );
    }  else {
      m->mtime = m["mtime-iso"];
      m->atime = m["atime-iso"];
    }

    if( st[ ST_SIZE ] < 0 )
    {
      m->size = "0";
      m->type = "directory";
      m["size"] = "";
      m->icon = "internal-gopher-menu";
    } else {
      m->type = id->conf->type_from_filename( file );
      m->size = Roxen.sizetostring( st[ ST_SIZE ] );
      m->icon = Roxen.image_from_type( m->type );
    }

    if( opt["real-file"] )
    {
      string file = m->path;
      foreach( id->conf->location_modules( id ), mixed tmp )
      {
        if(!search(file, tmp[0]))
        {
#ifdef MODULE_LEVEL_SECURITY
          if(id->conf->check_security(tmp[1], id)) 
            continue;
#endif
          string s;
          if(s=function_object(tmp[1])->real_file(file[strlen(tmp[0])..], id))
          {
            m["real-filename"] = s;
            m["real-dirname"]  = dirname( s );
            m["vfs"] = function_object(tmp[1])->module_identifier();
            m["vfs-root"] = function_object(tmp[1])->real_file( "", id );
            break;
          }
        }
      }
      if( !m["real-file"] )
      {
        m["real-file"] = id->conf->real_file( m->path, id );
        if( m["real-file"] )
          m["real-dirname"] = dirname( m["real-file"] );
      }
    }

    if( opt->thumbnail )
      if( (m->type / "/") [ 0 ]  == "image" )
      {
         string ms = (args["thumbnail-size"]?args["thumbnail-size"]:"60");
         mapping cia = ([
           "max-width":ms,
           "max-height":ms,
           "src":m->path,
           "format":(args["thumbnail-format"]?args["thumbnail-format"]:"png"),
         ]);
         m->thumbnail = Roxen.parse_rxml( Roxen.make_tag( "cimg-url", cia ), id );
      } else
        m->thumbnail = m->icon;

    if( opt->imagesize )
      if( (m->type / "/") [ 0 ]  == "image" )
      {
        switch( (m->type / "/") [ -1 ] )
        {
         case "gif":
         case "jpeg":
         case "jpg":
           catch 
           {
             object fd = id->conf->open_file( m->path, "r", id )[0];
             array xy = Dims.dims()->get( fd );
             m["x-size"] = xy[0];
             m["y-size"] = xy[1];
           };
           break;
         default:
           catch 
           {
             Image.Image i = roxen.load_image( m->path,id );
             m["x-size"] = (string)i->xsize();
             m["y-size"] = (string)i->ysize();
           };
        }
        if( !m["x-size"] )
          m["x-size"] = m["y-size"] = "?";
      }

    return m;
  };

  int sortfun( mapping a, mapping b )
  {
    switch( args["sort-order"] )
    {
     case "modified":
       return a["mtime-unix"] < b["mtime-unix"];

     case "type":
       if( a->type > b->type )
         return 1;
       if( a->type == b->type )
         return Array.dwim_sort_func( a->name, b->name );
       return 0;

     case "size":
       if( a["size-int"] < b["size-int"] )
         return 1;
       if( a->size == b->size )
         return Array.dwim_sort_func( a->name, b->name );
       return 0;

     case "alpha":
       return a->name > b->name;

     case "dwim":
     default: // dwimsort
       return Array.dwim_sort_func( a->name, b->name );
    }
  };

  array files = indices( a );
  if( args->glob )
  {
    array tmp = ({});
    foreach( args->glob/",", string g )
      tmp |= glob( g, files );
    files = tmp;
  }
  array res = map( files, get_datum );
  if( args["type-glob"] )
  {
    array tmp = ({});
    foreach( res, mapping a )
    {
      foreach( args["type-glob"]/",", string g )
        if( glob( g, a->type ) )
        {
          tmp += ({ a });
          break;
        }
    }
  }
  res = Array.sort_array( res, sortfun );
  if( args["sort-reverse"] )
    res = reverse( res );
  return res;
}

class TagDirectoryplugin 
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "directory";

  array get_dataset(mapping m, RequestID id) 
  {
    return get_directory_dataset(m, id);
  }
}

string|mapping parse_directory(RequestID id)
{
  string f = id->not_query;
  // First fix the URL
  //
  // It must end with "/" or "/."

  if(f == "" )
    return Roxen.http_redirect(id->not_query + "/", id);

  if(f[-1]!='/' && f[-1]!='.') 
    return Roxen.http_redirect(f+"/", id);

  if(f[-1]=='.' && query("override")) 
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

  return Roxen.http_rxml_answer(replace(query("template"),
                                        "$DIR$",id->not_query ), id);
}
