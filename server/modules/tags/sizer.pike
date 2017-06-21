// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.

constant thread_safe=1;
constant cvs_version = "$Id$";
#include <request_trace.h>
#include <module.h>
inherit "module";

// begin locale stuff
//<locale-token project="mod_sizer">_</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_sizer",X,Y)
// end locale stuff


constant module_type = MODULE_TAG | MODULE_FILTER;
LocaleString module_name = _(1,"Tags: Page sizer");

LocaleString module_doc  =
  _(2,"This module provides the <tt>&lt;page-size&gt;</tt> tag that "
    "calculates the size of a page, including inline images, and gives"
    " estimates of the time it will take to download the page.<p>"
    "You can also use the <i>size</i> prestate to trigger the sizing "
    "process</p>");

#define NOTE(X) ("<tr><td valign='top'><img src='/internal-roxen-err_1'></td>\n"\
		"<td><font color='black' size='-1'>" + (X) +"</font></td></tr>")
#define WARN(X) ("<tr><td valign='top'><img src='/internal-roxen-err_2'></td>\n"\
		 "<td><font color='black' size='-1'>" + (X) +"</font></td></tr>")
#define ERR(X) ("<tr><td valign='top'><img src='/internal-roxen-err_3'></td>\n"\
		 "<td><font color='black' size='-1'>" + (X) +"</font></td></tr>")

class Combo( string file, RequestID id )
{
  private RequestID id2;
  private mapping res;
  private int fetched;

  private void fetch( )
  {
    fetched = 1;
    id2 = id->clone_me();
    id2->misc->sizer_in_progress++;
    id2->not_query = file;
    res = id->conf->get_file( id2 );
    if(!res)
      error("Failed to fetch %s\n", file );
  }

  int ok( )
  {
    if( !fetched )fetch();
    return res && (!res->error || (res->error == 200));
  }

  string data()
  {
    if( !fetched )fetch();
    return res && (res->data || (res->file && res->file->read()));
  }

  string type( )
  {
    if( !fetched )fetch();
    return res->type;
  }

  int size()
  {
    if( !fetched )fetch();

    if(!res) return 0;
    if( res->data )
      return strlen( res->data );
    if( res->file )
      return res->file->stat()->size;
  }    

  string headers()
  {
    if( !fetched ) fetch();

    mapping heads = ([]);
    heads["Last-Modified"] = Roxen.http_date(id2->misc->last_modified);
    if( res->data )
      res->len = strlen(res->data);
    heads["Content-Type"] = res->type;
    heads["Accept-Ranges"] = "bytes";
    heads["Server"] = replace(version()," ","·");
    heads["Connection"]=(id2->misc->connection=="close"?"close":"keep-alive");
    if(res->encoding) heads["Content-Encoding"] = res->encoding;
    if(!res->error) res->error=200;
    if(res->expires)  heads->Expires = Roxen.http_date(res->expires);
    if(mappingp(res->extra_heads)) heads |= res->extra_heads;
    if(mappingp(id2->misc->moreheads)) heads |= id2->misc->moreheads;
    if( res->len > 0 || (res->error != 200) )
      heads["Content-Length"] = (string)res->len;

    string head_string = sprintf( "%s %d %s\r\n", id2->prot, res->error,
				  res->rettext||
				  Roxen.http_status_messages[res->error]||"");

    if( (res->error/100 == 2) && (res->len <= 0) )
      heads->Connection = "close";
    return head_string+Roxen.make_http_headers( heads );
  }
}


Combo do_read_file( string file, RequestID id )
{
  Combo res = Combo( file, id );
  res->ok();
  return res;
}

array size_file( string page, RequestID id )
{
  string messages = "";
  mapping sizes = ([]), types = ([]);
  array files = ({});
  id->misc->sizer_in_progress++;

  if( !has_prefix( lower_case(page), "http:" ) )
    page = Roxen.fix_relative( page, id );
  files = ({ page });
  if( strlen( page ) && page[0] == '/' )
  {
    Combo res;
    catch(  res = do_read_file( page, id ) );

    if( !res || !res->ok() )
      messages += ERR("Failed to read '"+Roxen.html_encode_string(page)+"'\n");

    function follow( string i ) {
      return lambda(object p, mapping m)
	     {
	       if(m[i])
	       {
		 if(sizes[m[i]])
		   return;
		 mapping ss,tt;
		 string mm;
		 array ff;
		 [ff,ss,tt,mm] = size_file(m[i],id);
		 sizes |= ss;
		 types |= tt;
		 files += ff;
		 messages += mm;
	       }
	     };
    };

    if( id->misc->sizer_in_progress == 1 )
      if( res->type()  == "text/html" )
	Parser.HTML( )->add_tags( ([
	  // src=''
	  "img":follow("src"), "input":follow("src"),
	  // background=''
	  "body":follow("background"), "table":follow("background"),
	  "td":follow("background"), "tr":follow("background"),
	]) )->feed( res->data() )->finish()->read();

    types[ page ] = res->type();
    sizes[ page ] = ({ res->size(), strlen(res->headers()) });
  } else {
    messages += ERR("Cannot read '"+Roxen.html_encode_string(page)+"'");
  }
  return ({ files, sizes, types, messages });
}

