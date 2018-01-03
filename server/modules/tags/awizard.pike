// This is a roxen module. Copyright © 1999 - 2009, Roxen IS.
//

inherit "module";
#include <request_trace.h>
#include <module.h>
#include <config.h>

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Tags: Advanced wizards";
constant module_doc  = 
#"Provides the <tt>&lt;awizard&gt;</tt> tag that is used to
create wizard like user interfaces. Each wizard can contain several pages 
with forms. The module handles navigation among the pages, input 
validation and keeps track of all the user's choices, no matter which page
they were made on.";
mapping cache = ([]);
int nid=1;

string store( mapping what )
{
  call_out( m_delete, 60*query("cache_timeout"), cache, (string)nid );
  cache[ (string)nid ] = what;
//   werror("store -> "+nid+"\n");
  return (string)nid++;
}

mapping lookup( string id )
{
//   werror("lookup "+id+"\n");
  return cache[(id/".")[0]];
}

// Advanced wizard

// tags:
//  <awizard title=...>
//  <page [name=...]>
//   <verify>...</verify> --> Will be executed when leaving the page.
//   <button [page=...] [title=...] [image=...]>
//   <ebutton [href=...] [title=...] [image=...]>RXML code to execute when the button is pressed</ebutton>
//   <come-from page=...>RXML to be executed when arriving from page</come-from>
//   <goto page=...>
//   <goto href=...>
//   <warn>string</warn>
//   <notice>string</notice>
//   <error>string</error> (can be used to prevent the user from leaving this page)
//  </page>

class Page
{
  inherit "wizard"; // For 'html_warn' with friends.
  int num, id, button_id, line_offset;
  string name;
  string page;        // RXML code for normal page.
  string verify;     // RXML code for verification.
  mapping come_from = ([ ]);
  mapping button_code;

  string tag_goto(string t, mapping m,  RequestID id)
  {
    if(m->page)
      id->misc->return_me = ([ "page":m->page ]);
    else
      id->misc->return_me = ([ "href":m->href ]);
    return "";
  }

  string tag_wizard_buttons(string t, mapping m, RequestID id)
  {
    return ("<p><table width=100%><tr width=100% >\n"
            "<td  width=50% align=left>"
            "<button prev title=\""+(m->previous||" <- Previous ")+"\">"
            "</td><td width=50% align=left>"
            "<button next title=\""+(m->next||" Next -> ")+"\"></td></tr>\n"
            "</table>");
  }

  mapping make_gbutton_args( mapping from )
  {
    mapping res = ([]);
    foreach( glob( "gbutton-*", indices(from) ), string f )
      res[ f[8..] ] = from[ f ];
    return res;
  }

  string tag_wizard_button(string t, mapping m, RequestID id)
  {
    mapping args = m - (["id": 1, "page": 1, "href": 1, "next": 1, "prev": 1,
			 "image": 1, "gbutton_title": 1, "title": 1]);
    if(m->page)
      args->name  = "goto_page_"+m->page+"/"+m->id;
    else if(m->href)
      args->name  = "goto_href_["+m->href+"]/"+m->id;
    else if(m->next)
    {
      if(!id->misc->next_possible)
        return "";
      args->name  = "goto_next_page/"+m->id;
    }
    else if(m->prev)
    {
      if(!id->misc->prev_possible)
        return "";
      args->name  = "goto_prev_page/"+m->id;
    } else
      args->name = "goto_current_page/"+m->id;
    if(m->image || m->gbutton_title || m["gbutton_title"] )
    {
      args->type = "image";
      if(!m->gbutton_title)
      {
        m->gbutton_title = m["gbutton-title"];
        m_delete( m, "gbutton-title" );
      }
      args->alt  = m->title||m->gbutton_title||m->alt||m->page||"[ "+m->image+" ]";
      args->border="0";
      if( !m->gbutton_title )
        args->src = replace(m->image, ({" ","?"}), ({"%20", "%3f"}));
      else
        args->src = parse_rxml(  make_container( "gbutton-url",
                                                 make_gbutton_args( m ),
                                                 m->gbutton_title ), id );
    } else {
      args->type  = "submit";
      args->value  = m->title||m->page;
    }
    if(m->src)
      args->src = m->src;

    return make_tag("input", args);
  }

