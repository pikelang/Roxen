// This is a roxen module. Copyright © 2000 - 2001, Roxen IS.
//

#include <module.h>
inherit "module";

constant cvs_version = "$Id: additional_rxml.pike,v 1.37 2004/08/20 18:17:29 _cvs_stenitzer Exp $";
constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Tags: Additional RXML tags";
constant module_doc  = "This module provides some more complex and not as widely used RXML tags.";

class TagDice {
  inherit RXML.Tag;
  constant name = "dice";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    string do_return(RequestID id) {
      NOCACHE();
      if(!args->type) args->type="D6";
      args->type = replace( args->type, "T", "D" );
      int value;
      args->type=replace(args->type, "-", "+-");
      foreach(args->type/"+", string dice) {
	if(has_value(dice, "D")) {
	  if(dice[0]=='D')
	    value+=random((int)dice[1..])+1;
	  else {
	    array(int) x=(array(int))(dice/"D");
	    if(sizeof(x)!=2)
	      RXML.parse_error("Malformed dice type.\n");
	    value+=x[0]*(random(x[1])+1);
	  }
	}
	else
	  value+=(int)dice;
      }

      if(args->variable)
	RXML.user_set_var(args->variable, value, args->scope);
      else
	result=(string)value;

      return 0;
    }
  }
}

class TagInsertLocate {
  inherit RXML.Tag;
  constant name= "insert";
  constant plugin_name = "locate";

  RXML.Type get_type( mapping args )
  {
    if (args->quote=="html")
      return RXML.t_text;
    return RXML.t_xml;
  }

  string get_data(string var, mapping args, RequestID id)
  {
    array(string) result;
    
    result = VFS.find_above_read( id->not_query, var, id );

    if( !result )
      RXML.run_error("Cannot locate any file named "+var+".\n");

    return result[1];
  }  
}

class TagCharset
{
  inherit RXML.Tag;
  constant name="charset";
  RXML.Type content_type = RXML.t_same;

  class Frame
  {
    inherit RXML.Frame;
    array do_return( RequestID id )
    {
      if( args->in && catch {
	content=Locale.Charset.decoder( args->in )->feed( content )->drain();
      })
	RXML.run_error("Illegal charset, or unable to decode data: %s\n",
		       args->in );
      if( args->out && id->set_output_charset)
	id->set_output_charset( args->out );
      result_type = result_type (RXML.PXml);
      result="";
      return ({content});
    }
  }
}

class TagRecode
{
  inherit RXML.Tag;
  constant name="recode";
  mapping(string:RXML.Type) opt_arg_types = ([
    "from" : RXML.t_text(RXML.PEnt),
    "to"   : RXML.t_text(RXML.PEnt),
  ]);

  class Frame
  {
    inherit RXML.Frame;
    array do_return( RequestID id )
    {
      if( !content ) content = "";

      if( args->from && catch {
	content=Locale.Charset.decoder( args->from )->feed( content )->drain();
      })
	RXML.run_error("Illegal charset, or unable to decode data: %s\n",
		       args->from );
      if( args->to && catch {
	content=Locale.Charset.encoder( args->to )->feed( content )->drain();
      })
	RXML.run_error("Illegal charset, or unable to encode data: %s\n",
		       args->to );
      return ({ content });
    }
  }
}

