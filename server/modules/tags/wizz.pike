// This is a roxen module. Copyright © 2000, Roxen IS.
//

#include <module.h>
inherit "module";

constant cvs_version = "$Id: wizz.pike,v 1.2 2001/03/08 14:35:49 per Exp $";
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

static RXML.TagSet rxml_tag_set;
void start(int num, Configuration conf) {
  rxml_tag_set = conf->rxml_tag_set;
}

class PageForm {
  inherit RXML.Tag;
  constant name="form";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  array(RXML.Type) result_types = ({ RXML.t_any(RXML.PXml) });

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      return ({ WIZZ->the_page });
    }
  }
}

static int page_internal_tags_generation;
static RXML.TagSet page_internal_tags;
static RXML.TagSet _page_internal_tags;

class PageFrame {
  inherit RXML.Frame;
  mapping(string:string|int) vars;
  RXML.TagSet additional_tags = page_internal_tags;
  mixed old_wizard;

  void create(string _content, mapping _vars) {
    content=_content;
    vars=_vars;
    args=([]);
    content_type = RXML.t_xml(RXML.PXml);
    result_type = RXML.t_xml;
    flags = RXML.FLAG_UNPARSED;
  }

  array do_enter(RequestID id) {
    old_wizard = id->misc->wizard;
    id->misc->wizard = vars;
    vars->page++;
    if(!vars["cancel-label"]) vars["cancel-label"]=LOCALE(0,"Cancel");
    if(!vars["ok-label"]) vars["ok-label"]=LOCALE(0,"Ok");
    if(!vars["previous-label"]) vars["previous-label"]=LOCALE(0, "< Previous");
    if(!vars["next-label"]) vars["next-label"]=LOCALE(0, "Next >");
    if(!vars->done) vars->done = "";
    if(!vars->cancel) vars->cancel = "";
  }

  int do_iterate=1;

  array do_return(RequestID id) {
    result = "\n<!-- Wizard -->\n"
      "<form method=\""+(vars->method||"POST")+"\" >\n" //action=\""+"\">\n"
      "<input type=\"hidden\" name=\"magic_roxen_automatic_charset_variable\" value=\"едц\" />\n"
      "<input type=\"hidden\" name=\"__done-url\" value=\""+vars->done+"\" />\n"
      "<input type=\"hidden\" name=\"__page\"  value=\""+id->misc->wizard->page+"\" />\n"+
      (vars->cancel?"<input type=\"hidden\" name=\"__cancel-url\" value=\""+vars->cancel+"\" />\n":"")+
      content+"</form>\n";
    id->misc->wizard = old_wizard;
    return 0;
  }

}

class TagWizard {
  inherit RXML.Tag;
  constant name="wizz";
  constant flags=RXML.FLAG_SOCKET_TAG;

  // PageNOP "pre-parses" the <page> tags, counts them
  // and stores the page to be shown in id->misc->wizard->the_page.
  class PageNOP {
    inherit RXML.Tag;
    constant name="page";
    RXML.Type content_type=RXML.t_same;

    class Frame {
      inherit RXML.Frame;

      array do_return(RequestID id) {
	if(id->misc->wizard->page &&
	   id->misc->wizard->page-1 == id->misc->wizard->pages) {
	  id->misc->wizard->verify = 1;
	  id->misc->wizard->verify_ok = 1;
	  RXML.Parser parser = _page_internal_tags(RXML.t_xml(RXML.PXml), id);
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

  class Template {
    inherit RXML.Tag;
    constant name="template";

    class Frame {
      inherit RXML.Frame;

      array do_return(RequestID id) {
	if(id->misc->wizard->pages <= id->misc->wizard->page)
	  id->misc->wizard->template=content;
      }
    }
  }

  RXML.TagSet internal_tags = RXML.TagSet("TagWizard.internal", ({ PageNOP(),
								   Template() }) );
  class Frame {
    inherit RXML.Frame;
    RXML.TagSet additional_tags = internal_tags;
    mixed oldwiz;

    array do_enter(RequestID id) {
      args->page=(int)id->variables->__page;
      if(id->variables->__ok || id->variables->__cancel) args->page=0;
      else if(id->variables->__prev_page) args->page-=2;
      else if(args->page!=0 && !id->variables->__next_page) args->page--;

      if(rxml_tag_set->generation > page_internal_tags_generation) {
	page_internal_tags = RXML.TagSet("TagWizard.page.form.internal",
					 ({ PageForm() }) +
					 values(get_plugins())->get_tag() );
	_page_internal_tags = RXML.TagSet("TagWizard.page.form.internal",
					  ({ PageForm() }) +
					  values(get_plugins())->get_tag() );
	_page_internal_tags->imported += ({ rxml_tag_set });
	page_internal_tags_generation = rxml_tag_set->generation;
      }

      oldwiz=id->misc->wizard;
      id->misc->wizard=args;
    }

    array do_return(RequestID id) {
      if((id->variables->__ok && id->variables["__done-url"]) ||
	 (id->variables->__cancel && id->variables["__cancel-url"])) {
	mapping r = Roxen.http_redirect(id->variables["__done-url"] || id->variables["__cancel-url"], id);
	if (r->error)
	  id->misc->defines[" _error"] = r->error;
	if (r->extra_heads)
	  id->misc->defines[" _extra_heads"] += r->extra_heads;
	return 0;
      }
      array ret=({ PageFrame( id->misc->wizard->template || default_template, WIZZ ) });
      id->misc->wizard=oldwiz;
      return ret;
    }

  }
}

constant default_template = #"
<table bgcolor=\"#000000\" cellpadding=\"1\" border=\"0\" cellspacing=\"0\" width=\"80%\">
  <tr><td><table bgcolor=\"#eeeeee\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" width=\"100%\">
    <tr><td valign=\"top\"><table width=\"100%\" cellspacing=\"0\" cellpadding=\"5\">
      <tr><td valign=top><font size=\"+2\">&_.title;</font></td>
          <td align=\"right\"><if variable='_.page == &_.pages;'>Completed</if>
                              <else>&_.page;/&_.pages;</else></td>
    <if variable='_.help'>
	  <td align=\"right\"><input type=\"image\" name=\"help\" src=\"/internal-roxen-help\" border=\"0\" value=\"Help\"></td>
    </if>
      </tr>
      <tr><td colspan=\"3\"><hr size=\"1\" noshade=\"noshade\" /></td></tr>
    </table>
    <table cellpadding=\"6\"><tr><td>" +
  /*
<pre><b>underscore</b>
<insert variables='full' scope='_' />
<b>form</b>
<insert variables='full' scope='form' />
</pre>
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