mixed find_internal( string f, RequestID id )
{
  string fmt;
  int quality;
  if( sscanf( f, "%s!%s!%d", f, fmt, quality ) != 3 )
    return 0;

  f = Gmp.mpz(f,16)->digits(256);

  mapping(string:Image.Image) i=Image._decode( do_read_file( f, id )->data() );

  switch( fmt )
  {
#if constant(Image.JPEG.encode)
    case "JPEG":
      return Roxen.http_string_answer(
	Image.JPEG.encode( i->img, ([ "quality":quality ]) ),
	"image/jpeg" );
      break;
#endif
    case "GIF":
      break;
  }
  return 0;
}

string imglink( string img, string fmt, int quality,RequestID id )
{
  return (query_absolute_internal_location(id)+
	  Gmp.mpz(img,256)->digits(16)+"!"+fmt+"!"+quality);
}

constant simpletag_page_size_flags = RXML.FLAG_EMPTY_ELEMENT;

string simpletag_page_size( string name,
			    mapping args,
			    string contents,
			    RequestID id )
{
  if( id->misc->sizer_in_progress )
    return ""; // avoid infinite recursion. :-)
  CACHE(0);
  string page;
  if( args->page )
    page = args->page;
  else
    page = id->not_query;

  mapping sizes = ([]), types = ([]);
  array files = ({});
  string messages;
  [files,sizes,types,messages] = size_file( page, id );

  string res = "";
  int total, total_headers;
  multiset what = (multiset)((args->include||"summary,details,dltime,"
			      "suggestions")/",");

  string fname( string f )
  {
    string d = dirname( page );
    if( strlen(f) > 4 && (f[1] == '_') )
    {
      string internal = replace(id->conf->query("InternalLoc"), "%", "%%");

      if( sscanf( f, internal + "cimg%*[^/]/%s", f ) == 2 )
      {
	if( mapping ar = roxen.argcache->lookup( f ) )
	{
	  string sz = "";
	  if( ar["max-width"] )  sz = " (xs:"+((string)ar["max-width"]);
	  if( ar["max-height"] ) sz +=" (ys:"+((string)ar["max-height"]);
	  if(strlen(sz))
	    sz+=")";

	  if( ar->src )
	    return "Cimg of "+fname( ar->src )+sz;
	  return "Cimg from data"+sz;
	}
      }
      else if(sscanf( f, internal + "graphic_text%*[^$]$%s", f ) == 2 )
      {
	mapping ar = roxen.argcache->lookup( f );
	if( ar[""] ) return "Gtext (\""+ar[""]+"\")";
	return "Gtext";
      }
    }
    if( d != "" )
      if( f[..strlen(d)-1] == d )
	f = f[strlen(d)+1..];
    return f;
  };
  int mpct;
  string describe_size( string ind, string f  )
  {
    array sz = sizes[ ind ];
    int pct = (`+(@sz)*100)/total;
    if( pct > mpct )
      mpct = pct;
    return sprintf( "  <tr><td><font color='black' size='-1'>%s</font></td>"
		    "<td align='right'><font color='black' size='-1'>%.1f</font>"
		    "</td><td align='right'><font color='black' size='-1'>%d"
		    "</font></td>"
	    "<td align='right'><font color='black' size='-1'>%d%%</font></td>"
		    "</tr>\n",
		    f, `+(@sz)/1024.0, sz[1],pct );
  };

  foreach( indices( sizes ), string f )
  {
    array sz = sizes[f];
    total += sz[0] + sz[1];
    total_headers += sz[1];
  }

  res += "<table width='100%' cellpadding='0' cellspacing='0'>\n"
    "  <tr><th align='left'><font size='-1' color='black'>File</font></th>"
    "<th align='right'><font size='-1' color='black'>Size (kb)</font></th>"
    "<th align='right'><font size='-1' color='black'>&nbsp; Headers (b)</font></th>"
    "<th align='right'><font size='-1' color='black'>&nbsp; % of page</font></td></tr>"
    "<tr><td colspan='4'><hr noshade='noshade' size='1'></td></tr>";

  foreach( files, string file )
    res += describe_size( file, fname(file) );

  if( !what->details )
  {
    res = strlen(messages)?"<tt><b>"+messages+"</b></tt><br />":"";
    res += "<table>";
  }
  else
    res = (strlen(messages)?"<tt><b>"+messages+"</b></tt><br />":"") + res;

  if( what->summary )
  {
    res += sprintf( "\n<tr><td><font color='black' size='-1'><b>Total size:</b></font></td><td align='right'><font color='black' size='-1'>%.1f</font></td><td align='right'><font color='black' size='-1'>%d</font></td><td>&nbsp;</td></tr>",
		    total/1024.0, total_headers );
    res += "<tr><td colspan='4'><hr noshade size='1'></td></tr>";
  }

  res += "</table>\n";
  if( what->dltime )
  {
    int i = -1;
    res += "<b><font size='-1'>Estimated download time:</font></b> "
	   "(bandwidth in kb/s)\n<table><tr>";
    foreach( (args->speeds?(array(float))(args->speeds/",")
	      :({ 28.8, 56.0, 64.0, 256.0, 384.0,1024.0 })), float kbit )
    {
      int time = (int)((total*8)/(kbit*1000)+0.7);
      if(!time) time = 1;
      string color;
      switch( time )
      {
	case 1..5:      color = "darkgreen"; break;
	case 6..10:     color = "black"; break;
	case 11..20:    color = "darkred"; break;
	case 21..30:    color = "darkorange";    break;
	case 31..:      color = "red";        break; 
      }
      res+=sprintf("<td align='right'><font color='%s' size='-1'><b>%2.1f</b>:"
		   "</td><td align='right'><font color='%s' size='-1'>%ds</font></td>\n",
		   color, kbit,color,time  );
      if( (++i % 3) == 2)
	res += "</tr>\n<tr>";
    }
    if( (i % 3) )
      res += "</tr>\n";
    res += "</table>";
  }


  if( what->suggestions )
  {
    res += "<hr noshade size='1' />";
    res += "<table>";
    if( ((total*8) / 56000)  > 20 )
    {
      res += WARN("This page takes more than 20 seconds to download over a "
		  "56Kbit/sec modem.");
      foreach( files, string f )
      {
	if( 100*`+(@sizes[f])/total > mpct/3 )
	switch( types[ f ] )
	{
	  case "image/jpeg":
#if constant(Image.JPEG.encode) && constant(Image.JPEG.decode)
	    if( sizes[f][0] < 300*1024 )
	    {
	      Image.Image i=Image.JPEG.decode( do_read_file( f, id )->data() );
	      if( (i->xsize() > 1024) || (i->ysize() > 1024) )
	      {
		res += NOTE(sprintf("The image %s (%dx%d) is larger than most "
				    "people can easily view on screen.",
				    fname(f),i->xsize(), i->ysize()));
	      }
	      else
	      {
		mapping  sz = ([
		  75:strlen(Image.JPEG.encode( i, ([ "quality":75 ]) )),
		  50:strlen(Image.JPEG.encode( i, ([ "quality":50 ]) )),
		  25:strlen(Image.JPEG.encode( i, ([ "quality":25 ]) )),
		]);
		int ds;
		string mm = "";
		if( sz[ 75 ] < sizes[f][0] )
		{
		  mm = ("The image "+fname(f)+
			" is compressed with a very high "
			"JPEG-quality. Try lowering it.");
		  ds = 0;
		}
		else if( sz[ 50 ] < sizes[f][0] )
		{
		  mm = ("The image "+fname(f)+" might be compressed better.");
		  ds = 1;
		}
		else
		  ds = 2;
		if( ds < 2 )
		{
		  if( ds )
		  {
		    res+=WARN(sprintf(replace(mm,"%","%%")+
				      " Some suggestions: "
				      "<a target='_foo' href='%s'>50%%: -%.1fKb</a>, "
				      "<a target='_foo' href='%s'>25%%: -%.1fKb</a>",
				      imglink(f, "JPEG", 50,id),
				      (sizes[f][0]-sz[50])/1024.0,
				      imglink(f, "JPEG", 25,id),
				      (sizes[f][0]-sz[25])/1024.0 ) );
		  } else {
		    res+=WARN(sprintf(replace(mm,"%","%%")+
				      " Some suggestions: <a target='_foo' href='%s'>75%%: "
				      "-%.1fKb</a>, <a target='_foo' href='%s'>"
				      "50%%: -%.1fKb</a>, "
				      "<a target='_foo' href='%s'>25%%: -%.1fKb</a>",
				      imglink(f, "JPEG", 75,id),
				      (sizes[f][0]-sz[75])/1024.0,
				      imglink(f, "JPEG", 50,id),
				      (sizes[f][0]-sz[50])/1024.0,
				      imglink(f, "JPEG", 25,id),
				      (sizes[f][0]-sz[25])/1024.0 ) );
		  }
		}
	      }
	    } else {
	      res += WARN("The image "+fname(f)+
			  " is huge. Try making it smaller");
	    }
#else /* !constant(Image.JPEG.encode) || !constant(Image.JPEG.decode) */
	    res += NOTE("Could not decode/encode JPEG image. "
			"This server lacks JPEG support.");
#endif /* constant(Image.JPEG.encode) */
	    break;
	  case "image/gif":
#if constant(Image.GIF) && constant(Image.GIF.encode)
	    mapping _i = Image._decode( do_read_file( f, id )->data() );
	    Image.Image i = _i->img;
	    Image.Image a = _i->alpha;

	    if( (i->xsize() > 1024) || (i->ysize() > 1024) )
	      res += NOTE(sprintf("The image %s (%dx%d) is larger than most "
				  "people can easily view on screen.",
				  fname(f), i->xsize(), i->ysize()));
	    else
	    {
	      mapping  sz;
	      if( a )
		sz = ([
		  8:strlen(Image.GIF.encode_trans(Image.Colortable( i, 7 )
						  ->map(i),a)),
		  32:strlen(Image.GIF.encode_trans(Image.Colortable( i, 31 )
						   ->map(i),a)),
		  128:strlen(Image.GIF.encode_trans(Image.Colortable( i, 127 )
						    ->map(i),a)),
		]);
	      else
		sz = ([
		  8:strlen(Image.GIF.encode(Image.Colortable( i, 8 )->map(i))),
		  32:strlen(Image.GIF.encode(Image.Colortable(i,32)->map(i))),
		  128:strlen(Image.GIF.encode(Image.Colortable(i,128)->map(i))),
		]);
	      int ds;
	      string mm = "";
	      if( sz[ 128 ] < sizes[f][0] )
	      {
		mm = ("The image "+fname(f)+" is compressed with a very high "
		      "number of colors.");
		ds = 0;
	      }
	      else if( sz[ 32 ] < sizes[f][0] )
	      {
		mm = ("The image "+fname(f)+" might be compressed better "
		      "with fewer colors.");
		ds = 1;
	      }
	      else
		ds = 2;
	      if( ds < 2 )
	      {
		if( ds )
		  res+=WARN(sprintf(replace(mm,"%","%%")+" Some suggestions: "
				    "32: -%.1fKb, 8: -%.1fKb",
				    (sizes[f][0]-sz[32])/1024.0,
				    (sizes[f][0]-sz[8])/1024.0 ) );
		else
		  res+=WARN(sprintf(replace(mm,"%","%%")+
				    " Some suggestions: 128: "
				    "-%.1fKb, 32: -%.1fKb, 8: -%.1fKb",
				    (sizes[f][0]-sz[128])/1024.0,
				    (sizes[f][0]-sz[32])/1024.0,
				    (sizes[f][0]-sz[8])/1024.0 ) );
	      }
	    }
#else // constant(Image.GIF) && constant(Image.GIF.encode)
	    res += NOTE("Could not decode/encode GIF image. "
			"This server lacks LZW support.");
#endif // constant(Image.GIF) && constant(Image.GIF.encode)
	    break;
	}
      }
    }
    res += "</table>";
  }

  res = "<table width='400' cellpadding='0' cellspacing='0' border='0'"
    " bgcolor='black'><tr><td>\n<table cellpadding='10' cellspacing='1'"
    " border='0' width='100%' bgcolor='white'>\n<tr><td>\n" + res +
    "</td></tr>\n</table>\n</td></tr></table>\n";
  return res ;
}

mapping filter(mapping result, RequestID id)
{
  if(!result				// nobody had anything to say
     || !stringp(result->data)		// got a file object
     || !(id->prestate->size)		// only bother when we're being hailed
     || !glob("text/html*", result->type)
     || id->misc->sizer_in_progress	// already sized file?
     || id->misc->orig			// not for internal requests
    )
    return 0; // signal that we didn't rewrite the result for good measure

  TRACE_ENTER("Calculating download times", 0);
  result->data = simpletag_page_size("", ([]), "", id ) + result->data;
  TRACE_LEAVE("");

  return result;
}


TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([

"page-size":#"<desc tag='tag'><p><short hide='hide'>
 Calculates the size of a page and estimates the
 downloadtime.</short><tag>page-size</tag> calculates the size of a
 page, including inline images, and gives estimates of the time it
 will take to download the page. All information is shown in a box.</p>

<ex-html>
<table width='400' cellpadding='0' cellspacing='0' border='0' bgcolor='black'><tr><td>
<table cellpadding='10' cellspacing='1' border='0' width='100%' bgcolor='white'>
<tr><td>
<table width='100%' cellpadding='0' cellspacing='0'>
  <tr><th align='left'><font size='-1' color='black'>File</font></th><th align='right'><font size='-1' color='black'>Size (kb)</font></th><th align='right'><font size='-1' color='black'>&nbsp; Headers (b)</font></th><th align='right'><font size='-1' color='black'>&nbsp; % of page</font></th></tr><tr><td colspan='4'><hr noshade='noshade' size='1' /></td></tr>  <tr><td><font color='black' size='-1'>/index.html</font></td><td align='right'><font color='black' size='-1'>0.5</font></td><td align='right'><font color='black' size='-1'>188</font></td><td align='right'><font color='black' size='-1'>0%</font></td></tr>
  <tr><td><font color='black' size='-1'>Gtext (\"roxen.com\")</font></td><td align='right'><font color='black' size='-1'>1.5</font></td><td align='right'><font color='black' size='-1'>189</font></td><td align='right'><font color='black' size='-1'>1%</font></td></tr>
  <tr><td><font color='black' size='-1'>/pic/apples.jpeg</font></td><td align='right'><font color='black' size='-1'>96.6</font></td><td align='right'><font color='black' size='-1'>163</font></td><td align='right'><font color='black' size='-1'>97%</font></td></tr>

<tr><td><font color='black' size='-1'><b>Total size:</b></font></td><td align='right'><font color='black' size='-1'>98.7</font></td><td align='right'><font color='black' size='-1'>540</font></td><td>&nbsp;</td></tr><tr><td colspan='4'><hr noshade='noshade' size='1' /></td></tr></table>
<b><font size='-1'>Estimated download time:</font></b> (bandwidth in kb/s)
<table><tr><td align='right'><font color='darkorange' size='-1'><b>28.8</b></font>:</td><td align='right'><font color='darkorange' size='-1'>28s</font></td>
<td align='right'><font color='darkred' size='-1'><b>56.0</b></font>:</td><td align='right'><font color='darkred' size='-1'>15s</font></td>
<td align='right'><font color='darkred' size='-1'><b>64.0</b></font>:</td><td align='right'><font color='darkred' size='-1'>13s</font></td>
</tr>
<tr><td align='right'><font color='darkgreen' size='-1'><b>256.0</b></font>:</td><td align='right'><font color='darkgreen' size='-1'>3s</font></td>
<td align='right'><font color='darkgreen' size='-1'><b>384.0</b></font>:</td><td align='right'><font color='darkgreen' size='-1'>2s</font></td>
<td align='right'><font color='darkgreen' size='-1'><b>1024.0</b></font>:</td><td align='right'><font color='darkgreen' size='-1'>1s</font></td>
</tr>
<tr></tr>
</table><hr noshade='noshade' size='1' /><table></table></td></tr>
</table>
</td></tr></table>
</ex-html>
</desc>

<attr name='page' value='path'>
 <p>Calculate size and downloadtime for another page than the current.</p>
</attr>

<attr name='include' value='summary,details,dltime,suggestions'>
 <p>What information to present.</p>
</attr>

<attr name='speeds' value='28.8,56.0,64.0,256.0,384.0,1024.0'>
 <p>Show the time it will take to download a page using the specified
 speed(s) in kbit/s.</p>
</attr>

<ex-box>
 <page-size
  page='../'
  include='summary,details,dltime,suggestions'
  speeds='28.8,56.0,64.0,256.0,384.0,1024.0'
 />
</ex-box>",
    ]);
#endif
