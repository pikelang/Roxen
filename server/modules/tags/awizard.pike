inherit "module";
#include <module.h>
#include <config.h>

constant cvs_version="$Id: awizard.pike,v 1.2 1999/11/02 01:38:47 per Exp $";
constant thread_safe=1;

array register_module()
{
  return ({ MODULE_PARSER,
	    "Advanced wizards",
	    "Generic wizard module",
	    0, 1 });
}

mapping cache = ([]);
int nid=1;

string store( mapping what )
{
  call_out( m_delete, 3600*1, cache, (string)nid );
  cache[ (string)nid ] = what;
  return (string)nid++;
}

mapping lookup( string id )
{
  return cache[id];
}

// Advanced wizard

// tags:
//  <store title=...>
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
  mapping my_tags, my_containers;
  int num, id, button_id, line_offset;
  string name;
  string page;        // RXML code for normal page.
  string verify;     // RXML code for verification.
  mapping come_from = ([ ]);
  mapping button_code;

  void init_tags()
  {
    my_tags = ([]);
    my_containers = ([]);
    foreach(glob("tag_*", indices(this_object())), string i)
      my_tags[ replace(i-"tag_", "_", "-") ] = this_object()[ i ];
    foreach(glob("container_*", indices(this_object())), string i)
      my_containers[ replace(i-"container_","_","-") ] = this_object()[ i ];
  }

  string tag_goto(string t, mapping m, int q, int w, object id)
  {
    if(m->page)
      id->misc->return_me = ([ "page":m->page ]);
    else
      id->misc->return_me = ([ "href":m->href ]);
    return "";
  }

  string tag_wizard_buttons(string t, mapping m, int q, int w, object id)
  {
    return ("<p><table width=100%><tr width=100% >\n"
            "<td  width=50% align=left>"
            "<button prev title=\""+(m->previous||" <- Previous ")+"\">"
            "</td><td width=50% align=left>"
            "<button next title=\""+(m->next||" Next -> ")+"\"></td></tr>\n"
            "</table>");
  }

  string tag_button(string t, mapping m, int q, int w, object id)
  {
    mapping args = ([]);
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
    if(m->image) {
      args->type = "image";
      args->alt  = m->title||m->alt||m->page||"[ "+m->image+" ]";
      args->border="0";
      args->src = replace(m->image, ({" ","?"}), ({"%20", "%3f"}));
    } else {
      args->type  = "submit";
      args->value  = m->title||m->page;
    }
    if(m->src)
      args->src = m->src;

    return make_tag("input", args);
  }

  string container_dbutton(string t, mapping m, string c, int q, int w, 
                           object id)
  {
    mapping args = ([]);
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
    if(m->image) {
      args->type = "image";
      args->border="0";
      args->src = replace(m->image, ({" ","?"}), ({"%20", "%3f"}));
    } else {
      args->type  = "submit";
      args->value  = m->title||m->page;
    }
    args->name += "/eval/"+store( ([ "code": c ]) );
    return make_tag("input", args);
  }

  string container_warn(string t, mapping m, string c, int q, int w, object id)
  {
    return html_warning( c, id );
  }

  string container_notice(string t, mapping m, string c, int q, int w, object id)
  {
    return html_notice( c, id );
  }

  string container_error(string t, mapping m, string c, int q, int w, object id) 
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
    init_tags();

    num =  m->num;
    name = m->name;
    page = parse_html(from, ([ ]), ([
      "verify":internal_tag_verify,
      "ebutton":internal_tag_ebutton,
      "come-from":internal_tag_come_from,
    ]));
  }

  string call_var(string tag, mapping args, int line, mixed foo, object id)
  {
    id->misc->line = line;
    return wizard_tag_var( tag, args, id );
  }

  string call_cvar(string tag, mapping args, string c, int line, 
		   mixed foo, object id)
  {
    id->misc->line = line;
    return wizard_tag_var( tag, args, c, id );
  }

  string eval(string what, object id)
  {
    if(!what) return "";
    id->misc->offset = line_offset;
    foreach(indices(my_tags), string s)
      id->misc->_tags[ s ] = my_tags[ s ];
    foreach(indices(my_containers), string s)
      id->misc->_containers[ s ] = my_containers[ s ];
    id->misc->_tags["var"] = call_var;
    id->misc->_containers["cvar"] = call_cvar;

    return parse_rxml(what, id);
  }

  mapping|int can_leave(object id, string eeval)
  {
    m_delete(id->variables,"error_message");
    eval(eeval + button_code[ id->misc->button_id ] + verify, id);
    if(id->misc->return_me) return id->misc->return_me;
    return !id->variables->error_message;
  }

  string generate( object id, string header, string footer )
  {
    string contents = eval((come_from[id->last_page]||"")
			   + header 
                           + page 
                           + footer, id);
    id->variables->error_message=0;
    return contents;
  }
}




class Store
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

  string internal_tag_include(string t, mapping args, int l, object id)
  {
    if(args->define) return id->misc->defines[args->define]||"";
    string q = id->conf->try_get_file(fix_relative(args->file, id), id);
    return q;
  }

  mapping button_code;
  string internal_tag_page(string t, mapping args, string c, int l, object id)
  {
    args->num = last_page;
    if(!args->name) args->name = (string)last_page;
    pages += ({ Page( args, c, button_id, button_code ) });
    button_id = pages[ -1 ]->button_id;
    pages[ -1 ]->line_offset = (int)id->misc->line + l;
    pages_by_name[ args->name ] = pages[ -1 ];
    last_page++;
  }

  string lc = "";
  void update(string contents, object id)
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

  void create(mapping args, string contents, object id, object p)
  {
    update(contents,id);
  }


  mapping|string handle( object id )
  {
    mapping v = id->variables;
    mapping s, error;
    object page, last_page;
    int new_page;
    string contents, goto;


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
    id->misc->_store_object = this_object();
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
	return http_redirect( goto, id );
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
      if(error->page && error->page != page->name)
      {
	v["goto_page_"+error->page+"/0"]=1;
	return handle( id );
      } else if(error->href) {
	return http_redirect(error->href, id);
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
  defvar("debug", 0, "Debug mode", TYPE_FLAG|VAR_MORE, "");
}


mapping stores = ([]);

constant help = "Da help";

mixed container_awizard(string tagname, mapping arguments, 
                        string contents, object id)
{
  mixed res;

  if(arguments->help)
    return help;

  if(!stores[id->not_query])
    stores[ id->not_query ] = Store( arguments, contents, id, this_object() );
  else
    stores[ id->not_query ]->update( contents, id );
  res = stores[ id->not_query ]->handle( id );
  if(mappingp(res)) 
  {
    string v = "";
    foreach(indices(res->extra_heads), string i)
      v += "<header name="+i+" value='"+res->extra_heads[i]+"'>";
    return v+"<return code="+res->error+">";
  }
  return ({res});
}

mapping query_container_callers()
{
  return ([ "awizard" : container_awizard, ]);
}