  string container_dbutton(string t, mapping m, string c, RequestID id)
  {
    mapping args = m - (["id": 1, "page": 1, "href": 1, "next": 1, "prev": 1,
			 "image": 1, "gbutton_title": 1, "title": 1]);
    if(m->page)
      args->name  = "goto_page_"+m->page+"/"+m->id;
    else if(m->href)
      args->name  = "goto_href_["+m->href+"]/"+m->id;
    else if(m->next)
    {
      if(!id->misc->next_possible)
        return "";
      args->name  = "goto_next_page/"+m->id;
    }
    else if(m->prev)
    {
      if(!id->misc->prev_possible)
        return "";
      args->name  = "goto_prev_page/"+m->id;
    } else
      args->name = "goto_current_page/"+m->id;
    if(m->image || m->gbutton_title || m["gbutton-title"])
    {
      if(!m->gbutton_title)
      {
        m->gbutton_title = m["gbutton-title"];
        m_delete( m, "gbutton-title" );
      }
      args->type = "image";
      args->border="0";
      if( m->gbutton_title )
        args->src = parse_rxml(  make_container( "gbutton-url",
                                                 make_gbutton_args( m ),
                                                 m->gbutton_title ), id );
      else
        args->src = replace(m->image, ({" ","?"}), ({"%20", "%3f"}));
    } else {
      args->type  = "submit";
      args->value  = m->title||m->page;
    }
    args->name += "/eval/"+store( ([ "code": c ]) );
    return make_tag("input", args);
  }

  string container_warn(string t, mapping m, string c, RequestID id)
  {
    return html_warning( c, id );
  }

  string container_notice(string t, mapping m, string c,RequestID id)
  {
    return html_notice( c, id );
  }

  string container_error(string t, mapping m, string c, RequestID id)
  {
    id->variables->error_message = c;
    return c;
  }

  string internal_tag_verify(string t, mapping args, string c)
  {
    verify += c;
    return "";
  }

  string internal_tag_ebutton(string t, mapping m, string c)
  {
    m->id=(string)++button_id;
    button_code[(int)m->id] = c;
    return make_tag("button", m);
  }

  string internal_tag_come_from(string t, mapping args, string c)
  {
    if(!come_from[args->name])
      come_from[args->name] = c;
    else
      come_from[args->name] += c;
    return "";
  }


  void create(mapping m, string from, int bi, mapping bc)
  {
    button_code = bc;
    button_id = bi;

    num =  m->num;
    name = m->name;
    page = parse_html(from, ([ ]), ([
      "verify":internal_tag_verify,
      "ebutton":internal_tag_ebutton,
      "come-from":internal_tag_come_from,
    ]));
  }

  string call_var(string tag, mapping args, RequestID id)
  {
    return wizard_tag_var( tag, args, id );
  }

  string call_cvar(string tag, mapping args, string c, /*int line,
		   mixed foo,*/ RequestID id)
  {
    //id->misc->line = line;
    return wizard_tag_var( tag, args, c, id );
  }

  string eval(string what, RequestID id)
  {
    if(!what) return "";
    id->misc->offset = line_offset;

    id->misc->awizard_page = this_object();
    string res = parse_rxml(what, id);
    m_delete (id->misc, "awizard_page"); // Assuming wizards can't be nested..
    return res;
  }

  mapping|int can_leave(RequestID id, string eeval)
  {
    m_delete(id->variables,"error_message");
    eval(eeval + button_code[ id->misc->button_id ] + verify, id);
    if(id->misc->return_me) return id->misc->return_me;
    return !id->variables->error_message;
  }

  string generate( RequestID id, string header, string footer )
  {
    string contents = eval((come_from[id->last_page]||"")
			   + header
                           + page
                           + footer, id);
    id->variables->error_message=0;
    return contents;
  }
}




class AWizard
{
  inherit "wizard";

  string footer="";
  string header="";
  array pages = ({});
  mapping pages_by_name = ([]);
  int last_page, button_id;

  string internal_tag_header(string t, mapping args, string c)
  {
    header = c;
  }

  string internal_tag_footer(string t, mapping args, string c)
  {
    footer = c;
  }

  string internal_tag_include(string t, mapping args, int l, RequestID id)
  {
    if(args->define)
      return id->misc->defines[args->define]||"";
    string q = id->conf->try_get_file(fix_relative(args->file, id), id);
    return q;
  }

  mapping button_code;
  string internal_tag_page(string t, mapping args, string c, int l,
                           RequestID id)
  {
    //  Replace conflicting tag name "button" in the content to make it local
    //  to this element.
    c = replace(c, ({ "<button", "<rxml:button" }),
		   ({ "<wizard-button", "<rxml:wizard-button" }) );
    args->num = last_page;
    if(!args->name) args->name = (string)last_page;
    pages += ({ Page( args, c, button_id, button_code ) });
    button_id = pages[ -1 ]->button_id;
    pages[ -1 ]->line_offset = (int)id->misc->line + l;
    pages_by_name[ args->name ] = pages[ -1 ];
    last_page++;
  }

