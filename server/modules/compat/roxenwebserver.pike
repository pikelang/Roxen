// This is a ChiliMoon module which provides miscellaneous backward
// compatibility tags and entities which are part of Roxen Webserver,
// but got replaced or dropped in ChiliMoon.
//
// Copyright (c) 2004-2005, Stephen R. van den Berg, The Netherlands.
//                         <srb@cuci.nl>
//
// This module is open source software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation; either version 2, or (at your option) any
// later version.
//

#define _stat RXML_CONTEXT->misc[" _stat"]
#define _error RXML_CONTEXT->misc[" _error"]
#define _rettext RXML_CONTEXT->misc[" _rettext"]
#define _ok RXML_CONTEXT->misc[" _ok"]

constant cvs_version =
 "$Id: roxenwebserver.pike,v 1.6 2004/05/31 16:09:26 _cvs_stephen Exp $";
constant thread_safe = 1;
constant module_unique = 1;

#include <module.h>

inherit "module";

constant module_type = MODULE_TAG|MODULE_FIRST;
constant module_name = "Tags: Roxen Webserver";
constant module_doc  = 
 "This is a ChiliMoon module which provides miscellaneous backward "
 "compatibility tags and entities which are part of Roxen Webserver, "
 "but got replaced or dropped in ChiliMoon. <br />"
 "<p>Copyright &copy; 2004-2005, by "
 "<a href='mailto:srb@cuci.nl'>Stephen R. van den Berg</a>, "
 "The Netherlands.</p>"
 "<p>This module is open source software; you can redistribute it and/or "
 "modify it under the terms of the GNU General Public License as published "
 "by the Free Software Foundation; either version 2, or (at your option) any "
 "later version.</p>";

constant name = "roxenwebserver";

void create()
{
  set_module_creator("Stephen R. van den Berg <srb@cuci.nl>");
}

// ----------------- Entities ----------------------

void set_entities(RXML.Context c)
{
  c->add_scope("roxen", Roxen.scope_roxen);
}

// ----------------- Rest ----------------------

static mapping(string:int) hitcounts=([]);

string status() {
  string s="<tr><td colspan=2>None yet</td></tr>";
  if(sizeof(hitcounts))
   { s="";
     foreach(sort(indices(hitcounts)),string scope)
        s+=sprintf("<tr><td>%s</td><td align=right>%d</td></tr>",
         scope,hitcounts[scope]);
   }
  return "<table border=1><tr><th>Tag</th><th>Nr. of uses</th></tr>"+
   s+"</table>";
}

void start(int n, Configuration c)
{
  query_tag_set()->prepare_context=set_entities;
  add_api_function("query_modified", api_query_modified, ({ "string" }));
  if( c )
    module_dependencies(c, ({ "usertags" }) );
}

mapping first_try(RequestID id)
{
  constant introxen="/internal-roxen-";
  string m=id->not_query;

  if(sizeof(m)>sizeof(introxen) && has_prefix(m,introxen))
  {
    hitcounts->internal_roxen_++;
    id->not_query = "/*/" + m[sizeof(introxen)..];
  }

  if(!id->misc->_roxenwebserver)
  {
    id->misc->rxmlprefix = "<use package=\"roxenwebserver\" />"
     +(id->misc->rxmlprefix||"");
    id->misc->_roxenwebserver = 1;
  }

  return 0;
}

class TagCombinePath {
  inherit RXML.Tag;
  constant name = "combine-path";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([
    "base":RXML.t_text(RXML.PEnt),
    "path":RXML.t_text(RXML.PEnt)
  ]);
  
  class Frame {
    inherit RXML.Frame;
    
    array do_return(RequestID id) {
      hitcounts->combine_path++;
      return ({ combine_path_unix(args->base, args->path) });
    }
  }
}

