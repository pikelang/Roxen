// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.
//

#include <module.h>
inherit "module";

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Tags: Really advanced wizard";
constant module_doc  = "...";

#define LOCALE(X,Y) (Y)
#define WIZZ [mapping(string:string|int)]([mapping(string:mixed)](id->misc)->wizard)

// id->misc->wizard contains:
//
// the_page = The content of the selected page
// page = The number of the selected page
// pages = The number of pages
// template = The template
// verify = The <page> is run though a verification pass if true
// verify_ok = The verification result.
// the_wizard_tag_args|the_page_tag_args

protected RXML.TagSet rxml_tag_set;
void start(int num, Configuration conf) {
  rxml_tag_set = conf->rxml_tag_set;
}

class PageForm {
  inherit RXML.Tag;
  constant name = "form";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  array(RXML.Type) result_types = ({ RXML.t_any(RXML.PXml) });

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      //      if(!WIZZ->the_page) run_error("No page sent to form\n");
      return ({ WIZZ->the_page });
    }
  }
}

class Page {
  inherit RXML.Tag;
  constant name = "page";

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(id->misc->wizard->page &&
	 id->misc->wizard->page-1 == id->misc->wizard->pages) {
	id->misc->wizard->verify = 1;
	id->misc->wizard->verify_ok = 1;
	RXML.Parser parser = page_internal_tags(RXML.t_xml(RXML.PXml), id);
	parser->write_end(content);
	parser->eval();
	if(!id->misc->wizard->verify_ok)
	  id->misc->wizard->page--;
	id->misc->wizard->verify = 0;
      }
      if(id->misc->wizard->page == id->misc->wizard->pages++) {
	id->misc->wizard |= args;
	id->misc->wizard->the_page = content;
      }
    }
  }
}

protected int page_internal_tags_generation;
protected RXML.TagSet page_internal_tags;

class PageFrame {
  inherit RXML.Frame;
  mapping(string:string|int) vars;
  RXML.TagSet additional_tags = page_internal_tags;
  mixed old_wizard;

  void create(string _content, mapping _vars) {
    content = _content;
    vars = _vars;
    args = ([]);
    content_type = RXML.t_xml(RXML.PXml);
    result_type = RXML.t_xml;
    flags = RXML.FLAG_UNPARSED;
  }

  array do_enter(RequestID id) {
    old_wizard = id->misc->wizard;
    id->misc->wizard = vars;
    vars->page++;
    if(!vars["cancel-label"]) vars["cancel-label"] = LOCALE(0,"Cancel");
    if(!vars["ok-label"]) vars["ok-label"] = LOCALE(0,"Ok");
    if(!vars["previous-label"]) vars["previous-label"] = LOCALE(0, "< Previous");
    if(!vars["next-label"]) vars["next-label"] = LOCALE(0, "Next >");
    if(!vars->title) vars->title = vars->name || vars->wizard_name || LOCALE(0, "Roxen wizard");
    if(!vars->done) vars->done = "";
    if(!vars->cancel) vars->cancel = "";
  }

  int do_iterate=1;

  array do_return(RequestID id) {
    result = "\n<!-- Wizard -->\n"
      "<form method=\""+(vars->method||"POST")+"\" >\n"
      "<input type=\"hidden\" name=\"magic_roxen_automatic_charset_variable\" value=\"едц\" />\n"
      "<input type=\"hidden\" name=\"__state\" value=\"" + vars->__state + "\" />\n"
      "<input type=\"hidden\" name=\"__done-url\" value=\""+vars->done+"\" />\n"
      "<input type=\"hidden\" name=\"__page\"  value=\""+vars->page+"\" />\n"+
      (vars->cancel?"<input type=\"hidden\" name=\"__cancel-url\" value=\""+
       vars->cancel+"\" />\n":"");

    result += content+"</form>\n";
    id->misc->wizard = old_wizard;
    return 0;
  }

}

class TagWizard {
  inherit RXML.Tag;
  constant name = "wizz";
  constant flags = RXML.FLAG_SOCKET_TAG;

  // "Preparse" the content by only count the number of <page> tags.
  class PageNOP {
    inherit RXML.Tag;
    constant name = "page";
    RXML.Type content_type = RXML.t_same;

    class Frame {
      inherit RXML.Frame;

      array do_return(RequestID id) {
	id->misc->wizard->pages++;
      }
    }
  }

  class Template {
    inherit RXML.Tag;
    constant name = "template";

    class Frame {
      inherit RXML.Frame;

