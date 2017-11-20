// Locale stuff.
// <locale-token project="roxen_config"> _ </locale-token>

#include <roxen.h>
#define _(X,Y)	_DEF_LOCALE("roxen_config",X,Y)

constant box      = "large";
constant box_initial = 0;

LocaleString box_name = _(232,"Crunch activity");
LocaleString box_doc  = _(262,"Recently changed Crunch reports");

class Fetcher
{
  mapping|int cache_context;
  Protocols.HTTP.Query query;
  string crunch_date( int t )
  {
    mapping l = localtime(t);
    return (1900+l->year)+""+sprintf("%02d%02d",(l->mon+1),(l->mday));
  }

  void done( Protocols.HTTP.Query q )
  {
    crunch_data = Data( query->data() );
    cache_set( "crunch_data", "data", query->data(), 9000, cache_context );
    destruct();
  }
  
  void fail( Protocols.HTTP.Query q )
  {
    crunch_data = Data("");
  }

  void create(mapping|int cache_context)
  {
    this_program::cache_context = cache_context;
    call_out( Fetcher, 3600, 1 );
    string url = "/bugzilla/buglist.cgi?ctype=atom&chfieldfrom=" +
      crunch_date( time()-24*60*60*7 );
    query = Protocols.HTTP.Query( )->set_callbacks( done, fail );
    query->async_request( "bugzilla.roxen.com", 80,
			  "GET "+url+" HTTP/1.0",
			  ([ "Host":"bugzilla.roxen.com:80" ]) );
  }
}


class Data( string data )
{
  class Bug( int id, string href, string short, string created,
	     string product, string component,
	     string version, string opsys, string arch,
	     string severity, string priority, string status,
	     string resolution )
  {
    string format( )
    {
      if( product == "Roxen WebServer" &&
	  (version > roxen.roxen_ver) )
	return "";

      if( (product == "Pike") && sizeof(version) &&
	  (abs((float)version - __VERSION__) > 0.09) )
	return "";

      switch( status )
      {
	case "RESOLVED":
	  status = "fixed";
	  break;
	case "ASSIGNED":
	  status = "open";
	  break;
	case "NEW":
	  status = "<font color='&usr.warncolor;'>New</font>";
	  break;
	default:
      }
      resolution = "";
      switch( component )
      {
	case "Admin Interface":
	  component = "GUI";
	  break;
	case "Image Module":
	  component = "Image";
      }
      return "<tr valign=top>"
	"<td><font size=-1>"+(product - "Roxen WebServer")+
	" <nobr>"+(component-"Other ")+"</nobr></font></td>"
	"<td><font size=-1><a href='"+ href +"'>"+short+"</a></font></td>"
	"<td><font size=-1>"+lower_case(status)+"</font></td></tr>";
    }

    int `<(Bug what )
    {
      if( what->status != status )
	return (what->status > status);
      return what->product+what->component+what->short > product+component+short;
    }
    
    int `>(Bug what )
    {
      return !`<(what);
    }
  }

  array(Bug) parsed;

  Parser.HTML entry_parser;

  Parser.HTML summary_parser;

  protected mapping md;

  string parse_summary_tr(Parser.HTML x, mapping m, string content)
  {
    md->summary_class = m->class;
    return content;
  }

  void parse_summary_td(Parser.HTML x, mapping m, string value)
  {
    if (!md["summary_" + md->summary_class + "_label"]) {
      md["summary_" + md->summary_class + "_label"] = value;
    } else {
      md["summary_" + md->summary_class + "_value"] = value;
    }
  }

  void parse_title(Parser.HTML x, mapping m, string title)
  {
    md->title = title;
  }

  void parse_link(Parser.HTML x, mapping m)
  {
    md->href = m->href;
  }

  void parse_id(Parser.HTML x, mapping m, string id)
  {
    md->id = ((("&" + (id/"?")[1])/"&id=")[1]/"&")[0];
  }

  void parse_name(Parser.HTML x, mapping m, string name)
  {
    md->author = name;
  }

  void parse_updated(Parser.HTML x, mapping m, string updated)
  {
    md->updated = updated;
  }

  void parse_summary(Parser.HTML x, mapping m, string summary)
  {
    summary_parser->finish(Parser.parse_html_entities(summary))->read();
  }

  void parse_entry(Parser.HTML b, mapping m, string content)
  {
    md = ([]);
    entry_parser->finish(content)->read();
    parsed += ({ Bug( (int)md->id, md->href, md->title, md->updated,
		      md->summary_bz_feed_product_value||"",
		      md->summary_bz_feed_component_value||"",
		      md->summary_bz_feed_version_value||"",
		      md->summary_bz_feed_opsys_value||"",
		      md->summary_bz_feed_arch_value||"",
		      md->summary_nz_feed_severity_value||"",
		      md->summary_bz_feed_priority_value||"",
		      md->summary_bz_feed_bug_status_value||"",
		      md->summary_bz_feed_resolution_value||"" ) });
  }
  
  void parse( )
  {
    parsed = ({});
    entry_parser = Parser.HTML()->
      add_container("title", parse_title)->
      add_tag("link", parse_link)->
      add_container("id", parse_id)->
      add_container("author", parse_name)->
      add_container("updated", parse_updated)->
      add_container("summary", parse_summary);
    summary_parser = Parser.HTML()->
      add_container("tr", parse_summary_tr)->
      add_container("td", parse_summary_td);
    Parser.HTML()->add_container( "entry", parse_entry )->
      finish( data )->read();
  }
  
  string get_page()
  {
    if(!parsed)
    {
      parse();
      sort(parsed);
    }
    return "<table cellspacing=0 cellpadding=2>"+(parsed->format()*"\n")+"</table>";
  }
}

Data crunch_data;
Fetcher fetcher;
string parse( RequestID id )
{
  string contents;
  if( !crunch_data )
  {
    string data;
    mapping cache_context = ([]);
    if( !(data = cache_lookup( "crunch_data", "data", cache_context )) )
    {
      if( !fetcher )
	fetcher = Fetcher(cache_context);
      contents = "Fetching data from Crunch...";
    } else {
      crunch_data = Data( data );
      call_out( Fetcher, 3600, 1 );
      contents = crunch_data->get_page();
    }
  } else
    contents = crunch_data->get_page();

  return
    "<box type='"+box+"' title='"+box_name+"'>"+contents+"</box>";
}
