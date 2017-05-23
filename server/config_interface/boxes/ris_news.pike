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

  return Mustache()->render(tmpl, items);
}

string parse(RequestID id)
{
  string contents;
  string url = "/press-ir/news/index.xml?__xsl=json.xsl";

  if (!(contents = .Box.get_http_data("www.roxen.com", 80,
                                      "GET "+ url + " HTTP/1.0")))
  {
    contents = "Fetching data from www.roxen.com...";
  }
  else {
    if (mixed err = catch(contents = extract_nonfluff(contents))) {
      report_notice("Error parsing Roxen news: %s\n",
                    describe_backtrace(err));
      contents = "Error parsing news.";
    }
  }

  return
    "<cbox type='"+box+"' title='"+box_name+"'>"+contents+"</cbox>";
}

