// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.

// Adds the <fl>, <ft> and <fd> tags. This makes it easy to
// build a folder list or an outline. Example:
//
//               <fl>
//                 <ft>ho
//                  <fd>heyhepp
//                 <ft>alakazot
//                  <fd>no more
//               </fl>

// the fl-list can be nestled
// ie <ft>...<fd>...</fd></ft> with implicit end tags

// made by Pontus Hagland december -96

constant cvs_version = "$Id$";
constant thread_safe=1;

#include <module.h>

inherit "module";
inherit "roxenlib";

mapping flcache=([]);
   // not_query:(flno: 1=fodled 2=unfolded )
int flno=1;

#define GC_LOOP_TIME QUERY(gc_time)
void create()
{
   defvar("gc_time", 300, "GC time", TYPE_INT|VAR_MORE,
	 "Time between gc loop. (It doesn't run when nothing to garb, anyway.)");

}


void gc()
{
   mixed m,n;
   int k=0;
   foreach (indices(flcache),m)
   {
      if (equal(({"gc"}),indices(flcache[m])))
	 m_delete(flcache,m);
      else
      {
	 foreach (flcache[m]->gc,n)
	    m_delete(flcache[m],n);
	 k+=sizeof(indices(flcache[m]));
	 flcache[m]->gc=indices(flcache[m])-({"gc"});
      }
   }
   if (k) call_out(gc,GC_LOOP_TIME);
}

constant module_type = MODULE_PARSER;
constant module_name = "Old Folding List Tag";
constant module_doc  = "<h2>Deprecated</h2>"
  "This is the older version of \"Folding list tag\". "
  "Adds the &lt;fl&gt;, &lt;ft&gt; and &lt;fd&gt; tags."
  " This makes it easy to build a folder list or an outline. "
  "Example:<pre>"
  "&lt;fl unfolded&gt;\n"
  "  &lt;ft folded&gt;ho\n"
  "   &lt;fd&gt;heyhepp\n"
  "  &lt;ft&gt;alakazot\n"
  "   &lt;fd&gt;no more\n"
  "&lt;/fl&gt;</pre>";

string encode_url(object id,
		  int flno,
		  int dest)
{
  string url = (id->not_query/"/")[-1]+"?fl="+id->variables->fl
    +"&flc"+flno+"="+dest;
  foreach(indices(id->variables), string var)
    if(var != "fl" && var[..2] != "flc" && stringp(id->variables[var]))
      url += sprintf("&%s=%s", http_encode_url(var),
		     http_encode_url(id->variables[var]));
  return url+"#fl_"+flno;
}

string tag_fl_postparse( string tag, mapping m, string cont, object id,
			 object file, mapping defines, object client )
{
   if (!id->variables->fl)
      id->variables->fl=flno++;
   if (!flcache[id->not_query])
   {
      if (-1==find_call_out(gc))
	 call_out(gc,GC_LOOP_TIME);
      flcache[id->not_query]=(["gc":({})]);
   }
   flcache[id->not_query]->gc-=({id->variables->fl});
   if (!flcache[id->not_query][id->variables->fl])
      flcache[id->not_query][id->variables->fl]=([]);

   if (id->variables["flc"+m->id])
   {
      flcache[id->not_query][id->variables->fl][m->id]=
	 (int)id->variables["flc"+m->id];
   }
   else if (!flcache[id->not_query][id->variables->fl][m->id])
   {
      if (m->unfolded)
	 flcache[id->not_query][id->variables->fl][m->id]=2;
      else
	 flcache[id->not_query][id->variables->fl][m->id]=1;
   }

   if (m->title)
   if (flcache[id->not_query][id->variables->fl][m->id]==1)
   {
      return "<!--"+m->id+"-->"
	     "<a name=\"fl_"+m->id+"\" target=\"_self\" href=\""+
	     encode_url(id,m->id,2)+"\">"
	     "<img width=\"20\" height=\"20\" src=\"internal-roxen-unfold\" border=\"0\" "
	     "alt=\"--\" /></a>"+cont;
   }
   else
   {
      return "<!--"+m->id+"-->"
	     "<a name=\"fl_"+m->id+"\" target=\"_self\" href=\""+
	     encode_url(id,m->id,1)+"\">"
	     "<img width=\"20\" height=\"20\" src=\"internal-roxen-fold\" border=\"0\" "
	     "alt=\"\/\" /></a>"+cont;
   }
   else
   if (flcache[id->not_query][id->variables->fl][m->id]==1)
   {
      return "<!--"+m->id+"-->"+"";
   }
   else
   {
      return "<!--"+m->id+"-->"+cont;
   }
}

RoxenModule rxml_warning_cache;
void old_rxml_warning(RequestID id, string no, string yes) {
  if(!rxml_warning_cache) rxml_warning_cache=my_configuration()->get_provider("oldRXMLwarning");
  if(!rxml_warning_cache) return;
  rxml_warning_cache->old_rxml_warning(id, no, yes);
}

string tag_fl( string tag, mapping arg, string cont,
	       object ma, string id, mapping defines)
{
   mapping m=(["ld":"","t":"","cont":"","count":0]);

   if (defines && defines[" fl "]) m=defines[" fl "];

   if (objectp(id)) id="";
   else id=((id=="")?"":id+":")+ma->count+":";

   if (!arg->folded) m->folded="unfolded";
   else m->folded="folded";

   recurse_parse_ftfd(cont,m,id);

   if (defines) defines[" fl "]=m;

   old_rxml_warning(ma, "fl tag ","foldlist");
   return "<dl>"+m->cont+"</dl>";
}

string recurse_parse_ftfd(string cont,mapping m,string id)
{
   return parse_html(cont,([]),
		(["ft":
		  lambda(string tag,mapping arg,string cont,mapping m,string id)
		  {
		     string t,fold;
		     int kinc=m->inc;
		     int me;
		     m->cont="";
		     me=++m->count;
		     t=recurse_parse_ftfd(cont,m,id);

		     if (arg->folded) fold="folded";
		     else if (arg->unfolded) fold="unfolded";
		     else fold=m->folded;

		     m->cont=
			"\n<dt><fl_postparse title "+fold
			+" id="
                        +((id=="")?(string)me:(id+me))+">"
                        +t+"</fl_postparse>"
                        +m->ld
                        +m->cont;
		     m->ld="";
		     m->inc=kinc+1;
		     return "";
		  },
		  "fd":
		  lambda(string tag,mapping arg,string cont,mapping m,string id)
		  {
		     m->ld=
                        "\n<fl_postparse contents id="
                        +((id=="")?(string)m->count:(id+m->count))+">"
			+"<dd>"
			+recurse_parse_ftfd(cont,m,id)
			+"</fl_postparse>"
                        +m->ld;

		     return "";
		  },
		  "fl":tag_fl]),m,id);
}

mapping query_container_callers()
{
  return ([ "fl" : tag_fl,
	    "fl_postparse" : tag_fl_postparse]);
}