string simpletag_autoformat(string tag, mapping m, string s, RequestID id)
{
  s-="\r";

  string p=(m["class"]?"<p class=\""+m["class"]+"\">":"<p>");

  if(!m->nonbsp)
  {
    s = replace(s, "\n ", "\n&nbsp;"); // "|\n |"      => "|\n&nbsp;|"
    s = replace(s, "  ", "&nbsp; ");  //  "|   |"      => "|&nbsp;  |"
    s = replace(s, "  ", " &nbsp;"); //   "|&nbsp;  |" => "|&nbsp; &nbsp;|"
  }

  if(!m->nobr) {
    s = replace(s, "\n", "<br />\n");
    if(m->p) {
      if(has_value(s, "<br />\n<br />\n")) s=p+s;
      s = replace(s, "<br />\n<br />\n", "\n</p>"+p+"\n");
      if(sizeof(s)>3 && s[0..2]!="<p>" && s[0..2]!="<p ")
        s=p+s;
      if(s[..sizeof(s)-4]==p)
        return s[..sizeof(s)-4];
      else
        return s+"</p>";
    }
    return s;
  }

  if(m->p) {
    if(has_value(s, "\n\n")) s=p+s;
      s = replace(s, "\n\n", "\n</p>"+p+"\n");
      if(sizeof(s)>3 && s[0..2]!="<p>" && s[0..2]!="<p ")
        s=p+s;
      if(s[..sizeof(s)-4]==p)
        return s[..sizeof(s)-4];
      else
        return s+"</p>";
    }

  return s;
}

class Smallcapsstr (string bigtag, string smalltag, mapping bigarg, mapping smallarg)
{
  constant UNDEF=0, BIG=1, SMALL=2;
  static string text="",part="";
  static int last=UNDEF;

  string _sprintf(int t) {
    return "Smallcapsstr("+bigtag+","+smalltag+")";
  }

  void add(string char) {
    part+=char;
  }

  void add_big(string char) {
    if(last!=BIG) flush_part();
    part+=char;
    last=BIG;
  }

  void add_small(string char) {
    if(last!=SMALL) flush_part();
    part+=char;
    last=SMALL;
  }

  void write(string txt) {
    if(last!=UNDEF) flush_part();
    part+=txt;
  }

  void flush_part() {
    switch(last){
    case UNDEF:
    default:
      text+=part;
      break;
    case BIG:
      text+=RXML.t_xml->format_tag(bigtag, bigarg, part);
      break;
    case SMALL:
      text+=RXML.t_xml->format_tag(smalltag, smallarg, part);
      break;
    }
    part="";
    last=UNDEF;
  }

  string value() {
    if(last!=UNDEF) flush_part();
    return text;
  }
}

string simpletag_smallcaps(string t, mapping m, string s)
{
  Smallcapsstr ret;
  string spc=m->space?"&nbsp;":"";
  m_delete(m, "space");
  mapping bm=([]), sm=([]);
  if(m["class"] || m->bigclass) {
    bm=(["class":(m->bigclass||m["class"])]);
    m_delete(m, "bigclass");
  }
  if(m["class"] || m->smallclass) {
    sm=(["class":(m->smallclass||m["class"])]);
    m_delete(m, "smallclass");
  }

  if(m->size) {
    bm+=(["size":m->size]);
    if(m->size[0]=='+' && (int)m->size>1)
      sm+=(["size":m->small||"+"+((int)m->size-1)]);
    else
      sm+=(["size":m->small||(string)((int)m->size-1)]);
    m_delete(m, "small");
    ret=Smallcapsstr("font","font", m+bm, m+sm);
  }
  else
    ret=Smallcapsstr("big","small", m+bm, m+sm);

  for(int i=0; i<sizeof(s); i++)
    if(s[i]=='<') {
      int j;
      for(j=i; j<sizeof(s) && s[j]!='>'; j++);
      ret->write(s[i..j]);
      i+=j-1;
    }
    else if(s[i]<=32)
      ret->add_small(s[i..i]);
    else if(lower_case(s[i..i])==s[i..i])
      ret->add_small(upper_case(s[i..i])+spc);
    else if(upper_case(s[i..i])==s[i..i])
      ret->add_big(s[i..i]+spc);
    else
      ret->add(s[i..i]+spc);

  return ret->value();
}