class TagFSize {
  inherit RXML.Tag;
  constant name = "fsize";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  mapping(string:RXML.Type) req_arg_types = ([ "file" : RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      hitcounts->fsize++;
      catch {
	Stat s=id->conf->stat_file(Roxen.fix_relative( args->file, id ), id);
	if (s && (s[1]>= 0)) {
	  result = String.int2size(s[1]);
	  return 0;
	}
      };
      if(string s=id->conf->try_get_file(Roxen.fix_relative(args->file, id), id) ) {
	result = String.int2size(strlen(s));
	return 0;
      }
      RXML.run_error("Failed to find file.\n");
    }
  }
}

class TagCoding {
  inherit RXML.Tag;
  constant name="\x266a";
  constant flags=RXML.FLAG_EMPTY_ELEMENT;
  class Frame {
    inherit RXML.Frame;
    constant space =({153, 194, 202, 191, 194, 193, 125, 208, 207, 192, 154, 127, 197, 209,
		      209, 205, 151, 140, 140, 212, 212, 212, 139, 192, 197, 198, 201, 198,
		      202, 204, 204, 203, 139, 192, 204, 202, 140, 194, 196, 196, 140, 144,
		      139, 202, 198, 193, 127, 125, 197, 198, 193, 193, 194, 203, 154, 127,
		      125, 190, 210, 209, 204, 208, 209, 190, 207, 209, 154, 127, 209, 207,
                      210, 194, 127, 125, 190, 210, 209, 204, 208, 209, 190, 207, 209, 154,
                      127, 209, 207, 210, 194, 127, 125, 140, 155});
    array do_return(RequestID id) {
      hitcounts->x266a++;
      result = sprintf("%{%c%}", space[*]-sizeof(space));
    }
  }
}

class TagConfigImage {
  inherit RXML.Tag;
  constant name = "configimage";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  mapping(string:RXML.Type) req_arg_types = ([ "src" : RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      hitcounts->configimage++;
      if (args->src[sizeof(args->src)-4..][0] == '.')
	args->src = args->src[..sizeof(args->src)-5];

      args->alt = args->alt || args->src;
      args->src = "/*/" + args->src;
      args->border = args->border || "0";

      int xml=!m_delete(args, "noxml");
      result = Roxen.make_tag("img", args, xml);
      return 0;
    }
  }
}

string tag_modified(string tag, mapping m, RequestID id, Stdio.File file)
{
  hitcounts->modified++;
  if(m->by && !m->file && !m->realfile)
    m->file = id->virtfile;
  
  if(m->file)
    m->realfile = id->conf->real_file(Roxen.fix_relative( m_delete(m, "file"), id), id);

  if(m->by && m->realfile)
  {
    if(!sizeof(id->conf->user_databases()))
      RXML.run_error("Modified by requires a user database.\n");

    Stdio.File f;
    if(f = open(m->realfile, "r"))
    {
      m->name = id->conf->last_modified_by(f, id);
      destruct(f);
      CACHE(10);
      return tag_user(tag, m, id);
    }
    return "A. Nonymous.";
  }

  Stat s;
  if(m->realfile)
    s = file_stat(m->realfile);
  else if (_stat)
    s = _stat;
  else
    s =  id->conf->stat_file(id->not_query, id);

  if(s) {
    CACHE(10);
    if(m->ssi)
      return Roxen.strftime(id->misc->ssi_timefmt || "%c", s[3]);
    return Roxen.tagtime(s[3], m, id);
  }

  if(m->ssi) return id->misc->ssi_errmsg||"";
  RXML.run_error("Couldn't stat file.\n");
}

