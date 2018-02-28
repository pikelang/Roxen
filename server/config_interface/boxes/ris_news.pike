// Locale stuff.
// <locale-token project="roxen_config">_</locale-token>

#include <roxen.h>
#include <config_interface.h>
#define _(X,Y)  _DEF_LOCALE("roxen_config",X,Y)

constant box         = "small";
constant box_initial = 1;

LocaleString box_name = _(263,"News from www.roxen.com");
LocaleString box_doc  = _(281,"The news headlines from www.roxen.com");

constant tmpl = #"
<ul class='linklist'>
  {{ #. }}
  <li><a href='https://roxen.com{{ url }}'>
    {{ #date }}<span class='date'>{{ date }}</span>{{ /date }}
    {{ title }}</a></li>
  {{ /. }}
</ul>";

string extract_nonfluff(string from)
{
  catch {
    from = utf8_to_string(from);
  };

  array(mapping) items = ({});

  if (mixed err = catch(items = Standards.JSON.decode(from))) {
    report_notice("Failed parsing Roxen news: %s\n",
                  describe_backtrace(err));
    return "Error fetching news";
  }

  return Roxen.render_mustache(tmpl, items);
}

string parse(RequestID id)
{
#ifdef DEBUG
  if (id->request_headers["pragma"] &&
      id->request_headers["pragma"] == "no-cache" &&
      !id->variables->_raw)
  {
    .Box.clear_cache(true);
  }
#endif

  string contents;
  string url = "http://www.roxen.com/press-ir/news/index.xml";
  mapping rvars = ([ "__xsl": "json.xsl" ]);

  int(-1..1)|string cc = .Box.get_http_data2(url, rvars);

  // No previous request made.
  if (cc == 0) {
    string furl = "/boxes/ris_news.pike?_raw=1&_roxen_wizard_id=" +
                  id->variables->_roxen_wizard_id;
    contents = "<div id='x-data'>Fetching data ..."
               " <i class='fa fa-spinner fa-pulse'></i></div>"
               "<script>"
               " rxnlib.fetchInto('" + furl + "', 'x-data',"
               "   function() {"
               "     rxnlib.main(document.getElementById('x-data'));"
               "   });"
               "</script>";
  }
  // Pending request
  else if (cc == 1) {
    // Tell the Javascript to try again.
    contents = "-1";
  }
  // Bad request
  else if (cc == -1) {
    contents = "Error parsing news.";
  }
  // Got cached data
  else {
    contents = cc;

    if (mixed err = catch(contents = extract_nonfluff(contents))) {
      report_notice("Error parsing Roxen news: %s\n",
                    describe_backtrace(err));
      contents = "Error parsing news.";
    }
  }

  if (id->variables->_raw) {
    return contents;
  }

  return
    "<cbox type='"+box+"' title='"+box_name+"'>"+contents+"</cbox>";
}