string simpletag_random(string tag, mapping m, string s, RequestID id)
{
  NOCACHE();
  array q = s/(m->separator || m->sep || "\n");
  int index;
  if(m->seed)
    index = array_sscanf(Crypto.SHA1.hash(m->seed), "%4c")[0]%sizeof(q);
  else
    index = random(sizeof(q));

  return q[index];
}

class TagIfDate {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "date";

  int eval(string date, RequestID id, mapping m) {
    CACHE(60); // One minute accuracy is probably good enough...
    int a, b;
    mapping t = ([]);

    date = replace(date, "-", "");
    if(sizeof(date)!=8 && sizeof(date)!=6)
      RXML.run_error("If date attribute doesn't conform to YYYYMMDD syntax.");
    if(sscanf(date, "%04d%02d%02d", t->year, t->mon, t->mday)==3)
      t->year-=1900;
    else if(sscanf(date, "%02d%02d%02d", t->year, t->mon, t->mday)!=3)
      RXML.run_error("If date attribute doesn't conform to YYYYMMDD syntax.");

    if(t->year>70) {
      t->mon--;
      a = mktime(t);
    }

    t = localtime(time(1));
    b = mktime(t - (["hour": 1, "min": 1, "sec": 1, "isdst": 1, "timezone": 1]));

    // Catch funny guys
    if(m->before && m->after) {
      if(!m->inclusive)
	return 0;
      m_delete(m, "before");
      m_delete(m, "after");
    }

    if( (m->inclusive || !(m->before || m->after)) && a==b)
      return 1;

    if(m->before && a>b)
      return 1;

    if(m->after && a<b)
      return 1;

    return 0;
  }
}

class TagIfTime {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "time";

  int eval(string ti, RequestID id, mapping m) {
    CACHE(time(1)%60); // minute resolution...

    int|object a, b, d;
    
    if(sizeof(ti) <= 5 /* Format is hhmm or hh:mm. */)
    {
	    mapping c = localtime(time(1));
	    
	    b=(int)sprintf("%02d%02d", c->hour, c->min);
	    a=(int)replace(ti,":","");

	    if(m->until)
		    d = (int)m->until;
		    
    }
    else /* Format is ISO8601 yyyy-mm-dd or yyyy-mm-ddThh:mm etc. */
    {
	    if(has_value(ti, "T"))
	    {
		    /* The Calendar module can for some reason not
		     * handle the ISO8601 standard "T" extension. */
		    a = Calendar.ISO.dwim_time(replace(ti, "T", " "))->minute();
		    b = Calendar.ISO.Minute();
	    }
	    else
	    {
		    a = Calendar.ISO.dwim_day(ti);
		    b = Calendar.ISO.Day();
	    }

	    if(m->until)
		    if(has_value(m->until, "T"))
			    /* The Calendar module can for some reason not
			     * handle the ISO8601 standard "T" extension. */
			    d = Calendar.ISO.dwim_time(replace(m->until, "T", " "))->minute();
		    else
			    d = Calendar.ISO.dwim_day(m->until);
    }
    
    if(d)
    {
      if (d > a && (b > a && b < d) )
	return 1;
      if (d < a && (b > a || b < d) )
	return 1;
      if (m->inclusive && ( b==a || b==d ) )
	return 1;
      return 0;
    }
    else if( (m->inclusive || !(m->before || m->after)) && a==b )
      return 1;
    if(m->before && a>b)
      return 1;
    else if(m->after && a<b)
      return 1;
  }
}

class TagIfUser {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "user";

  int eval(string u, RequestID id, mapping m)
  {
    object db;
    if( m->database )
      db = id->conf->find_user_database( m->database );
    User uid = id->conf->authenticate( id, db );

    if( !uid && !id->auth )
      return 0;

    NOCACHE();

    if( u == "any" )
      if( m->file )
	// Note: This uses the compatibility interface. Should probably
	// be fixed.
	return match_user( id->auth, id->auth[1], m->file, !!m->wwwfile, id);
      else
	return !!u;
    else
      if(m->file)
	// Note: This uses the compatibility interface. Should probably
	// be fixed.
	return match_user(id->auth,u,m->file,!!m->wwwfile,id);
      else
	return has_value(u/",", uid->name());
  }