  string lc = "";
  void update(string contents, RequestID id)
  {
    if((contents != lc) || id->pragma["no-cache"])
    {
      lc = contents;
      button_code = ([]);
      button_id = 0;
      last_page = 0;
      pages = ({});
      pages_by_name = ([]);
      footer=header="";

      parse_html_lines(parse_html_lines(contents,
                                        ([
                                          "include":internal_tag_include,
                                        ]),
                                        ([
                                          "comment":lambda(){ return ""; },
                                        ]),id),
                       ([]),
                       ([
                         "page":internal_tag_page,
                         "header":internal_tag_header,
                         "footer":internal_tag_footer,
                       ]),id );
      int off = sizeof(header/"\n")-1;
      foreach(pages, object p)
	p->line_offset -= off;
    }
  }

  void create(mapping args, string contents, RequestID id, object p)
  {
    update(contents,id);
  }


  mapping|string handle( RequestID id )
  {
    object|mapping v = id->variables;
    mapping s, error;
    object page, last_page;
    int new_page;
    string contents, goto;
    int cur_page_num = (int) v->_page_num;


    if( v->_____state)
      s = lookup( v->_____state );
    else
      s = ([]);

    if(!s)
      return "State expired from database. Please start over";

    foreach(indices(s), string q)
      v[ q ] = v[ q ]||s[ q ];

    m_delete(v, "_____state");
    id->misc->next_possible = ((int)v->_page_num) < (sizeof(pages)-1);
    id->misc->prev_possible = ((int)v->_page_num) > 0;
    id->misc->_awizard_object = this_object();
    foreach(glob("goto_*", indices(v)), string q)
    {
      goto = q;
      m_delete(v, q);
    }

    if(goto)
    {
      mapping er;

      string extra_eval;
      if(sscanf(goto, "%*s/eval/%s", extra_eval) == 2)
      {
	extra_eval = lookup( extra_eval )->code;
        if(!extra_eval)
          throw(({"Failed to find extra eval in cache\n", backtrace()}));
      }
      last_page = pages[ (int)v->_page_num ];

      if(last_page) v->last_page = last_page->name;
      if(mappingp(er) && !er->page)
	error = er;
      else if(mappingp(er) && er->page)
	new_page = (pages_by_name[ error->page ] &&
		    pages_by_name[ error->page ]->num)+1;
      else if(sscanf(goto, "goto_next_page/%d",id->misc->button_id))
	new_page = ((int)v->_page_num)+2;
      else if(sscanf(goto, "goto_prev_page/%d", id->misc->button_id))
	new_page = ((int)v->_page_num);
      else if(sscanf(goto, "goto_page_%s/%d", goto, id->misc->button_id))
	new_page = pages_by_name[ goto ] && pages_by_name[ goto ]->num+1;
      else if(sscanf(goto, "goto_href_[%s]/%d", goto, id->misc->button_id)) {
        if( last_page && extra_eval )
          last_page->can_leave( id,  extra_eval );
	return http_redirect( fix_relative(goto,id), id );
      }

      if( last_page && last_page->can_leave( id, extra_eval ))
      {
	if(new_page)
	{
	  if(new_page < 1) new_page = 1;
	  if(new_page > sizeof(pages)) new_page = sizeof(pages);
	  v->_page_num = (string)(new_page-1);
	}
      }
    }

    id->misc->next_possible = ((int)v->_page_num) < (sizeof(pages)-1);
    id->misc->prev_possible = ((int)v->_page_num) > 0;
    if((sizeof(pages) <= (int)v->_page_num) ||
       (int)v->_page_num < 0)
      return "No such page";
    page = pages[ (int)v->_page_num ];

    if(!error)
    {
      contents = page->generate( id, header, footer );
      error = id->misc->return_me;
    }

    if(error)
    {
      if(error->page && error->page != page->name &&
	 !(id->misc->awizard_in_error_page &&
	   id->misc->awizard_in_error_page[cur_page_num]))
      {
	v["goto_page_"+error->page+"/0"]=1;
	// The following is a safeguard to prevent infinite recursion
	// if the awizard pages are improperly constructed. This code
	// doesn't work perfectly if <awizard> tags are nested, but
	// it's assumed elsewhere that that never happens.
	if (!id->misc->awizard_in_error_page)
	  id->misc->awizard_in_error_page = (<>);
	id->misc->awizard_in_error_page[cur_page_num] = 1;
	mapping|string res = handle( id );
	id->misc->awizard_in_error_page[cur_page_num] = 0;
	return res;
      } else if(error->href) {
	return http_redirect(fix_relative(error->href,id), id);
      } else if(!error->page)
	return error;
    }

    foreach(glob("goto_*", indices(v)), string nope)  m_delete(v, nope);
    m_delete(v, "_page_num");
    m_delete(v, "_____state");
    return
      ("<form method="+(query("debug")?"get":"post")+
       " action=\""+id->not_query+"\">\n"
       " <input type=hidden name=_page_num value=\""+page->num+"\">\n"
       " <input type=hidden name=_____state value=\""+
       store( v )+"\">\n" + contents + " </form>\n");
  }
}

