// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.

#include <module.h>
#include <stat.h>
inherit "module";
constant module_type = MODULE_TAG;
constant module_name = "Tags: Dir emit source";
constant module_doc = "This module provies the 'dir' emit source. It "
  "or another compatible module is required by the Directory Listings module";

class Imagesize(mapping m, RequestID id) {
  inherit RXML.Value;
  int x,y;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    string|array(string) ct = m->type;
    if (arrayp(ct))
      ct = ct[0];
    if( !x && !y && (ct / "/")[0] == "image" ) {
      switch( (ct / "/")[-1] ) {
      case "gif":
      case "jpeg":
      case "jpg":
      case "png":
	catch {
	  object fd = id->conf->open_file( m->path, "r", id )[0];
	  array xy = Dims.dims()->get( fd );
	  x = (int)xy[0];
	  y = (int)xy[1];
	};
	break;
      default:
	catch {
	  Image.Image i = roxen.load_image( m->path,id );
	  m["x-size"] = i->xsize();
	  m["y-size"] = i->ysize();
	};
      }
    }
    if(!x || !y) return ENCODE_RXML_TEXT("?", type);
    return ENCODE_RXML_INT(var=="x-size"?x:y, type);
  }
}

class Realfile(mapping m, RequestID id) {
  inherit RXML.Value;
  mapping n;

  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    if(!n) {
      n = ([]);
      string file = m->path;
      foreach( id->conf->location_modules(), mixed tmp ) {
	if(!search(file, tmp[0])) {
#ifdef MODULE_LEVEL_SECURITY
	  if(id->conf->check_security(tmp[1], id))
	    continue;
#endif
	  string s;
	  if(s=function_object(tmp[1])->real_file(file[strlen(tmp[0])..],id)) {
	    n["real-filename"] = s;
	    n["real-dirname"]  = dirname( s );
	    n["vfs"] = function_object(tmp[1])->module_identifier();
	    n["vfs-root"] = function_object(tmp[1])->real_file( "", id );
	    break;
	  }
	}
      }
      if(!n["real-filename"]) {
	n["real-filename"] = id->conf->real_file( m->path, id );
	if( n["real-filename"] )
	  n["real-dirname"] = dirname( n["real-filename"] );
      }
    }
    return ENCODE_RXML_TEXT(n[var], type);
  }
}

class Thumbnail(mapping m, mapping args, RequestID id) {
  inherit RXML.Value;

  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    string|array(string) ct = m->type;
    if (arrayp(ct))
      ct = ct[0];
    if( (ct / "/")[0] == "image" ) {
      string ms = (args["thumbnail-size"]?args["thumbnail-size"]:"60");
      mapping cia = ([
	"max-width":ms,
	"max-height":ms,
	"src":m->path,
	"format":(args["thumbnail-format"]?args["thumbnail-format"]:"png"),
      ]);
      if( args["thumbnail-format"] == "jpeg" )
	cia["jpeg-quality"] = "40";
      return ENCODE_RXML_TEXT( Roxen.parse_rxml( RXML.t_xml->
						 format_tag( "cimg-url",
							     cia ), id ), type);
    }
    return ENCODE_RXML_TEXT(m["type-img"], type);
  }
}