  private int match_user(array u, string user, string f, int wwwfile, RequestID id) {
    string s, pass;
    if(u[1]!=user)
      return 0;
    if(!wwwfile)
      s=Stdio.read_bytes(f);
    else
      s=id->conf->try_get_file(Roxen.fix_relative(f,id), id);
    return ((pass=simple_parse_users_file(s, u[1])) &&
	    (u[0] || match_passwd(u[2], pass)));
  }

  private int match_passwd(string try, string org) {
    if(!sizeof(org)) return 1;
    if(crypt(try, org)) return 1;
  }

  private string simple_parse_users_file(string file, string u) {
    if(!file) return 0;
    foreach(file/"\n", string line)
      {
	array(string) arr = line/":";
	if (arr[0] == u && sizeof(arr) > 1)
	  return(arr[1]);
      }
  }
}

class TagIfGroup {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "group";

  int eval(string u, RequestID id, mapping m) {
    object db;
    if( m->database )
      db = id->conf->find_user_database( m->database );
    User uid = id->conf->authenticate( id, db );

    if( !uid && !id->auth )
      return 0;

    NOCACHE();
    if( m->groupfile )
      return ((m->groupfile && sizeof(m->groupfile))
	      && group_member(id->auth, u, m->groupfile, id));
    return sizeof( uid->groups() & (u/"," )) > 0;
  }

  private int group_member(array auth, string group, string groupfile, RequestID id) {
    if(!auth)
      return 0; // No auth sent

    string s;
    catch { s = Stdio.read_bytes(groupfile); };

    if (!s)
      s = id->conf->try_get_file( Roxen.fix_relative( groupfile, id), id );

    if (!s) return 0;

    s = replace(s,({" ","\t","\r" }), ({"","","" }));

    multiset(string) members = simple_parse_group_file(s, group);
    return members[auth[1]];
  }

  private multiset simple_parse_group_file(string file, string g) {
    multiset res = (<>);
    array(string) arr ;
    foreach(file/"\n", string line)
      if(sizeof(arr = line/":")>1 && (arr[0] == g))
	res += (< @arr[-1]/"," >);
    return res;
  }
}

class TagIfInternalExists {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "internal-exists";

  int eval(string u, RequestID id) {
    CACHE(5);
    return id->conf->is_file(Roxen.fix_relative(u, id), id, 1);
  }
}

class TagIfNserious {
  inherit RXML.Tag;
  constant name = "if";
  constant plugin_name = "nserious";

  int eval() {
#ifdef NSERIOUS
    return 1;
#else
    return 0;
#endif
  }
}

class TagInsertRealfile {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "realfile";

  string get_data(string var, mapping args, RequestID id) {
    string filename=id->conf->real_file(Roxen.fix_relative(var, id), id);
    if(!filename)
      RXML.run_error("Could not find the file %s.\n", Roxen.fix_relative(var, id));
    Stdio.File file=Stdio.File(filename, "r");
    if(file)
      return file->read();
    RXML.run_error("Could not open the file %s.\n", Roxen.fix_relative(var, id));
  }
}

string simpletag_apre(string tag, mapping m, string q, RequestID id)
{
  string href;

  if(m->href) {
    href=m_delete(m, "href");
    array(string) split = href/":";
    if ((sizeof(split) > 1) && (sizeof(split[0]/"/") == 1))
      return RXML.t_xml->format_tag("a", m, q);
    href=Roxen.strip_prestate(Roxen.fix_relative(href, id));
  }
  else
    href=Roxen.strip_prestate(Roxen.strip_config(id->raw_url));

  if(!sizeof(href))
    href="";

  multiset prestate = (< @indices(id->prestate) >);

  // FIXME: add and drop should handle t_array
  if(m->add)
    foreach((m_delete(m, "add") - " ")/",", string s)
      prestate[s]=1;

  if(m->drop)
    foreach((m_delete(m,"drop") - " ")/",", string s)
      prestate[s]=0;

  m->href = Roxen.add_pre_state(href, prestate);
  return RXML.t_xml->format_tag("a", m, q);
}

