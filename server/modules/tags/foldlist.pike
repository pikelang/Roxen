// This is a roxen module. Copyright © 1999-2000, Roxen IS.
//

constant cvs_version = "$Id: foldlist.pike,v 1.18 2000/04/14 22:52:41 kuntri Exp $";
constant thread_safe=1;

#include <module.h>

inherit "module";
inherit "roxenlib";
inherit "state";

constant module_type = MODULE_PARSER;
constant module_name = "Folding lists";
constant module_doc  = "Provides the &lt;foldlist&gt; tag, which is used to "
"build folding lists. The folding lists work like <tt>&lt;dl&gt;</tt> lists "
"where each item can be folded or unfolded.";

TAGDOCUMENTATION
#ifdef manual
constant tagdoc=([

"foldlist":({#"<desc cont><short>
This tag is used to build folding lists, that are like <dl>
lists, but where each element can be unfolded.</short> The tags used to build
the lists elements are ft and fd.
</desc>

<attr name=unfolded>
Will make all the elements in the list unfolded by default.
</attr>
",

(["ft":({#"<desc cont>
This tag is used within the foldlist tag. The contents of this
container, that is not within an fd, tag will be visible both when the
element is folded and unfolded.

<attr name=folded>
Will make this element folded by default. Overrides an unfolded
attribute set in the foldlist tag.
</attr>

<attr name=unfolded>
Will make this element unfolded by default.
</attr>
",

(["fd":#"<desc cont>
The contents of this container will only be visible when the element
it is written in is unfolded."])
  })])
})]);
#endif

string encode_url(array states, object state, RequestID id){
  string value="";

  foreach(states, int tmp) {
    if(tmp>-1)
      value+=(string)tmp;
    else
      return id->not_query+"?state="+
        state->uri_encode(value);
  }
  return id->not_query+"?state="+
    state->uri_encode(value);
}

//It seems like the fold/unfold images are mixed up.
private string tag_ft(string tag, mapping m, string cont, RequestID id, object state, mapping fl) {
    int index=fl->cnt++;
    array states=copy_value(fl->states);
    if((m->unfolded && states[index]==-1) ||
      states[index]==1) {
        fl->txt="";
        fl->states[index]=1;
        id->misc->foldlist_id=fl->inh+(fl->cnt>10?":":"")+(string)fl->cnt;
        states[index]=0;
	return "<dt><a target=\"_self\" href=\""+
	       encode_url(states,state,id)+
               "\"><img width=\"20\" height=\"20\" "
               "src=\""+(m->unfoldedsrc||fl->ufsrc)+"\" border=\"0\" "
	       "alt=\"-\" /></a>"+
               parse_html(cont,([]),(["fd":
				      lambda(string tag, mapping m, string cont) {
					fl->txt+=parse_rxml(cont,id);
					return "";
				      }
	       ]))+"</dt><dd>"+fl->txt+"</dd>";
    }
    fl->states[index]=0;
    states[index]=1;
    return "<dt><a target=\"_self\" href=\""+
           encode_url(states,state,id)+
           "\"><img width=\"20\" height=\"20\" "
           "src=\""+(m->foldedsrc||fl->fsrc)+"\" border=\"0\" "
	   "alt=\"+\" /></a>"+parse_html(cont,([]),(["fd":""]))+"</dt>";
}

string container_foldlist(string tag, mapping m, string c, RequestID id) {
  array states;
  int fds=sizeof(lower_case(c)/"<fd")-1;

  if(!id->misc->foldlist_id)
    id->misc->foldlist_id="";

  //Make an initial guess of what should be folded and what should not.
  if(m->unfolded)
    states=allocate(fds,1);  //All unfolded
  else if(m->folded)
    states=allocate(fds,0);  //All folded
  else
    states=allocate(fds,-1); //All unknown

  //Register ourselfs as state consumers and incorporate our initial state.
  string fl_name = (m->name || "fl")+fds+(id->misc->foldlist_id!=""?":"+id->misc->foldlist_id:"");
  object state=Page_state(id);
  string state_id = state->register_consumer(fl_name, id);
  if(id->variables->state && !state->uri_decode(id->variables->state))
      RXML.run_error("Error in state.");

  //Get our real state
  array new=(state->get(state_id)||"")/"";
  for(int i=0; i<sizeof(new); i++)
    states[i]=(int)new[i];

  mapping fl=(["states":states,
               "cnt":0,
               "inh":id->misc->foldlist_id,
               "txt":"",
               "fsrc":m->foldedsrc||"/internal-roxen-unfold",
               "ufsrc":m->unfoldedsrc||"/internal-roxen-fold"]);

  //Do the real thing.
  c=parse_html(c,([]),(["ft":tag_ft]),id,state,fl);
  id->misc->foldlist_id=fl->inh;

  return (id->misc->debug?"<!-- "+state_id+" -->":"")+"<dl>"+c+"</dl>\n";
}
