constant cvs_version="$Id: ximg.pike,v 1.2 1999/05/20 03:26:24 neotron Exp $";
#include <module.h>
inherit "module";
inherit "roxenlib";

// Written by Fredrik Hubinette

array register_module()
{
  return ({ MODULE_PARSER, "Ximg",
	    "This module adds a new tag &lt;ximg&gt; which, when enabled, acts "
	    "like the &lt;img&gt; tag but adds the dimension of the image to the for faster loading. It only works for gif and jpeg images.",0,1 });
}

string tag_ximg(string t, mapping m, mixed id)
{
  string tmp="";
  if(m->src)
  {
    string file;
    if(file=id->conf->real_file(fix_relative(m->src, id), id))
    {
      array(int) xysize;
      if(xysize=Dims.dims()->get(file))
      {
	m->width=(string)xysize[0];
	m->height=(string)xysize[1];
      }else{
	m->err="Dims failed";
      }
    }else{
      m->err="Virtual path failed";
    }
  }
  foreach(indices(m),string s)
    tmp+=sprintf(" %s=\"%s\"",s,m[s]);
  return "<img"+tmp+">";
}

mapping query_tag_callers() { return ([]); }

mapping query_tag_callers()
{
  return ([ "ximg":tag_ximg, ]);
}