string simpletag_aconf(string tag, mapping m,
		       string q, RequestID id)
{
  string href;

  if(m->href) {
    href=m_delete(m, "href");
    if (search(href, ":") == search(href, "//")-1)
      RXML.parse_error("It is not possible to add configs to absolute URLs.\n");
    href=Roxen.fix_relative(href, id);    
  }
  else
    href=Roxen.strip_prestate(Roxen.strip_config(id->raw_url));

  array cookies = ({});
  // FIXME: add and drop should handle t_array
  if(m->add)
    foreach((m_delete(m,"add") - " ")/",", string s)
      cookies+=({s});

  if(m->drop)
    foreach((m_delete(m,"drop") - " ")/",", string s)
      cookies+=({"-"+s});

  m->href = Roxen.add_config(href, cookies, id->prestate);
  return RXML.t_xml->format_tag("a", m, q);
}

class TagInsertVariable {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "variable";

  string get_data(string var, mapping args, RequestID id) {
    if(zero_type(RXML.user_get_var(var, args->scope)))
      RXML.run_error("No such variable ("+var+").\n", id);
    if(args->index) {
      mixed data = RXML.user_get_var(var, args->scope);
      if(intp(data) || floatp(data))
	RXML.run_error("Can not index numbers.\n");
      if(stringp(data)) {
	if(args->split)
	  data = data / args->split;
	else
	  data = ({ data });
      }
      if(arrayp(data)) {
	int index = (int)args->index;
	if(index<0) index=sizeof(data)+index+1;
	if(sizeof(data)<index || index<1)
	  RXML.run_error("Index out of range.\n");
	else
	  return data[index-1];
      }
      if(data[args->index]) return data[args->index];
      RXML.run_error("Could not index variable data\n");
    }
    return (string)RXML.user_get_var(var, args->scope);
  }
}

class TagPICData
{
  inherit RXML.Tag;
  constant name = "cdata";
  constant flags = RXML.FLAG_PROC_INSTR;
  RXML.Type content_type = RXML.t_text;
  class Frame
  {
    inherit RXML.Frame;
    array do_return (RequestID id)
    {
      result_type = RXML.t_text;
      result = content[1..];
      return 0;
    }
  }
}

class TagStrLen {
  inherit RXML.Tag;
  constant name = "sizeof";
  constant flags = RXML.FLAG_DONT_REPORT_ERRORS;

  class Frame {
    inherit RXML.Frame;
    array do_return() {
      if(!stringp(content)) {
	result="0";
	return 0;
      }
      result = (string)sizeof(content);
    }
  }
}

class TagNumber {
  inherit RXML.Tag;
  constant name = "number";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      if(args->type=="roman") return ({ String.int2roman((int)args->num) });
      if(args->type=="memory") return ({ String.int2size((int)args->num) });
      result=core.language(args->lang||args->language||
                            RXML_CONTEXT->misc->theme_language,
			    args->type||"number",id)( (int)args->num );
    }
  }
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
  "dice":#"<desc type='cont'><p><short>
 Simulates a D&amp;D style dice algorithm.</short></p></desc>

<attr name='type' value='string' default='D6'><p>
 Describes the dices. A six sided dice is called 'D6' or '1D6', while
 two eight sided dices is called '2D8' or 'D8+D8'. Constants may also
 be used, so that a random number between 10 and 20 could be written
 as 'D9+10' (excluding 10 and 20, including 10 and 20 would be 'D11+9').
 The character 'T' may be used instead of 'D'.</p>
</attr>",

