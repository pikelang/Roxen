// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.
// by Mirar <mirar@roxen.com>

// Adds the <sed> tag, to emulate a subset of sed operations in rxml
//
// <sed [suppress] [lines] [chars] [split=<linesplit>]
//      [append] [prepend]>
// <e [rxml]>edit command</e>
// <raw>raw, unparsed data</raw>
// <rxml>data run in rxml parser before edited</rxml>
// <source variable|cookie=name [rxml]>
// <destination variable|cookie=name>
// </sed>
//
// edit commands supported:
// <firstline>,<lastline><edit command>
//    ^^ numeral (17) ^^
//       or relative (+17, -17)
//       or a search regexp (/regexp/)
//       or multiple (17/regexp//regexp/+2)
//
// D                  - delete first line in space
// G                  - insert hold space
// H                  - append current space to hold space
// P                  - print current data
// a<string>          - insert
// c<string>          - change current space
// d                  - delete current space
// h                  - copy current space to hold space
// i<string>          - print string
// l                  - print current space
// p                  - print first line in data
// q                  - quit evaluating
// s/regexp/with/x    - replace
// y/chars/chars/     - replace chars
//
// where line is numeral, first line==1

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>

inherit "module";

mapping flcache=([]);
   // not_query:(flno: 1=fodled 2=unfolded )
int flno=1;
float compat_level;

#define GC_LOOP_TIME QUERY(gc_time)

constant module_type = MODULE_TAG;
constant module_name = "Tags: SED";
constant module_doc =
#"This module provides the <tt>&lt;sed&gt;</tt> tag, that works like the 
Unix sed command.";

array sedreplace(string s,object re,string with,
		 array whatin,int first,int lastmod,
		 multiset flags)
{
   array a;
   string w=0;
   array pr=({});

   if (!(a=re->split(s)))
      return 0;

   if (first)
   {
      array wa;
      wa=sedreplace(a[0],re,with,whatin,first,lastmod,flags);
      if (wa)
	 if (!flags["g"])
	    return ({wa[0],wa[1]+s[strlen(a[0])..]});
	 else
	    pr=wa[0],w=wa[1];
      else
	 w=a[0];
   }

   string t=
      replace(with,whatin[..sizeof(a)-first+lastmod-1],
	      a[first..sizeof(a)+lastmod-1]);

   if (flags["p"]) pr+=({t});

   s=(w||"")+t;
   if (flags["g"])
   {
      if (lastmod)
      {
	 array wa;
	 wa=sedreplace(a[-1],re,with,whatin,first,lastmod,flags);
	 if (wa)
	 {
	    pr+=wa[0];
	    s+=wa[1];
	 }
	 else
	    s+=a[-1];
      }
   }
   else
      s+=a[-1];

   return ({pr,s});
};

array scan_for_linenumber(string cmd,
			  array(string) in,
			  int n)
{
   int x;
   string what;
   object re;

   while (cmd!="" && (cmd[0]>='0' && cmd[0]<='9')
	  || cmd[0]=='/' || cmd[0]=='+' || cmd[0]=='-')
   {
      if (cmd[0]>='0' && cmd[0]<='9')
      {
	 sscanf(cmd,"%d%s",n,cmd);
	 n--;
      }
      else if (cmd[0]=='+')
      {
	 sscanf(cmd,"+%d%s",x,cmd);
	 n+=x;
      }
      else if (cmd[0]=='-')
      {
	 sscanf(cmd,"-%d%s",x,cmd);
	 n-=x;
      }
      else if (sscanf(cmd,"/%s/%s",what,cmd)==2)
      {
	 re=Regexp(what);
	 while (n<sizeof(in))
	 {
	    if (re->match(in[n])) break;
	    n++;
	 }
      }
      else break;
   }
   if (n<0) n=0; else if (n>=sizeof(in)) n=sizeof(in)-1;
   return ({n,cmd});
}

