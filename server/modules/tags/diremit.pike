#include <module.h>
#include <stat.h>
inherit "module";
constant module_type = MODULE_TAG;
constant module_name = "Dir emit source";
constant module_doc = "This module provies the 'dir' emit source.";

class TagDirectoryplugin
{
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "dir";

  array get_dataset(mapping args, RequestID id)
  {
    // Now..
    string d;
    if( args->directory )
      d = Roxen.fix_relative( args->directory, id );
    else
      d = dirname(id->not_query);

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
        m->size = Roxen.sizetostring( st[ ST_SIZE ] );
        m["type-img"] = Roxen.image_from_type( m->type );
      }

      if( opt["real-file"] )
      {
        string file = m->path;
        foreach( id->conf->location_modules( ), mixed tmp )
        {
          if(!search(file, tmp[0]))
          {
#ifdef MODULE_LEVEL_SECURITY
            if(id->conf->check_security(tmp[1], id))
              continue;
#endif
            string s;
            if(s=function_object(tmp[1])->real_file(file[strlen(tmp[0])..],id))
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
	  if( args["thumbnail-format"] == "jpeg" )
	    cia["jpeg-quality"] = "40";
          m->thumbnail = 
                       Roxen.parse_rxml( RXML.t_xml->format_tag( "cimg-url",
                                                                 cia ), id );
        } else
          m->thumbnail = m["type-img"];

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
    }
    res = Array.sort_array( res, sortfun );
    if( args["sort-reverse"] )
      res = reverse( res );
    return res;
  }
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([

"emit#dir":({ #"<desc plugin='plugin'><p><short>
 This plugin is used to generate directory listings.</short> The
 directory module must be added to use these entities. This plugin
 is only available in the directory template.
</p></desc>

<attr name='directory' value='path'><p>
 Apply the listing to this directory.</p>
</attr>

<attr name='options' value='(real-file,thumbnail,imagesize)'><p>
 Use these options to customize the directory listings. These argument
 have been made options due to them demanding a lot of raw computing
 power, since they involve image manipulation and other demanding
 tasks. These options can be combined.</p>

<xtable>
<row><c>real-file</c><c>Makes it possible to show the absolute
location of the file including the filename from an 'outside Roxen' view.</c></row>
<row><c>thumbnail</c><c>Makes it possible to use image thumbnails in a
directory listing. Note: Remember that some imageformats needs heavy
computations to generate thumbnails. <ext>tiff</ext> for instance
needs to unpack its image to be able to resolve the image's height and
width. </c></row> <row><c>imagesize</c><c>Makes it able to show the
image's height and width in a directory listing. Note: Remember that
some imageformats needs heavy computations to generate thumbnails.
<ext>tiff</ext> for instance needs to unpack its image to be able to
resolve the image's height and width.</c></row>
</xtable>
</attr>

<attr name='thumbnail-size' value='number'><p>
 Sets the size of the thumbnail. Defaultsize is 60 pixels. The size is
 set in proportion to the image's longest side, e.g. if the height of
 the image is longer than it's width, then the thumbnail will be 60
 pixels high. The shortest side will be shown in proportion to the
 longest side. This attribute can only be used together with the
 <att>option=\"thumbnail\"</att> attribute.</p>
</attr>

<attr name='thumbnail-format' value='imageformat'><p>
 Set the output format for the thumbnail. Default is <ext>png</ext>.
 All imageformats that <xref href='../graphics/cimg.tag' /> handles can
 be used to produce thumbnails. This attribute can only be used
 together with the <att>option=\"thumbnail\"</att> attribute.</p>
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
<row><c>alpha</c><c>Sort files and directories alphabetically.</c></row>
<row><c>dwim</c><c>Sort files and directories by \"Do What I (want) Method\". In many methods numeriacal sorts fail as the number '10' often appears before '2'. This method sorts numerical characters first then alphabetically, e.g. 1foo.html, 2foo.html, 10foo.html, foo1.html, foo2.html, foo10.html.</c></row>
<row><c>modified</c><c>Sort files by modification date.</c></row>
<row><c>size</c><c>Sort files by size.</c></row>
<row><c>type</c><c>Sort files by content-type.</c></row>
</xtable>
</attr>

<attr name='sort-reversed'><p>
 Reverse the sort order.</p>
</attr>",

([
"&_.atime;":#"<desc ent='ent'><p>
  Returns the date when the file was last accessed.
</p></desc>",

"&_.atime-iso;":#"<desc ent='ent'><p>
 Returns the date when the file was last accessed. Uses isotime
 (%Y-%m-%d).
</p></desc>",

"&_.atime-unix;":#"<desc ent='ent'><p>
 Returns the date when the file was last accessed. Uses unixtime.
</p></desc>",

"&_.dirname;":#"<desc ent='ent'><p>
 Returns the directoryname.
</p></desc>",

"&_.filename;":#"<desc ent='ent'><p>
 Returns the filename.
</p></desc>",

"&_.type-img;":#"<desc ent='ent'><p>
 Returns the internal Roxen name of the icon representating the
 directory or the file's content-type, e.g. internal-gopher-menu for a
 directory-folder or internal-gopher-text for a HTML-file.
</p></desc>",

"&_.mode;":#"<desc ent='ent'><p>
 Returns file permission rights represented binary, e.g. \"r-xr-xr-x\".
</p></desc>",

"&_.mode-int;":#"<desc ent='ent'><p>
 Returns file permission rights represented by integers. When encoded to
 binary this represents what is shown when using the Unix command \"ls
 -l\" or as shown using <ent>_.mode</ent>, e.g. \"16749\".
</p></desc>",

"&_.mtime;":#"<desc ent='ent'><p>
 Returns the date when the file was last modified.
</p></desc>",

"&_.mtime-iso;":#"<desc ent='ent'><p>
 Returns the date when the file was last modified. Uses isotime (%Y-%m-%d).
</p></desc>",

"&_.mtime-unix;":#"<desc ent='ent'><p>
 Returns the date when the file was last modified. Uses unixtime.
</p></desc>",

"&_.name;":#"<desc ent='ent'><p>
 Returns the name of the file or directory.
</p></desc>",

"&_.path;":#"<desc ent='ent'><p>
 Returns the path to the file or directory.
</p></desc>",

"&_.size;":#"<desc ent='ent'><p>
 Returns a file's size in kb(kilobytes).
</p></desc>",

"&_.filesize;":#"<desc ent='ent'><p>
 Returns a file's size in bytes. Directories get the size \"-2\".
</p></desc>",

"&_.type;":#"<desc ent='ent'><p>
 Returns the file's content-type.
</p></desc>",

"&_.thumbnail;":#"<desc ent='ent'><p>
 Returns the image associated with the file's content-type or
 directory. Only available when <att>option=\"thumbnail\"</att> is
 used.
</p></desc>",

"&_.x-size;":#"<desc ent='ent'><p>
 Returns the width of the image. Only available when
 <att>option=\"imagesize\"</att> is used.
</p></desc>",

"&_.y-size;":#"<desc ent='ent'><p>
 Returns the height of the image. Only available when
 <att>option=\"imagesize\"</att> is used.
</p></desc>",
])
		 })
]);
#endif