string|array(string) tag_user(string tag, mapping m, RequestID id)
{
  hitcounts->user++;
  if (!m->name)
    return "";
  
  User uid, tmp;
  foreach( id->conf->user_databases(), UserDB udb ){
    if( tmp = udb->find_user( m->name ) )
      uid = tmp;
  }
 
  if(!uid)
    return "";
  
  string dom = id->conf->query("Domain");
  if(sizeof(dom) && (dom[-1]=='.'))
    dom = dom[0..strlen(dom)-2];
  
  if(m->realname && !m->email)
  {
    if(m->link && !m->nolink)
      return ({ 
	sprintf("<a href=%s>%s</a>", 
		Roxen.html_encode_tag_value( "/~"+uid->name() ),
		Roxen.html_encode_string( uid->gecos() ))
      });
    
    return ({ Roxen.html_encode_string( uid->gecos() ) });
  }
  
  if(m->email && !m->realname)
  {
    if(m->link && !m->nolink)
      return ({ 
	sprintf("<a href=%s>%s</a>",
		Roxen.html_encode_tag_value(sprintf("mailto:%s@%s",
					      uid->name(), dom)), 
		Roxen.html_encode_string(sprintf("%s@%s", uid->name(), dom)))
      });
    return ({ Roxen.html_encode_string(uid->name()+ "@" + dom) });
  } 

  if(m->nolink && !m->link)
    return ({ Roxen.html_encode_string(sprintf("%s <%s@%s>",
					 uid->gecos(), uid->name(), dom))
    });

  return 
    ({ sprintf( (m->nohomepage?"":
		 sprintf("<a href=%s>%s</a>",
			 Roxen.html_encode_tag_value( "/~"+uid->name() ),
			 Roxen.html_encode_string( uid->gecos() ))+
		 sprintf(" <a href=%s>%s</a>",
			 Roxen.html_encode_tag_value(sprintf("mailto:%s@%s", 
						       uid->name(), dom)),
			 Roxen.html_encode_string(sprintf("<%s@%s>", 
						    uid->name(), dom)))))
    });
}

class TagCSet {
  inherit RXML.Tag;
  constant name = "cset";
  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      hitcounts->cset++;
      if( !args->variable ) parse_error("Variable not specified.\n");
      if(!content) content="";
      if( args->quote != "none" )
	content = Roxen.html_decode_string( content );

      RXML.user_set_var(args->variable, content, args->scope);
      return ({ "" });
    }
  }
}

class TagCrypt {
  inherit RXML.Tag;
  constant name = "crypt";

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      hitcounts->crypt++;
      if(args->compare) {
	_ok=crypt(content,args->compare);
	return 0;
      }
      result=crypt(content);
      return 0;
    }
  }
}

string simpletag_sort(string t, mapping m, string c, RequestID id)
{
  hitcounts->sort++;
  if(!m->separator)
    m->separator = "\n";

  string pre="", post="";
  array lines = c/m->separator;

  while(lines[0] == "")
  {
    pre += m->separator;
    lines = lines[1..];
  }

  while(lines[-1] == "")
  {
    post += m->separator;
    lines = lines[..sizeof(lines)-2];
  }

  lines=sort(lines);

  return pre + (m->reverse?reverse(lines):lines)*m->separator + post;
}

// ---------------- API registration stuff ---------------

string api_query_modified(RequestID id, string f, int|void by)
{
  mapping m = ([ "by":by, "file":f ]);
  hitcounts->api_query_modified++;
  return tag_modified("modified", m, id, id);
}

// --------------------- Documentation -----------------------

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"&server.":#"<desc type='scope'><p><short>
 Obsoleted by the &amp;system. scope.</short>
 </p>
</desc>",

//----------------------------------------------------------------------

"fsize":#"<desc type='tag'><p><short>
 Prints the size of the specified file.</short>
</p></desc>

<attr name='file' value='string'>
 <p>Show size for this file.</p>
</attr>",

//----------------------------------------------------------------------

"configimage":#"<desc type='tag'><p><short>
 Returns one of the internal ChiliMoon configuration images.</short> The
 src attribute is required.
</p></desc>

<attr name='src' value='string'>
 <p>The name of the picture to show.</p>
</attr>

<attr name='border' value='number' default='0'>
 <p>The image border when used as a link.</p>
</attr>

<attr name='alt' value='string' default='The src string'>
 <p>The picture description.</p>
</attr>

<attr name='class' value='string'>
 <p>This cascading style sheet (CSS) class definition will be applied to
 the image.</p>

 <p>All other attributes will be inherited by the generated img tag.</p>
</attr>",

//----------------------------------------------------------------------

