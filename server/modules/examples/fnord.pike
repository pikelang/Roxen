// This is a small sample module.  It is intended to show a simple example
// of a container.
 
string cvs_version = "$Id: fnord.pike,v 1.3 1996/12/02 04:32:39 per Exp $";
#include <module.h>
inherit "module";
 
 
// Documentation:
 
// The purpose of this module is to allow comments in the SPML source
// that are invisible to average viewers, but can be seen with the
// right magic incantation.  Fnord!  The special text is rendered in
// the "sample" font, if available, which makes it possible for
// someone looking at the mixed output to distinguish text that is for
// public consumption from that which is restricted.
 
// See also <COMMENT> which is similar, but always removes the
// enclosed text.
 
// If you have a section of text (with markup, if desired) that you
// may be planning on adding later, but don't want to generally
// activate (the pointers may not have all been done, yet) you can use
// this.  It has other uses, too.
 
// This is not a secure way to hide text, I would like to see a
// version that requires authentication to turn on the "hidden" text,
// but this simple version does not do that.
 
// To use this in your SPML, enter the "hidden" text between a <FNORD>
// and </FNORD>, you can include any additional markup you desire.
// You may want to have a <P> or two to set it off, or use
// <BLOCKQUOTE> inside.  Here's a simple example:
 
//      The text that everyone sees. <FNORD>With some they
//      don't.</FNORD> And then some they do.
 
// Since the excised text may be part of a sentence flow, its removal
// may disrupt the readability.  In this case an ALT attribute can be
// used on the FNORD to give text for the mundanes to see.  This text
// should not have markup (some kinds might work, but others might
// not).  Here's an example of how that might be used:
 
//      This server <FNORD ALT="provides">will provide, when we
//      actually get to it,</FNORD> complete source for the ...
 
// The way the normally hidden text is made visible is by including
// "fnord" in the prestates (i.e. add "/(fnord)" before the "filename"
// part of the URL).

// Michael A. Patton <map@bbn.com>





// First, check the 'request_id->prestate' multiset for the presence
// of 'fnord'. If it is there, show the contents, otherwise, if there
// is an 'alt' text, display it, if not, simply return an empty string

string tag_fnord(string tag, mapping m, string q, object request_id ) 
{ 
  if (request_id->prestate->fnord)
    return "<SAMP>"+q+"</SAMP>"; 
  else if (m->alt)
    return m->alt;
  else
    return "";
}


// This function is needed in _all_ modules. The first index in the
// resulting array is the type of the module, the second is the 'short name',
// the third is a documentation string, the next is reserved, and the last one
// indiceates wheter or not there can be more than one of this module
// active in any virtual server at any time. If it is 0, there can be more
// than one, othervise not.    This is a 'one of a kind' module, only one
// copy of this module can be included in any virtual server at any time.

array register_module()
{
  return ({ MODULE_PARSER, 
            "Fnord!",
            ("Adds an extra container tag, 'fnord' that's supposed to make "
	     "things invisible unless the \"fnord\" prestate is present."
	      "<p>This module is here as an example of how to write a "
	      "very simple RXML-parsing module."),
            0, 1	     
            });
}
 
// This is nessesary functions for all MODULE_PARSER modules.

mapping query_tag_callers() { return ([]); }
mapping query_container_callers() { return (["fnord":tag_fnord,]); }
 