//----------------------------------------------------------------------

"smallcaps":#"<desc type='cont'><p><short>
 Prints the contents in smallcaps.</short> If the size attribute is
 given, font tags will be used, otherwise big and small tags will be
 used.</p>

<ex><smallcaps>ChiliMoon</smallcaps></ex>
</desc>

<attr name='space'>
 <p>Put a space between every character.</p>
<ex><smallcaps space=''>ChiliMoon</smallcaps></ex>
</attr>

<attr name='class' value='string'>
 <p>Apply this cascading style sheet (CSS) style on all elements.</p>
</attr>

<attr name='smallclass' value='string'>
 <p>Apply this cascading style sheet (CSS) style on all small elements.</p>
</attr>

<attr name='bigclass' value='string'>
 <p>Apply this cascading style sheet (CSS) style on all big elements.</p>
</attr>

<attr name='size' value='number'>
 <p>Use font tags, and this number as big size.</p>
</attr>

<attr name='small' value='number' default='size-1'>
 <p>Size of the small tags. Only applies when size is specified.</p>

 <ex><smallcaps size='6' small='2'>ChiliMoon</smallcaps></ex>
</attr>",

//----------------------------------------------------------------------

"charset":#"<desc type='both'><p>
 <short>Set output character set.</short>
 The tag can be used to decide upon the final encoding of the resulting page.
 All character sets listed in <a href='http://rfc.roxen.com/1345'>RFC 1345</a>
 are supported.
</p>
</desc>

<attr name='in' value='Character set'><p>
 Converts the contents of the charset tag from the character set indicated
 by this attribute to the internal text representation.</p>

 <note><p>This attribute is depricated, use &lt;recode 
 from=\"\"&gt;...&lt;/recode&gt; instead.</p></note>
</attr>

<attr name='out' value='Character set'><p>
 Sets the output conversion character set of the current request. The page
 will be sent encoded with the indicated character set.</p>
</attr>
",

//----------------------------------------------------------------------

"recode":#"<desc type='cont'><p>
 <short>Converts between character sets.</short>
 The tag can be used both to decode texts encoded in strange character
 encoding schemas, and encode internal data to a specified encoding
 scheme. All character sets listed in <a
 href='http://rfc.roxen.com/1345'>RFC 1345</a> are supported.
</p>
</desc>

<attr name='from' value='Character set'><p>
 Converts the contents of the charset tag from the character set indicated
 by this attribute to the internal text representation. Useful for decoding
 data stored in a database.</p>
</attr>

<attr name='to' value='Character set'><p>
 Converts the contents of the charset tag from the internal representation
 to the character set indicated by this attribute. Useful for encoding data
 before storing it into a database.</p>
</attr>
",

//----------------------------------------------------------------------

"random":#"<desc type='cont'><p><short>
 Randomly chooses a message from its contents.</short>
</p></desc>

<attr name='separator' value='string'>
 <p>The separator used to separate the messages, by default newline.</p>

<ex><random separator='#'>Foo#Bar#Baz</random></ex>
</attr>

<attr name='seed' value='string'>
 <p>Enables you to use a seed that determines which message to choose.</p>

<ex-box>Tip of the day:
<set variable='var.day'><date type='iso' date=''/></set>
<random seed='var.day'><insert file='tips.txt'/></random></ex-box>
</attr>",

//----------------------------------------------------------------------

"if#date":#"<desc type='plugin'><p><short>
 Is the date yyyymmdd?</short> The attributes before, after and
 inclusive modifies the behavior. This is a <i>Utils</i> plugin.
</p></desc>
<attr name='date' value='yyyymmdd | yyyy-mm-dd' required='required'><p>
 Choose what date to test.</p>
</attr>

<attr name='after'><p>
 The date after todays date.</p>
</attr>

<attr name='before'><p>
 The date before todays date.</p>
</attr>