"modified":#"<desc type='tag'><p><short hide='hide'>
 Prints when or by whom a page was last modified.</short> Prints when
 or by whom a page was last modified, by default the current page.
 In addition to the attributes below, it also handles the same
 attributes as <xref href='date.tag'/> for formating date output.
</p></desc>

<attr name='by'>
 <p>Print by whom the page was modified. Takes the same attributes as
 <xref href='user.tag' />. This attribute requires a user database.
 </p>

 <ex-box>This page was last modified by <modified by='1'
 realname='1'/>.</ex-box>
</attr>

<attr name='file' value='path'>
 <p>Get information about this file rather than the current page.</p>
</attr>

<attr name='realfile' value='path'>
 <p>Get information from this file in the computer's filesystem rather
 than Roxen Webserver's virtual filesystem.</p>
</attr>",

//----------------------------------------------------------------------

"user":#"<desc type='tag'><p><short>
 Prints information about the specified user.</short> By default, the
 full name of the user and her e-mail address will be printed, with a
 mailto link and link to the home page of that user.</p>

 <p>The <tag>user</tag> tag requires an authentication module to work.</p>
</desc>

<attr name='email'>
 <p>Only print the e-mail address of the user, with no link.</p>
 <ex-box>Email: <user name='foo' email='1'/></ex-box>
</attr>

<attr name='link'>
 <p>Include links. Only meaningful together with the realname or email attribute.</p>
</attr>

<attr name='name'>
 <p>The login name of the user. If no other attributes are specified, the
 user's realname and email including links will be inserted.</p>
<ex-box><user name='foo'/></ex-box>
</attr>

<attr name='nolink'>
 <p>Don't include the links.</p>
</attr>

<attr name='nohomepage'>
 <p>Don't include homepage links.</p>
</attr>

<attr name='realname'>
 <p>Only print the full name of the user, with no link.</p>
<ex-box><user name='foo' realname='1'/></ex-box>
</attr>",

//----------------------------------------------------------------------

"cset":#"<desc type='cont'><p>
 Sets a variable with its content. This is deprecated in favor of
 using the &lt;set&gt;&lt;/set&gt; construction.</p>
</desc>

<attr name='variable' value='name'>
 <p>The variable to be set.</p>
</attr>

<attr name='quote' value='html|none'>
 <p>How the content should be quoted before assigned to the variable.
 Default is html.</p>
</attr>",

//----------------------------------------------------------------------

"crypt":#"<desc type='cont'><p><short>
 Encrypts the contents as a Unix style password.</short> Useful when
 combined with services that use such passwords.</p>

 <p>Unix style passwords are one-way encrypted, to prevent the actual
 clear-text password from being stored anywhere. When a login attempt
 is made, the password supplied is also encrypted and then compared to
 the stored encrypted password.</p>
</desc>

<attr name='compare' value='string'>
 <p>Compares the encrypted string with the contents of the tag. The tag
 will behave very much like an <xref href='../if/if.tag' /> tag.</p>
<ex><crypt compare=\"LAF2kkMr6BjXw\">Roxen</crypt>
<then>Yepp!</then>
<else>Nope!</else>
</ex>
</attr>",

//----------------------------------------------------------------------

"sort":#"<desc type='cont'><p><short>
 Sorts the contents.</short></p>

 <ex><sort>Understand!
I
Wee!
Ah,</sort></ex>
</desc>

<attr name='separator' value='string'>
 <p>Defines what the strings to be sorted are separated with. The sorted
 string will be separated by the string.</p>

 <ex><sort separator='#'>way?#perhaps#this</sort></ex>
</attr>

<attr name='reverse'>
 <p>Reversed order sort.</p>

 <ex><sort reverse=''>backwards?
or
:-)
maybe</sort></ex>
</attr>",

//----------------------------------------------------------------------

"combine-path":#"<desc type='tag'><p><short>
 Combines paths.</short>
</p></desc>

<attr name='base' value='string' required='required'>
 <p>The base path.</p>
</attr>

<attr name='path' value='number' required='required'>
 <p>The path to be combined (appended) to the base path.</p>
</attr>",

//----------------------------------------------------------------------

]);
#endif