array execute_sed(array(string) e,array(string) in,int suppress)
{
   int start,stop;
   string div,what,with,inflags;
   multiset flags;
   array whatin=({"\\1","\\2","\\3","\\4","\\5","\\6","\\7","\\8","\\9"});
   array print=({});
   array hold=({});
   object re;
   array a1,a2;

   start=0;
   stop=sizeof(in)-1;

   foreach (e, string cmd)
   {
      a1=scan_for_linenumber(cmd,in,start);
      start=a1[0];
      cmd=a1[1];

      if (cmd[0..1]==",$") { cmd=cmd[2..]; stop=sizeof(in)-1; }
      else if (sscanf(cmd,",%s",cmd))
      {
	 a1=scan_for_linenumber(cmd,in,start);
	 stop=a1[0];
	 cmd=a1[1];
      }

      if (stop>sizeof(in)-1) stop=sizeof(in)-1;
      if (start<0) start=0;

      if (cmd=="") continue;
      switch (cmd[0])
      {
	 case 's':
	    div=cmd[1..1];
	    if (div=="%") div="%%";
	    inflags="";
	    if (sscanf(cmd,"%*c"+div+"%s"+div+"%s"+div+"%s",
		       what,with,inflags)<3) continue;
	    flags=aggregate_multiset(@(inflags/""));
	
	    int first=0,lastmod=0;
	    if (what!="") // fix the regexp for working split
	    {
	       if (what[0]!='^') what="^(.*)"+what,first=1;
	       if (what[-1]!='$') what=what+"(.*)$",lastmod=-1;
	    }
	    re=Regexp(what);

	    while (start<=stop)
	    {
	       array sa=sedreplace(in[start],re,with,whatin,
				   first,lastmod,flags);

	       if (sa)
	       {
		  in[start]=sa[1];
		  print+=sa[0];
		  if (compat_level < 5.0 && !flags["g"]) break;
	       }
	       start++;
	    }
	
	    break;

	 case 'y':
	    div=cmd[1..1];
	    if (div=="%") div="%%";
	    inflags="";
	    if (sscanf(cmd,"%*c"+div+"%s"+div+"%s"+div+"%s",
		       what,with,inflags)<3) continue;
	    if (strlen(what)!=strlen(with))
	    {
	       what=what[0..strlen(with)-1];
	       with=with[0..strlen(what)-1];
	    }
	
	    a1=what/"",a2=with/"";

	    while (start<=stop)
	    {
	       in[start]=replace(in[start],a1,a2);
	       start++;
	    }
	    break;

	 case 'G': // insert hold space
	    in=in[..start-1]+hold+in[start..];
	    if (stop>=start) stop+=sizeof(hold);
	    break;

	 case 'a': // insert line
	    in=in[..start-1]+({cmd[1..]})+in[start..];
	    if (stop>=start) stop++;
	    break;

	 case 'c': // change
	    in=in[..start-1]+({cmd[1..]})+in[stop+1..];
	    stop=start;
	    break;

	 case 'd': // delete
	    in=in[..start-1]+in[stop+1..];
	    stop=start;
	    break;

	 case 'D': // delete first line
	    in=in[..start-1]+in[start+1..];
	    stop=start;
	    break;

	 case 'h': // copy
	    hold=in[start..stop];
	    break;

	 case 'H': // appending copy
	    hold+=in[start..stop];
	    break;
	
	 case 'i': // print text
	    print+=({cmd[1..]});
	    break;

	 case 'l': // print space
	    print+=in[start..stop];
	    break;

	 case 'P': // print all
	    print+=in;
	    break;

	 case 'p': // print first
	    print+=in[..0];
	    break;

	 case 'q': // quit
	    if (!suppress) return print+in;
	    return print;

	 default:
	    // error? just ignore for now
      }
   }
   if (!suppress) return print+in;
   return print;
}

string container_sed(string tag,mapping m,string cont,object id)
{
   mapping c=(["e":({})]);
   string|array d;
   compat_level = (float) my_configuration()->query("compat_level");

   parse_html(cont,
	      (["source":lambda(string tag,mapping m,mapping c,object id)
			 {
			    if (m->variable)
			      c->data = RXML_CONTEXT->user_get_var (m->variable) || "";
			    else if (m->cookie) {
			       c->data=id->cookie[m->cookie]||"";
			    } else
			       c->data="";
			    if (m->rxml) c->data=Roxen.parse_rxml(c->data,id);
			 },
		"destination":lambda(string tag,mapping m,mapping c,object id)
			 {
			    if (m->variable) c->destvar=m->variable;
			    else if (m->cookie) c->destcookie=m->cookie;
			    else c->nodest=1;
			 },
	      ]),
	      (["e":lambda(string tag,mapping m,string cont,mapping c,
			   object id)
		    { if (m->rxml) c->e+=({Roxen.parse_rxml(cont,id)});
		       else c->e+=({cont}); },
		"raw":lambda(string tag,mapping m,string cont,mapping c)
		       { c->data=cont; },
		"rxml":lambda(string tag,mapping m,string cont,mapping c,
			      object id)
		       { c->data=Roxen.parse_rxml(cont,id); },
	      ]),c,id);

   if (!c->data) return "<!-- sed command missing data -->";

   d=c->data;

   if (m->split) d/=m->split;
   else if (m->lines) d/="\n";
   else if (m->chars) d/="";
   else d=({c->data});

   d=execute_sed(c->e,d,!!(m->suppress||m["-n"]));

   if (m->split) d*=m->split;
   else if (m->lines) d*="\n";
   else if (m->chars) d*="";
   else d=d*"";

   if (c->destvar)
   {
      if (m->prepend) d += RXML_CONTEXT->user_get_var (c->destvar) || "";
      if (m->apppend || m->append)
	d = (RXML_CONTEXT->user_get_var (c->destvar) || "") + d;
      RXML_CONTEXT->user_set_var (c->destvar, d);
   }
   else if (c->destcookie)
   {
      // Hmm, shouldn't the prepend and append attributes work on the
      // cookie? Looks like a cut'n'paste bug here, but I leave it be
      // for compatibility. /mast
      if (m->prepend) d += RXML_CONTEXT->user_get_var (c->destvar) || "";
      if (m->apppend || m->append)
	d = (RXML_CONTEXT->user_get_var (c->destvar) || "") + d;
      // NOTE: The following line messes up for the protocol cache,
      //       since we have no idea if it overwrites a cookie that
      //       has been used earlier.
      id->cookie[c->destcookie]=d;
   }
   else if (!c->nodest)
      return d;

   return "";
}


TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
  "sed":({ #"<desc type='cont'><p><short>Adds the <tag>sed</tag> tag, to emulate a 
  subset of sed operations in rxml.</short></p></desc>

  <attr name='suppress'></attr>
  <attr name='lines'></attr>
  <attr name='chars'></attr>
  <attr name='split' value='separator'></attr>
  <attr name='append'></attr>
  <attr name='prepend'></attr>

  ", 
       	   (["e":#"<desc type='cont'>
	     <p>The edit command to apply to the input. It is possible to control
	        which lines that will be affected by using 
                <tag>e</tag>[<i>first line</i>],[<i>last line</i>][<i>command</i>]<tag>/e</tag>.
                It is possible to use relative line numbers using '+' and '-' or 
                using regexp by start and end the regexp with '/'</p>
             <p>
<ex>
  <set variable=\"var.foo\">Foo. Foo. Foo. Foo. Foo. Foo. Foo.</set>

  <sed split=\".\">
    <source variable=\"var.foo\" />
    <e>3,+3y/o/u/</e>
  </sed>
</ex>
             </p>
	     <list type=\"dl\">
	       <item name='D'><p>Delete first line in space</p></item>
	       <item name='G'><p>Insert hold space</p></item>
	       <item name='H'><p>Append current space to hold space</p></item>
	       <item name='P'><p>Print current data</p></item>
	       <item name='a'><p>Insert.</p> 
                              <p>Usage: <b>a</b>[<i>string</i>]</p></item>
	       <item name='c'><p>Change current space.</p> 
	                      <p>Usage: <b>c</b>[<i>string</i>]</p></item>
	       <item name='d'><p>Delete current space</p></item>
	       <item name='h'><p>Copy current space to hold space</p></item>
	       <item name='i'><p>Print string</p>
	                      <p>Usage: <b>i</b>[<i>string</i>]</p></item>
	       <item name='l'><p>Print current space</p></item>
	       <item name='p'><p>Print first line in data</p></item>
	       <item name='q'><p>Quit evaluating</p></item>
	       <item name='s'><p>Replace. Replaces the first match on each
                                line unless the flag <i>g</i> is active, in
                                which case all matches will be replaced.
                                In 4.5 and earlier compat mode the
                                replacement will terminate after the first
                                matching line (unless <i>g</i> is active).</p>
	                      <p>Usage: <b>s/</b>[<i>regexp</i>]<b>/</b>[<i>with</i>]<b>/</b>[<i>x</i>]</p></item>
	       <item name='y'><p>Replace chars</p>
	                      <p>Usage: <b>y/</b>[<i>chars</i>]<b>/</b>[<i>chars</i>]<b>/</b></p></item></list></desc>
	     <attr name='rxml'><p>Run through RXML parser before edit</p></attr>"
	   ,
	   "source":#"<desc type='cont'><p>Tells which source to read from if
                        <tag>raw</tag> or <tag>rxml</tag>is not used. Must be 
			either variable or cookie.</p></desc>

			<attr name='variable' value='variable'></attr>
			<attr name='cookie' value='cookie'></attr>
			<attr name='rxml'><p>Run through RXML parser 
			                  before edit</p></attr>",
	   
	   "destination":#"<desc type='cont'><p>Tells which destination to 
                             store the edited string if other than screen. Must
                             be either variable or cookie.</p></desc>

			     <attr name='variable' value='variable'></attr>
			     <attr name='cookie' value='cookie'></attr>",

	   "raw":#"<desc type='cont'><p>Raw, unparsed data.</p></desc>",
	   
	   "rxml":#"<desc type='cont'><p>Data run through RXML parser before 
                      edited.</p></desc>"]),
  }),
]);
#endif