void create()
{
  defvar("cache_timeout", 60, "Cache timeout", TYPE_INT|VAR_MORE,
	 "Timeout in minutes for the internal state and data cache.");

  defvar("debug", 0, "Debug mode", TYPE_FLAG|VAR_MORE,
	 "Use GET instead of POST in the form, to make debugging easier.");
}


mapping(string:AWizard) wizards = ([]);

#define PROXY_TAG(name)							\
  array|string tag_ ## name (string t, mapping m, RequestID id)	\
  {									\
    if (id->misc->awizard_page)						\
      return id->misc->awizard_page->tag_ ## name (t, m, id);		\
    else								\
      return ({1});							\
  }

#define PROXY_CONTAINER(name)							\
  array|string container_ ## name (string t, mapping m, string c, RequestID id)	\
  {										\
    if (id->misc->awizard_page)							\
      return id->misc->awizard_page->container_ ## name (t, m, c, id);		\
    else									\
      return ({1});								\
  }

PROXY_TAG (goto);
PROXY_TAG (wizard_buttons);
PROXY_TAG (wizard_button);
PROXY_CONTAINER (dbutton);
PROXY_CONTAINER (warn);
PROXY_CONTAINER (notice);
PROXY_CONTAINER (error);

array|string tag_var(string tag, mapping args, RequestID id)
{
  if (id->misc->awizard_page)
    return id->misc->awizard_page->call_var (tag, args, id);
  else
    return ({1});
}

array|string container_cvar(string tag, mapping args, string c, RequestID id)
{
  if (id->misc->awizard_page)
    return id->misc->awizard_page->call_cvar (tag, args, c, id);
  else
    return ({1});
}

mixed container_awizard(string tagname, mapping arguments,
                        string contents, RequestID id)
{
  mixed res;
  
  if(!wizards[id->not_query])
    wizards[ id->not_query ]=AWizard(arguments, contents, id, this_object() );
  else
    wizards[ id->not_query ]->update( contents, id );

  res = wizards[ id->not_query ]->handle( id );

  if(mappingp(res))
  {
    string v = "";
    foreach(indices(res->extra_heads), string i)
      v += "<header name="+i+" value='"+res->extra_heads[i]+"'>";
    return v+"<return code="+res->error+">";
  }
  return ({res});
}

// --------------------- Documentation -----------------------

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"awizard":({#"<desc type='tag'>

</desc>

<attr name='title' value='string'>

</attr>",

(["page":({#"<desc type='tag'>
 Creates a new page in the wizard.
</desc>

<attr name='name' value='string'>
 A name for the page.
</attr>",

(["verify":#"<desc type='cont'>
 RXML code to be executed when leaving the page.
</desc>",

"button":#"<desc type='tag'>
 Creates a button.
</desc>

<attr name='page' value='string'>
 Send the user to this page when the button is pressed.
</attr>

<attr name='title' value='string'>
 Put a name on the button.
</attr>

<attr name='image' value='path'>
 Put an image on the button.
</attr>",

"ebutton":#"<desc type='cont'>
 A more advanced button. When pressed the content of this container
 will be parsed before the user are allowed to leave the page.
</desc>

<attr name='href' value='URL'>
 Send the user to this URL.
</attr>

<attr name='title' value='string'>
 Put a name on the button.
</attr>

<attr name='image' value='path'>
 Put an image on the button.
</attr>",

"come-from-page":#"<desc type='cont'>

</desc>

<attr name='page' value='string'>

</attr>",

"goto":#"<desc type='tag'>

</desc>

<attr name='page' value='string'>

</attr>

<attr name='href' value='URL'>

</attr>",

"warn":#"<desc type='cont'>

</desc>",

"notice":#"<desc type='cont'>

</desc>",

"error":#"<desc type='cont'>

</desc>",])
	 })])
	})]);
#endif



// tags:
//  <awizard title=...>
//  <page [name=...]>
//   <verify>...</verify> --> Will be executed when leaving the page.
//   <button [page=...] [title=...] [image=...]>
//   <ebutton [href=...] [title=...] [image=...]>RXML code to execute when the button is pressed</ebutton>
//   <come-from page=...>RXML to be executed when arriving from page</come-from>
//   <goto page=...>
//   <goto href=...>
//   <warn>string</warn>
//   <notice>string</notice>
//   <error>string</error> (can be used to prevent the user from leaving this page)
//  </page>