class TagWSDirectoryplugin
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "ws-dir";

  array get_dataset(mapping args, RequestID id)
  {
    string d;
    if( args->directory )
      d = Roxen.fix_relative( args->directory, id );
    else
      d = dirname(id->not_query);

    // FIXME: We could be smarter here and add a stat callback on the
    // directory, but it's a bit of work to find out where it comes
    // from.
    NOCACHE();

    mapping a = id->conf->find_dir_stat( d, id );

    if( !a || !sizeof(a) )
      return ({});

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
                "filesize":st[ ST_SIZE ],
                "mode":(Roxen.decode_mode( st[ ST_MODE ] )/"<tt>")[-1]-"</tt>",
              ]);

      if( args->strftime )
      {
        m["mtime"] = Roxen.strftime( args->strftime, st[ ST_MTIME ] );
        m["atime"] = Roxen.strftime( args->strftime, st[ ST_ATIME ] );
      }  else {
        m->mtime = m["mtime-iso"];
        m->atime = m["atime-iso"];
      }

      if( st[ ST_SIZE ] < 0 )
      {
        m->size = "0";
        m->type = "directory";
        m["size"] = "";
        m["type-img"] = "internal-gopher-menu";
      } else {
        m->type = id->conf->type_from_filename( file );
	if (arrayp(m->type))
	  m->type = m->type[0];
        m->size = Roxen.sizetostring( st[ ST_SIZE ] );
        m["type-img"] = Roxen.image_from_type( m->type );
      }

      m["real-filename"] = m["real-dirname"] = m["vfs"] =
	m["vfs-root"] = Realfile(m, id);
      m->thumbnail = Thumbnail(m, args, id);
      m["x-size"] = m["y-size"] = Imagesize(m, id);

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
         if( a->filesize < b->filesize )
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
    if( args->type )
    {
      array tmp = ({});
      foreach( res, mapping a )
      {
        foreach( args->type/",", string g )
          if( glob( g, a->type ) )
          {
            tmp += ({ a });
            break;
          }
      }
    res = tmp;
    }
    res = Array.sort_array( res, sortfun );
    if( args["sort-reverse"] )
      res = reverse( res );
    return res;
  }
}

class TagDirectoryplugin
{
  inherit TagWSDirectoryplugin;
  constant plugin_name = "dir";