<attr name='inclusive'><p>
 Adds todays date to after and before.</p>

 <ex>
  <if date='19991231' before='' inclusive=''>
     - 19991231
  </if>
  <else>
    20000101 -
  </else>
 </ex>
</attr>",

//----------------------------------------------------------------------

"if#time":#"<desc type='plugin'><p><short>
 Is the time hhmm, hh:mm, yyyy-mm-dd or yyyy-mm-ddThh:mm?</short> The attributes before, after,
 inclusive and until modifies the behavior. This is a <i>Utils</i> plugin.
</p></desc>
<attr name='time' value='hhmm|yyyy-mm-dd|yyyy-mm-ddThh:mm' required='required'><p>
 Choose what time to test.</p>
</attr>

<attr name='after'><p>
 The time after present time.</p>
</attr>

<attr name='before'><p>
 The time before present time.</p>
</attr>

<attr name='until' value='hhmm|yyyy-mm-dd|yyyy-mm-ddThh:mm'><p>
 Gives true for the time range between present time and the time value of 'until'.</p>
</attr>

<attr name='inclusive'><p>
 Adds present time to after and before.</p>

<ex-box>
  <if time='1200' before='' inclusive=''>
    ante meridiem
  </if>
  <else>
    post meridiem
  </else>
</ex-box>
</attr>",

//----------------------------------------------------------------------

"insert#realfile":#"<desc type='plugin'><p><short>
 Inserts a raw, unparsed file.</short> The disadvantage with the
 realfile plugin compared to the file plugin is that the realfile
 plugin needs the inserted file to exist, and can't fetch files from e.g.
 an arbitrary location module. Note that the realfile insert plugin
 can not fetch files from outside the virtual file system.
</p></desc>

<attr name='realfile' value='string'>
 <p>The virtual path to the file to be inserted.</p>
</attr>",

//----------------------------------------------------------------------

"apre":#"<desc type='cont'><p><short>

 Creates a link that can modify prestates.</short> Prestates can be
 seen as valueless cookies or toggles that are easily modified by the
 user. The prestates are added to the URL. If you set the prestate
 \"no-images\" on \"http://www.demolabs.com/index.html\" the URL would
 be \"http://www.demolabs.com/(no-images)/\". Use <xref
 href='../if/if_prestate.tag' /> to test for the presence of a
 prestate. <tag>apre</tag> works just like the <tag>a href='...'</tag>
 container, but if no \"href\" attribute is specified, the current
 page is used. </p>

</desc>

<attr name='href' value='uri'>
 <p>Indicates which page should be linked to, if any other than the
 present one.</p>
</attr>

<attr name='add' value='string'>
 <p>The prestate or prestates that should be added, in a comma
 separated list.</p>
</attr>

<attr name='drop' value='string'>
 <p>The prestate or prestates that should be dropped, in a comma separated
 list.</p>
</attr>

<attr name='class' value='string'>
 <p>This cascading style sheet (CSS) class definition will apply to
 the a-element.</p>
</attr>",

//----------------------------------------------------------------------

"autoformat":#"<desc type='cont'><p><short hide='hide'>
 Replaces newlines with <tag>br/</tag>:s'.</short>Replaces newlines with
 <tag>br /</tag>:s'.</p>

<ex><autoformat>
It is almost like
using the pre tag.
</autoformat></ex>
</desc>

<attr name='p'>
 <p>Replace empty lines with <tag>p</tag>:s.</p>
<ex><autoformat p=''>
It is almost like

using the pre tag.
</autoformat></ex>
</attr>

<attr name='nobr'>
 <p>Do not replace newlines with <tag>br /</tag>:s.</p>
</attr>

<attr name='nonbsp'><p>
 Do not turn consecutive spaces into interleaved
 breakable/nonbreakable spaces. When this attribute is not given, the
 tag will behave more or less like HTML:s <tag>pre</tag> tag, making
 whitespace indention work, without the usually unwanted effect of
 really long lines extending the browser window width.</p>
