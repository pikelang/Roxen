// This is a ChiliMoon module which provides HTML conversion to other formats.
// Copyright (c) 2002-2005, Stephen R. van den Berg, The Netherlands.
//                     <srb@cuci.nl>
//
// This module is open source software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation; either version 2, or (at your option) any
// later version.
//

#define _ok id->misc->defines[" _ok"]

constant cvs_version =
 "$Id: html2x.pike,v 1.1 2004/05/22 17:45:31 _cvs_stephen Exp $";
constant thread_safe = 1;

#include <module.h>
#include <config.h>

inherit "module";


// ---------------- Module registration stuff ----------------

constant module_type = MODULE_TAG;
LocaleString module_name = "Tags: HTML2x";
LocaleString module_doc  =
 "This module provides the HTML2x RXML tags."
 "The conversion is performed using external programs "
 "(w3m, html2ps, ps2pdf, gs).<br />"
 "<p>Copyright &copy; 2002-2005, by "
 "<a href='mailto:srb@cuci.nl'>Stephen R. van den Berg</a>, "
 "The Netherlands.</p>"
 "<p>This module is open source software; you can redistribute it and/or "
 "modify it under the terms of the GNU General Public License as published "
 "by the Free Software Foundation; either version 2, or (at your option) any "
 "later version.</p>";

void create() {
  set_module_creator("Stephen R. van den Berg <srb@cuci.nl>");
  defvar ("w3m", "/usr/bin/w3m",
	"w3m", TYPE_FILE,
        "Path to w3m."
          );
  defvar ("html2ps", "/usr/bin/html2ps",
	"html2ps", TYPE_FILE,
        "Path to html2ps."
          );
  defvar ("ps2pdf", "/usr/bin/ps2pdf",
	"ps2pdf", TYPE_FILE,
        "Path to ps2pdf."
          );
  defvar ("gs", "/usr/bin/gs",
	"gs", TYPE_FILE,
        "Path to GhostScript."
          );
}

static string lastfile;

string status() {
  return "";
}

#define IS(arg)	((arg) && sizeof(arg))

// ------------------- Containers ----------------

static void getfout(object mfifo,object fout,void|int trunc)
{ string res,tmp;
  res="";
  while(tmp=fout->read(trunc),trunc&&strlen(tmp)==trunc)
     res=tmp;
  res+=tmp+fout->read();
  destruct(fout);
  ;{ int i;
     i=strlen(res);
     mfifo->write(trunc&&trunc<i?res[i-trunc..]:res);
   }
}

class TagHtml2x {
  inherit RXML.Tag;
  constant name = "html2x";
  constant flags = RXML.FLAG_DONT_RECOVER;
  mapping(string:RXML.Type) req_arg_types = ([
   //"filename" : RXML.t_text(RXML.PEnt),
  ]);
  mapping(string:RXML.Type) opt_arg_types = ([
   "format" : RXML.t_text(RXML.PEnt),
   "quote" : RXML.t_text(RXML.PEnt),
   "cols" : RXML.t_text(RXML.PEnt),
   "ppc" : RXML.t_text(RXML.PEnt),
   "grayscale" : RXML.t_text(RXML.PEnt),
   "resolution" : RXML.t_text(RXML.PEnt),
  ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      _ok = 1;

      int cols=(int)args->cols||80;
      float ppc=(float)args->ppc||8.0;
      string resolution="high";

      if(args->resolution=="low")
	 resolution=args->resolution;

      if(args->quote=="none")
         result_type=RXML.t_xml;
      else if(args->quote=="html")
         result_type=RXML.t_text;
      else              
         result_type=RXML.t_xml;

      object fin=Stdio.FILE(),fout=Stdio.FILE(),procs;
      ;{ object in=fin->pipe(),out=fout->pipe();
         string html2ps=module::query("html2ps");
         if(args->grayscale)
            html2ps+=" -g";
         putenv("HOME","/dev/null");
         procs=Process.spawn(
          args->format=="pdf"
          ?sprintf("%s 2>/dev/null | %s - -",
           html2ps,module::query("ps2pdf"))
          :args->format=="fax"
          ?sprintf("%s 2>/dev/null "
            "| %s -sDEVICE=dfax%s -sOutputFile=- -dNOPAUSE -q -dSAFER -",
           html2ps,module::query("gs"),resolution)
          :args->format=="postscript"
           ?sprintf("%s 2>/dev/null",html2ps)
     :sprintf("%s -dump -no-cookie -T text/html -cols %d -ppc %f 2>/dev/null |"
            "/bin/sed -e 's/ *$//'",module::query("w3m"),cols,ppc),
          in,out);
         destruct(in);destruct(out);
       }
      array ret=({"","",0});
      object mfifo=Thread.Fifo();
      thread_create(getfout,mfifo,fout);
      if(String.width(content)>8)
         content=string_to_utf8(content);
      fin->write(content);destruct(fin);
      ret[1]=mfifo->read();
      ret[2]=procs->wait();
      _ok=!ret[2];
      result=ret[1];
      return 0;
    }
  }
}

// --------------------- Documentation -----------------------

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"html2x":#"<desc type='cont'><p><short>
 Convert HTML to other formats.</short>
 The conversion is performed using /usr/bin/w3m.</p>
</desc>

<attr name='format' value='ascii|postscript|pdf'>
 <p>Specifies the outputformat. Default is <var>ascii</var>.</p>
</attr>

<attr name='cols' value='int'>
 <p>Specifies the columnwidth to be used. Default is <var>80</var>.</p>
</attr>

<attr name='ppc' value='int'>
 <p>Specifies the number of pixels per character.
  Larger values will make tables narrower. Default is <var>8.0</var>.</p>
</attr>

<attr name='quote' value='html|none'>
 <p>How the content should be quoted.  Default is none.</p>
</attr>

<attr name='grayscale'>
 <p>Convert colour images to grayscale images.</p>
</attr>

<attr name='resolution' value='high|low'>
 <p>Selects the resolution of the fax.  Default is high.</p>
</attr>

",

//----------------------------------------------------------------------

    ]);
#endif