  array get_dataset(mapping args, RequestID id)
  {
    foreach(tagset->get_overridden_tags("emit#dir"), RXML.Tag t)
      if(t && t->sb_dir)
	return t->get_dataset(args, id) || ({});
    return ::get_dataset (args, id);
  }
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([

"emit#dir":({ #"<desc type='plugin'><p><short>
 This plugin is used to generate directory listings.</short> The
 directory module must be added to use these entities. This plugin
 is only available in the directory template.
</p></desc>

<attr name='directory' value='path'><p>
 List this directory. The default is to list the directory containing
 the currently requested page.</p>
</attr>

<attr name='thumbnail-size' value='number'><p>
 Sets the size of the thumbnail. Defaultsize is 60 pixels. The size is
 set in proportion to the image's longest side, e.g. if the height of
 the image is longer than it's width, then the thumbnail will be 60
 pixels high. The shortest side will be shown in proportion to the
 longest side.</p>
</attr>

<attr name='thumbnail-format' value='imageformat'><p>
 Set the output format for the thumbnail. Default is <ext>png</ext>.
 All imageformats that <xref href='../graphics/cimg.tag' /> handles can
 be used to produce thumbnails.</p>
</attr>

<attr name='strftime' value='strftime string' default='%Y-%m-%d'><p>
 Format the date according to this string. Default is the isotime
 format (%Y-%m-%d), which will return (Year(four characters)-month(two
 characters)-day(two characters)), e.g. 2000-11-22. See the attribute
 <att>strftime</att> in <xref href='../information/date.tag' /> for a
 full listing of available formats.</p>
</attr>

<attr name='glob' value='glob-pattern1[,glob-pattern2,...]'><p>
 Only show files matching the glob-pattern.</p>
</attr>

<attr name='type' value='glob-pattern1[,glob-pattern2,...]'><p>
 Only show files which content-type matches the glob-pattern.</p>
</attr>

<attr name='sort-order' value='alpha|dwim|modified|size|type' default='dwim'><p>
 Sort the files and directories by this method.</p>
<xtable>
<row><c><p>alpha</p></c><c><p>Sort files and directories alphabetically.</p></c></row>
<row><c><p>dwim</p></c><c><p>Sort files and directories by \"Do What I (want) Method\". In many methods numeriacal sorts fail as the number '10' often appears before '2'. This method sorts numerical characters first then alphabetically, e.g. 1foo.html, 2foo.html, 10foo.html, foo1.html, foo2.html, foo10.html.</p></c></row>
<row><c><p>modified</p></c><c><p>Sort files by modification date.</p></c></row>
<row><c><p>size</p></c><c><p>Sort files by size.</p></c></row>
<row><c><p>type</p></c><c><p>Sort files by content-type.</p></c></row>
</xtable>
</attr>

<attr name='sort-reverse'><p>
 Reverse the sort order.</p>
</attr>",

([
"&_.atime;":#"<desc type='entity'><p>
  Returns the date when the file was last accessed.
</p></desc>",

"&_.atime-iso;":#"<desc type='entity'><p>
 Returns the date when the file was last accessed. Uses isotime
 (%Y-%m-%d).
</p></desc>",

"&_.atime-unix;":#"<desc type='entity'><p>
 Returns the date when the file was last accessed. Uses unixtime.
</p></desc>",

"&_.dirname;":#"<desc type='entity'><p>
 Returns the directoryname.
</p></desc>",

"&_.filename;":#"<desc type='entity'><p>
 Returns the filename.
</p></desc>",

"&_.type-img;":#"<desc type='entity'><p>
 Returns the internal Roxen name of the icon representating the
 directory or the file's content-type, e.g. internal-gopher-menu for a
 directory-folder or internal-gopher-text for a HTML-file.
</p></desc>",

"&_.mode;":#"<desc type='entity'><p>
 Returns file permission rights represented binary, e.g. \"r-xr-xr-x\".
</p></desc>",

"&_.mode-int;":#"<desc type='entity'><p>
 Returns file permission rights represented by integers. When encoded to
 binary this represents what is shown when using the Unix command \"ls
 -l\" or as shown using <ent>_.mode</ent>, e.g. \"16749\".
</p></desc>",

"&_.mtime;":#"<desc type='entity'><p>
 Returns the date when the file was last modified.
</p></desc>",

"&_.mtime-iso;":#"<desc type='entity'><p>
 Returns the date when the file was last modified. Uses isotime (%Y-%m-%d).
</p></desc>",

"&_.mtime-unix;":#"<desc type='entity'><p>
 Returns the date when the file was last modified. Uses unixtime.
</p></desc>",

"&_.name;":#"<desc type='entity'><p>
 Returns the name of the file or directory.
</p></desc>",

"&_.path;":#"<desc type='entity'><p>
 Returns the path to the file or directory.
</p></desc>",

"&_.real-dirname;":#"<desc type='entity'><p>
 Returns the directory of the real file in the filesystem.
</p></desc>",

"&_.real-filename;":#"<desc type='entity'><p>
 Returns the path to the real file in the filesystem.
</p></desc>",

"&_.size;":#"<desc type='entity'><p>
 Returns a file's size in kb(kilobytes).
</p></desc>",

"&_.filesize;":#"<desc type='entity'><p>
 Returns a file's size in bytes. Directories get the size \"-2\".
</p></desc>",

"&_.type;":#"<desc type='entity'><p>
 Returns the file's content-type.
</p></desc>",

"&_.thumbnail;":#"<desc type='entity'><p>
 Returns the image associated with the file's content-type or
 directory.
</p></desc>",

"&_.vfs;":#"<desc type='entity'><p>
 Returns the name of the virtual filesystem that keeps the file.
</p></desc>",

"&_.vfs-root;":#"<desc type='entity'><p>
 Returns the root directory of the virtual filesystem that keeps the file.
</p></desc>",

"&_.x-size;":#"<desc type='entity'><p>
 Returns the width of the image.
</p></desc>",

"&_.y-size;":#"<desc type='entity'><p>
 Returns the height of the image.
</p></desc>",
])
	   }),

"emit#ws-dir": #"<desc type='plugin'><p><short>
 Alias for the \"dir\" emit source that lists directories.</short>
 This can be used in case the WebServer \"dir\" plugin has been
 overridden. See <xref href='emit_dir.tag'/> for full documentation.
</p></desc>",
]);
#endif