      array do_return(RequestID id) {
	if(id->misc->wizard->pages <= id->misc->wizard->page)
	  id->misc->wizard->template = content;
	result = "";
      }
    }
  }

  RXML.TagSet internal_tags = RXML.TagSet(this_module(), "l1", ({ PageNOP(),
									Template() }) );
  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags = internal_tags;
    mixed old_wizard;

    array do_enter(RequestID id) {
      args->page = id->real_variables->__page ? (int)id->real_variables->__page[0] : 0;
      args->pages = 0;
      if(id->real_variables->__ok || id->real_variables->__cancel) args->page=0;
      else if(id->real_variables->__prev_page) args->page-=2;
      else if(args->page!=0 && !id->real_variables->__next_page) args->page--;

      if(rxml_tag_set->generation > page_internal_tags_generation) {
	page_internal_tags = RXML.TagSet(this_module(), "l2",
					 ({ Page(), PageForm() }) +
					 values(get_plugins())->get_tag() );
	page_internal_tags->imported += ({ rxml_tag_set });
	page_internal_tags_generation = rxml_tag_set->generation;
      }

      StateHandler.Page_state state = StateHandler.Page_state(id);
      state->register_consumer("wizard");
      if(id->real_variables->__state) {
	state->use_session( StateHandler.decode_session_id(id->real_variables->__state[0]) );
	state->decode(id->real_variables->__state[0]);
      }
      else
	state->use_session();

      old_wizard = id->misc->wizard;
      id->misc->wizard = ( state->get() || ([]) ) | args |
	map(id->real_variables, lambda(array in) { return sizeof(in)==1?in[0]:in; });
      state->alter(id->misc->wizard);
      id->misc->wizard->__state = state->encode();
    }

    array do_return(RequestID id) {
      if((id->variables->__ok && id->variables["__done-url"]) ||
	 (id->variables->__cancel && id->variables["__cancel-url"])) {
	mapping r = Roxen.http_redirect(id->variables["__done-url"] ||
					id->variables["__cancel-url"], id);
	if (r->error)
	  RXML_CONTEXT->set_misc (" _error", r->error);
	if (r->extra_heads)
	  RXML_CONTEXT->extend_scope ("header", r->extra_heads);
	return 0;
      }

      array ret;
      if(id->misc->wizard->pages)
	ret = ({ PageFrame( id->misc->wizard->template || default_template, WIZZ ) });
      id->misc->wizard = old_wizard;
      return ret;
    }

  }
}

constant default_template = #"
<table bgcolor=\"#000000\" cellpadding=\"1\" border=\"0\" cellspacing=\"0\" width=\"80%\">
  <tr><td><table bgcolor=\"#eeeeee\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" width=\"100%\">
    <tr><td valign=\"top\" align=\"center\">
      <table width=\"97%\" cellspacing=\"0\" cellpadding=\"5\" border=\"0\">
      <tr><td valign=\"top\"><font size=\"+2\">&_.title;</font></td>
          <td align=\"right\"><if variable='_.page == &_.pages;'>Completed</if>
                              <else>&_.page;/&_.pages;</else></td>
    <if variable='_.help'>
	  <td align=\"right\"><input type=\"image\" name=\"help\" src=\"/internal-roxen-help\" border=\"0\" value=\"Help\"></td>
    </if>
      </tr>
    </table>
    <hr size=\"1\" noshade=\"noshade\" width=\"95%\" />
    </td></tr><tr><td valign=\"top\">
    <table cellpadding=\"6\"><tr><td>" +
/*
#"
<pre><b>underscore</b>
<insert variables='full' scope='_' />
<b>form</b>
<insert variables='full' scope='form' />
</pre>
"+
*/
#"        <form/>
    </td></tr></table>
    <table width=\"100%\"><tr><td width=\"33%\">
        <if variable='_.page != 1'>
        <input type=\"submit\" name=\"__prev_page\" value=\"&_.previous-label;\" /></if>
      </td><td width=\"33%\" align=\"center\">
         <if variable='_.page == &_.pages;'>
	 &nbsp;&nbsp;<input type=\"submit\" name=\"__ok\" value=\" &_.ok-label; \" />&nbsp;&nbsp;</if>
	 &nbsp;&nbsp;<input type=\"submit\" name=\"__cancel\" value=\" &_.cancel-label; \" />&nbsp;&nbsp
      </td><td width=\"33%\" align=\"right\">
        <if variable='_.page != &_.pages;'>
        <input type=\"submit\" name=\"__next_page\" value=\"&_.next-label;\" /></if>
      </td></tr></table>
    </td></tr>
  </table>
  </td></tr>
</table>";