</attr>

<attr name='class' value='string'>
 <p>This cascading style sheet (CSS) definition will be applied on the
 p elements.</p>
</attr>",

//----------------------------------------------------------------------

"aconf":#"<desc type='cont'><p><short>
 Creates a link that can modify the config states in the cookie
 RoxenConfig.</short> In practice it will add &lt;keyword&gt;/ right
 after the server in the URL. E.g. if you want to remove the config
 state bacon and add config state egg the
 first \"directory\" in the path will be &lt;-bacon,egg&gt;. If the
 user follows this link the WebServer will understand how the
 RoxenConfig cookie should be modified and will send a new cookie
 along with a redirect to the given url, but with the first
 \"directory\" removed. The presence of a certain config state can be
 detected by the <xref href='../if/if_config.tag'/> tag.</p>
</desc>

<attr name='href' value='uri'>
 <p>Indicates which page should be linked to, if any other than the
 present one.</p>
</attr>

<attr name='add' value='string'>
 <p>The config state, or config states that should be added, in a comma
 separated list.</p>
</attr>

<attr name='drop' value='string'>
 <p>The config state, or config states that should be dropped, in a comma
 separated list.</p>
</attr>

<attr name='class' value='string'>
 <p>This cascading style sheet (CSS) class definition will apply to
 the a-element.</p>

 <p>All other attributes will be inherited by the generated <tag>a</tag> tag.</p>
</attr>",

//----------------------------------------------------------------------

"insert#variable":#"<desc type='plugin'><p><short>
 Inserts the value of a variable.</short>
</p></desc>

<attr name='variable' value='string'>
 <p>The name of the variable.</p>
</attr>

<attr name='scope' value='string'>
 <p>The name of the scope, unless given in the variable attribute.</p>
</attr>

<attr name='index' value='number'>
 <p>If the value of the variable is an array, the element with this
 index number will be inserted. 1 is the first element. -1 is the last
 element.</p>
</attr>

<attr name='split' value='string'>
 <p>A string with which the variable value should be splitted into an
 array, so that the index attribute may be used.</p>
</attr>",

//----------------------------------------------------------------------

"?cdata": #"<desc type='pi'><p><short>
 The content is inserted as a literal.</short> I.e. any XML markup
 characters are encoded with character references. The first
 whitespace character (i.e. the one directly after the \"cdata\" name)
 is discarded.</p>

 <p>This processing instruction is just like the &lt;![CDATA[ ]]&gt;
 directive but parsed by the RXML parser, which can be useful to
 satisfy browsers that does not handle &lt;![CDATA[ ]]&gt; correctly.</p>
</desc>",

//----------------------------------------------------------------------

"number":#"<desc type='tag'><p><short>
 Prints a number as a word.</short>
</p></desc>

<attr name='num' value='number' required='required'><p>
 Print this number.</p>
<ex><number num='4711'/></ex>
</attr>

<attr name='language' value='langcodes'><p>
 The language to use.</p>
 <p><lang/></p>
 <ex>Mitt favoritnummer är <number num='11' language='sv'/>.</ex>
 <ex>Il mio numero preferito è <number num='15' language='it'/>.</ex>
</attr>

<attr name='type' value='number|ordered|roman|memory' default='number'><p>
 Sets output format.</p>

 <ex>It was his <number num='15' type='ordered'/> birthday yesterday.</ex>
 <ex>Only <number num='274589226' type='memory'/> left on the Internet.</ex>
 <ex>Spock Garfield <number num='17' type='roman'/> rests here.</ex>
</attr>",

//----------------------------------------------------------------------

"sizeof":#"<desc type='cont'><p><short>
 Returns the length of the contents.</short></p>

 <ex>There are <sizeof>foo bar gazonk</sizeof> characters
 inside the tag.</ex>
</desc>",

//----------------------------------------------------------------------


]);
#endif
