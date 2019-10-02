// This is a roxen module. Copyright © 1999 - 2009, Roxen IS.
//

constant cvs_version = "$Id$";
constant thread_safe = 1;

#include <module.h>
inherit "module";

constant module_type = MODULE_TAG;
constant module_name = "Tags: Folding lists";
constant module_doc  = "Provides the &lt;foldlist&gt; tag, which is used to "
"build folding lists. The folding lists work like <tt>&lt;dl&gt;</tt> lists "
"where each item can be folded or unfolded.";

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([

"foldlist":({#"<desc type='cont'><p><short hide='hide'>
 This tag is used to build folding lists, that are like &lt;dl&gt; lists,
 but where each element can be unfolded.</short>This tag is used to
 build folding lists, that are like <tag>dl</tag> lists, but where
 each element can be unfolded. The tags used to build the lists
 elements are <tag>ft</tag> and <tag>fd</tag>.</p></desc>

<attr name='unfolded'><p>
 Will make all the elements in the list unfolded by default.</p>
</attr>

<attr name='foldedsrc'><p>
 The image to use for folded items. The default is '/internal-roxen-unfold'.</p>
</attr>

<attr name='unfoldedsrc'><p>
 The image to use for unfolded items. The default is '/internal-roxen-fold'.</p>
</attr>",

([ "ft":({#"<desc type='cont'><p>
This tag is used within the foldlist tag. The contents of this
container, that is not within an fd, tag will be visible both when the
element is folded and unfolded.</p></desc>

<attr name='folded'><p>
 Will make this element folded by default. Overrides an unfolded
 attribute set in the foldlist tag.</p>
</attr>

<attr name='unfolded'><p>
 Will make this element unfolded by default.</p>
</attr>

<attr name='foldedsrc'><p>
 The image to use for folded items. Overrides the 'foldedsrc'
 attribute in <tag>tablist</tag> for this item.</p>
</attr>

<attr name='unfoldedsrc'><p>
 The image to use for unfolded items. Overrides the 'foldedsrc'
 attribute in <tag>tablist</tag> for this item.</p>
</attr>",

([ "fd":#"<desc type='cont'><p>
 The contents of this container will only be visible when the element
 it is written in is unfolded.</p>
</desc>

<ex>
 <foldlist>
   <ft>
     Heading1
     <fd>Contents 1</fd>
   </ft>
   <ft>
     Heading2
     <fd>Contents 2</fd>
   </ft>
 </foldlist>
</ex>" ])
  })])
})]);
#endif


string encode_url(array states, RequestID id){
  object state=id->misc->foldlist->state;

  int value, q;
  foreach(states, int tmp) {
    value+=tmp*(2->pow(q));
    q+=2;
  }
  value=(value<<1)+1;

  return state->encode_revisit_url (id, value);
}

class TagFoldlist {
  inherit RXML.Tag;
  constant name = "foldlist";

  class TagFD {
    inherit RXML.Tag;
    constant name = "fd";

    class Frame {
      inherit RXML.Frame;
      int show;

      array do_enter(RequestID id) {
	show=id->misc->foldlist_show;
	if(show)
	  do_iterate=0;
	else
	  do_iterate=-1;
	return 0;
      }

      int do_iterate;

      array do_return(RequestID id) {
	if(show)
	  result="<dt><dd>"+content+"</dd></dt>";
	else
	  result="";
	return 0;
      }
    }
  }

  class TagFT {
    inherit RXML.Tag;
    constant name = "ft";

    class Frame {
      inherit RXML.Frame;
      int index, show;

      int set_def(RequestID id) {
	if (args->unfold)
	  return 1;
	if (args->fold)
	  return 0;
	return id->misc->foldlist->def;
      }

      array do_enter(RequestID id) {
	index=id->misc->foldlist->counter++;
	if(sizeof(id->misc->foldlist->states)>index)
	  switch(id->misc->foldlist->states[index]) {
	  case 0:
	    show = set_def(id);
	    break;
	  case 1:
	    show = 0;
	    break;
	  case 2:
	    show = 1;
	    break;
	  }
	else {
	  id->misc->foldlist->states+=({ 0 });
	  show=set_def(id);
	}
	id->misc->foldlist_show=show;
	return 0;
      }

      array do_return(RequestID id) {
	array states=copy_value(id->misc->foldlist->states);
	states[index]=!show+1;
	result="<dt><a target=\"_self\" href=\""+
	  encode_url(states, id)+
	  "\"><img src=\""+
	  (args[(show?"un":"")+"foldedsrc"]||id->misc->foldlist[(show?"u":"")+"fsrc"])+
	  "\" border=\"0\" alt=\""+({ "+", "-" })[show]+"\" /></a>"+
	  content+"</dt>";
	return 0;
      }

    }
  }

  // This tag set can probably be shared, but I don't know for sure. /mast
  RXML.TagSet internal = RXML.TagSet(this_module(), "foldlist", ({ TagFT(), TagFD() }) );

  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags = internal;

    mapping foldlist;
    string state_id;

    array do_enter(RequestID id) {

      // The initial state
      int def=!!args->unfolded;

      // Find out environment
      foldlist=id->misc->foldlist;
      string hist="";
      if(foldlist && foldlist->hist) {
	hist=foldlist->hist;
	if(foldlist->cnt > 15) hist+=":";
	hist+=sprintf("%x",foldlist->cnt);
      }
      else
	id->misc->foldlist_depth++;

      // Register ourselfs as state consumers and incorporate our initial state.
      state_id = (args->name || "fl")+":"+id->misc->foldlist_depth+":"+hist;
      StateHandler.Page_state state=StateHandler.Page_state(id);
      state_id = state->register_consumer(state_id);
      if(id->real_variables->__state && !state->uri_decode(id->real_variables->__state[0]))
	RXML.run_error("Error in state.");

      //Get our real state
      // 00 unknown
      // 01 folded
      // 10 unfolded
      array(int) states=({});
      int istates=state->get();
      //      werror("istates: %d\n",istates);
      if(istates)
	istates=istates>>1;
      while(istates) {
	states+=({ istates & 3 });
	istates=istates >> 2;
      }
      while(sizeof(states) && states[-1]==0)
	states=states[..sizeof(states)-2];

      // Export our findings
      id->misc->foldlist=(["states":states,
			   "state":state,
			   "def":def,
			   "cnt":0,
			   "hist":hist,
			   "fsrc":args->foldedsrc||"/internal-roxen-unfold",
			   "ufsrc":args->unfoldedsrc||"/internal-roxen-fold"
      ]);
      return 0;
    }

    array do_return(RequestID id) {
      id->misc->foldlist=foldlist;
      result = (id->misc->debug?"<!-- "+state_id+" -->\n":"")+
	"<dl>"+content+"</dl>\n";
      m_delete(id->misc, "foldlist_show");
      return 0;
    }

  }
}
