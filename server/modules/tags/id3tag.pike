// This is a roxen module. Copyright 2002, Honza Petrous
//

constant cvs_version="$Id: id3tag.pike,v 1.1 2002/06/12 05:09:42 hop Exp $";
constant thread_safe=1;
#include <module.h>
#include <config.h>

inherit "module";

Configuration conf;
int parsed_ok, parsed_all, parsed_fail, accessed_all;
string last_err;

#define ID3_DEBUG 1
#ifdef ID3_DEBUG
# define ID3_WERR(X) werror("ID3tags: "+X+"\n")
#else
# define ID3_WERR(X)
#endif


// Module interface functions

//constant module_type=MODULE_TAG|MODULE_PROVIDER;
constant module_type=MODULE_TAG;
constant module_name="Icecast: ID3 tag";
constant module_doc  = "This module gives the "
  "<tt>&lt;emit&gt;</tt> plugin (<tt>&lt;emit source=\"id3\" ... &gt;</tt>).\n";


TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"emit#id3": ({ #"<desc type='plugin'><p><short>
Use this source to retrieve metainformation from MP3 files.</short> The
result will be available in variables named as the ID3 tag names.</p>
<p>Note:<br />
The returned entities depend on version of ID3 standard used in file.
Ie. <i>album</i> can be reached as <i>&amp;_.talb;</i> in version 2.4.x
or 2.3.x or as <i>&amp;_.tal;</i> in 2.2.x or as <i>&amp;_.album;</i>
in version 1.0 or 1.1.<br />
So, for convenience, there are provided 'friendly' entities, so the basic
tags are accessible by their 'friendly' names independently from version
of tags in file.</p>
</desc>

<attr name='name' value='name of file' default='none'><p>
Name of file in server's virtual tree.</p>
</attr>

<attr name='realname' value='real name of file' default='none'><p>
Name of file in operation system's filesystem.</p>
</attr>",
([
"&_.title;":#"<desc type='entity'><p>
  Returns the name of song.
  </p></desc>",

"&_.album;":#"<desc type='entity'><p>
  Returns the name of album.
  </p></desc>",

"&_.artist;":#"<desc type='entity'><p>
  Returns the name of artist.
  </p></desc>",

"&_.genre;":#"<desc type='entity'><p>
  Returns the name of genre.
  </p></desc>"
])

})

]);
#endif

// Internal helpers

// -------------------------------- Tag handlers -----------------------------

class TagID3plugin {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "id3";


  array get_dataset(mapping m, RequestID id) {
    mapping sav, rv;
    string key;
    mixed err;

    last_err = 0;
    Stdio.File fd;
    Standards.ID3.Tag tag;

    accessed_all++;
    if(m->name) {
      key = m->name;
      rv = cache_lookup("id3tag_cache", key);
      if(rv)
        return ({ rv });
      [fd,err] = id->conf->open_file( key, "rR", id, 1 );
    } else {
      key = m->realname;
      rv = cache_lookup("id3tag_cache", key);
      if(rv)
        return ({ rv });
      err = catch( fd = Stdio.File(key, "r") );
    }
    parsed_all++;

    if(!fd) {
      //Chyba
      parsed_fail++;
      last_err = sprintf("%O, %O", key, err[0]);
      ID3_WERR(last_err);
      return ({});
    }

    err = catch(tag = Standards.ID3.Tag(fd));
    if(err) {
        catch(fd->close());
        parsed_fail++;
        last_err = sprintf("%O: %O", key, err[0]);
        ID3_WERR(last_err);
        return ({});
      }
    rv = tag->friendly_values() + ([ "version": tag->version ]);
    if(tag->header->major_version == 2)
      rv += (mapping(string:string))mkmapping(tag->frames->id,
      		tag->frames->data->get_string());;

    fd->close();
    parsed_ok++;
    cache_set("id3tag_cache", key, rv, query("ci_timeout"));
    return(({rv}));
 
  }
}


// ------------------------ Setting the defaults -------------------------

void create()
{

  set_module_creator("Honza Petrous <hop@unibase.cz>");

  //defvar
  defvar("ci_timeout", Variable.Int(0, VAR_MORE, "Cache timeout",
         "The time after that the cached values will be timed out."));

}


// --------------------- More interface functions --------------------------

void start(int level, Configuration _conf)
{
  if (_conf)
    conf = _conf;
  parsed_ok = 0;
  parsed_all = 0;
  parsed_fail = 0;
}

string status()
{
  string rv = "";

      rv += "<h2>Parsed files</h2>\n";
      rv += sprintf("<p>OK: %d of %d<br>Failed: %d<br />Accessed: %d</p>\n",
                parsed_ok, parsed_all,
                parsed_fail, accessed_all);
      if(last_err)
        rv += "<br />\n" +
	      "<h2>Latest error</h2>\n" +
	      "<code>"+last_err+"</code><br />\n";

    return rv;
}
