// This is a roxen module. (c) Informationsvävarna AB 1996.
// $Id: flik.pike,v 1.1 1996/12/11 12:02:13 law Exp $

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

// made by Pontus Hagland <law@infovav.se> december -96

string cvs_version = "$Id: flik.pike,v 1.1 1996/12/11 12:02:13 law Exp $";
#include <module.h>

inherit "module";
inherit "roxenlib";

mapping flcache=([]); 
   // not_query:(flno: 1=fodled 2=unfolded )
int flno=1;

void create()
{
}

array (mixed) register_module()
{
  return ({ MODULE_PARSER, "fliklist", 
	      "Adds the &lt;fl&gt;, &lt;ft&gt; and &lt;fd&gt; tags."
	       " This makes it easy to build a folder list or an outline. "
	       "Example:<pre>"
	       "&lt;fl&gt;\n"
	       "  &lt;ft&gt;ho\n"
	       "   &lt;fd&gt;heyhepp\n"
	       "  &lt;ft&gt;alakazot\n"
	       "   &lt;fd&gt;no more\n"
	       "&lt;/fl&gt;</pre>"});
}

void start()
{
}

string encode_url(object id, 
		  int flno,
		  int dest)
{
   return 
      (id->not_query/"/")[-1]+"?fl="+id->variables->fl
      +"&flc"+flno+"="+dest;
}

string tag_fl_postparse( string tag, mapping m, string cont, object id,
			 object file, mapping defines, object client )
{
   if (!id->variables->fl)
      id->variables->fl=flno++;
   if (!flcache[id->not_query])
      flcache[id->not_query]=([]);
   if (!flcache[id->not_query][id->variables->fl])
      flcache[id->not_query][id->variables->fl]=([]);

   if (id->variables["flc"+m->id])
   {
      perror("change #"+m->id+" to "+(int)id->variables["flc"+m->id]+"\n");
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
	     "<a href="+encode_url(id,m->id,2)+">"
	     "<img width=20 height=20 src=internal-roxen-unfold border=0></a>"+cont;
   }
   else
   {
      return "<!--"+m->id+"-->"
	     "<a href="+encode_url(id,m->id,1)+">"
	     "<img width=20 height=20 src=internal-roxen-fold border=0></a>"
             +cont;
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

string recurse_parse_ftfd(string cont,mapping m,string id);

string tag_fl( string tag, mapping arg, string cont, mapping ma, string id)
{
   mapping m=(["ld":"","t":"","cont":"","count":0]);

   if (objectp(id)) id="";
   else id=((id=="")?"":id+":")+ma->count+":";

   if (!arg->folded) m->folded="unfolded";
   else m->folded="folded";

   recurse_parse_ftfd(cont,m,id);

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

