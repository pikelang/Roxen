/*
 * $Id: ldaptag.pike,v 1.1 1999/04/24 16:37:51 js Exp $
 *
 * A module for Roxen Challenger, which gives the tags
 * <LDAP>, <LDAPOUTPUT> (with subtag <LDAPFOREACH>) and <LDAPELSE>
 *
 * Honza Petrous
 *
 *
 * TODO: ldap_last_error: not works at all!
 *	 show_internals: checking for quit mode
 *	 backtrace

!!! Needs more testings, mainly for error handling !!!

   History:

     1998-03-17 v1.0	initial version (only for Ldap module!)
     1998-07-03 v1.1	modified for Protocols.LDAP module
			corrected one-level parsing of LDAPFOREACH tag
     1998-07-09 v1.2	LDAPFOR: corrected checking of attribute to case
			insensitive
     1998-07-10 v1.2a	LDAPFOR: corrected sizechecking for 'labeleduri*'
     1998-07-13 v1.2b	LDAP: corrected attribute values reading
			corrected typo: fialed -> failed (Thx Matt Brookes)
     1998-08-18 v1.2	release version
     1998-11-10 v1.4	LDAPOUTPUT: added checking for number of returned
			entries
			LDAPOUTPUT: added flag 'norem'
     1998-11-10 v1.5	read_attrs: added support for 'replace' op
     1999-02-22 v1.6	Removed OLD_LDAP_API support

 */

constant cvs_version="$Id: ldaptag.pike,v 1.1 1999/04/24 16:37:51 js Exp $";
//constant thread_safe=0;
#include <module.h>

inherit "module";
inherit "roxenlib";

import Array;

#define LDAPTAGDEBUG
#ifdef LDAPTAGDEBUG
#define DEBUGLOG(s) perror("LDAPtag: " + s + "\n")
#else
#define DEBUGLOG(s)
#endif

string status_connect_server = "";
string status_connect_last = "";
int status_connect_nums = 0;
string ldap_last_error = "";
//mapping status_connect_unsuc = ([]);

/*
 * Module interface functions
 */

array register_module()
{
  return( ({ MODULE_PARSER,
	     "LDAP module",
	     "This module gives the tag &lt;LDAP&gt; and containers"
	     " &lt;LDAPOUTPUT&gt;, &lt;LDAPFOR&gt; and &lt;LDAPELSE&gt;<br>\n"
	     "Usage:<ul>\n"
	     "<table border=0>\n"
	     "<tr><td valign=top><b>&lt;ldap&gt;</b></td>\n"
	     "<td>Executes an LDAP operation, but "
	     "doesn't do anything with the result. This is useful if "
	     "you do operation like ADD or MODIFY.</td></tr>\n"
	     "<tr><td valign=top><b>&lt;ldapoutput&gt;</b></td>\n"
	     "<td>Executes an LDAP search and "
             "replaces #-quoted attributes with the results. Second, "
	     "third, ... attribute value can be specified by "
	     "suffix \":n\" before #.<br>"
	     "Special attribute names are:<br>\n"
	     "<table border=0>\n"
	     "<tr><td valign=top>dn</td>\n"
	     "<td>gets DN of entry."
	     "<tr><td valign=top>labeledURIAnchor</td>\n"
	     "<td>gets anchor tag from attribute \"labeledURI\"</td>"
	     "<tr><td valign=top>labeledURIuri</td>\n"
	     "<td>gets URI part of attribute \"labeledURI\"</td>"
	     "<tr><td valign=top>labeledURIlabel</td>\n"
	     "<td>gets label part of attribute \"labeledURI\"</td>"
	     "</table><br>\n"
	     "# is "
             "quoted as ##.<br>The content inbetween &lt;ldapoutput&gt; and "
             "&lt;/ldapoutput&gt; is repeated once for every DN in the "
             "result.</td></tr>\n"
	     "<tr><td valign=top><b>&lt;ldapfor&gt;</b></td>\n"
	     "<td>Repeats content of tag for multiple attribute values."
	     "<br><b>Usable only within &lt;ldapoutput&gt; tag!</b><p>"
	     "Variable quoted by # is replaced by value.</td></tr>\n"
	     "<tr><td valign=top><b>&lt;ldapelse&gt;</b></td>\n"
	     "<td>Is executed only if error ocurred with last &lt;ldap&gt; or "
	     "&lt;ldapoutput&gt; tags.<p>"
	     "Content is parsed and variable #ldaperror# is replaced "
	     "with last error message.</td></tr>\n"
	     "</table></ul>\n"
	     "The following attributes are used commonly by tags "
	     "&lt;ldap&gt; and &lt;ldapoutput&gt;:<ul>\n"
	     "<table border=0>\n"
	     "<tr><td valign=top><b>host<b></td>"
	     "<td>The hostname of the machine the LDAP-server runs on.</td></tr>\n"
	     "<tr><td valign=top><b>user</b></td>"
	     "<td>The name of the user to access the directory with.</td></tr>\n"
	     "<tr><td valign=top><b>password</b></td>"
	     "<td>The password to access the directory.</td></tr>\n"
	     "<tr><td valign=top><b>basedn</b></td>"
	     "<td>The base DN to access the directory.</td></tr>\n"
	     "</table></ul><p>\n"
	     "The following attributes are used by &lt;ldap&gt; tag:<ul>\n"
	     "<table border=0>\n"
	     "<tr><td valign=top><b>dn</b></td>"
	     "<td>The value of DN for operation. <b>(REQUIRED)</b></td></tr>\n"
	     "<tr><td valign=top><b>op</b></td>"
	     "<td>The mode operation of access the directory. <b>(REQUIRED)</b><p>"
	     "Valid values are \"add\",\"delete\",\"modify\" and \"replace\".</td></tr>\n"
	     "<tr><td valign=top><b>attr</b></td>"
	     "<td>The attributes for operation.<p>"
	     "<b>(</b><i>attr_name1</i><b>:</b>['<i>value1</i>'[,...]]<b>)</b>[(...)]<p>"
	     "Example: attr=\"(cn:'Super User')(mail:'post@ahoy.org','root@bla.cz')(ou:)\"</td></tr>"
	     "</table></ul><p>\n"
	     "The following attributes are used by &lt;ldapoutput&gt; tag:<ul>\n"
	     "<table border=0>\n"
	     "<tr><td valign=top><b>filter</b></td>"
	     "<td>The filter for search operation. <b>(REQUIRED)<b/></td></tr>\n"
	     "<tr><td valign=top><b>scope</b></td>"
	     "<td>The scope to access the directory.<p>Valid values are"
	     " \"base\", \"onelevel\" and \"subtree\".</td></tr>\n"
	     "<tr><td valign=top><b>parse</b></td>"
	     "<td>If specified, the filter will be parsed by the "
	     "RXML-parser</td></tr>"
	     "</table></ul><p>\n"
	     "The following attributes are used by &lt;ldapfor&gt; tag:<ul>\n"
	     "<table border=0>\n"
	     "<tr><td valign=top><b>attr</b></td>"
	     "<td>The parsed attribute name. <b>(REQUIRED)<b/></td></tr>\n"
	     "<tr><td valign=top><b>index</b></td>"
	     "<td>The initial index value.<p>Index starts from 1."
	     "<br><i>Default value is 1 (from first value)</i>.</td></tr>\n"
	     "<tr><td valign=top><b>step</b></td>"
	     "<td>The increment value for index.<p><i>Default value "
	     "is 1 (index=index+1).</i></td></tr>"
	     "<tr><td valign=top><b>max</b></td>"
	     "<td>If specified, \"max\" value is returned.</td></tr>"
	     "</table></ul><p>\n"
	     "\n"
	     "<b>NOTE</b>: Specifying passwords in the documents may prove "
	     "to be a security hole if the module is not loaded for some "
	     "reason.<br>\n"
	     "<b>SEE ALSO</b>: The &lt;FORMOUTPUT&gt; tag can be "
	     "useful to generate the queries.<br>\n"
             "<p>&copy; 1998 Honza Petrous, distributed freely under GPL license.",
	     0,
	     1 }) );
}

/*
 * Tag handlers
 */

int|mapping(string:array(mixed)) read_attrs(string attrs, int op) {
// from string: (attname1:'val1','val2'...)(attname2:'val1',...) to
// ADD: (["attname1":({"val1","val2"...}), ...
// REPLACE|MODIFY: (["attname1":({op, "val1","val2"...}), ...

  array(string) atypes; // = ({"objectclass","cn","mail","o"});
  array(array(mixed)) avals; // = ({({op, "top","person"}),({op, "sysdept"}), ({op, "sysdept@unibase.cz", "xx@yy.cc"}),({op, "UniBASE Ltd."})});
  array(mixed) tmpvals, tmparr;
  string aval;
  mapping(string:array(mixed)) rv;
  int vcnt, ix, cnt = 0, flg = (op > 0);;

  if(flg)
    flg = 1;
  DEBUGLOG(sprintf("DEB: string: %O\n",attrs));
  if (sizeof(attrs / "(") < 2)
    return(0);
  atypes = allocate(sizeof(attrs / "(")-1);
  avals = allocate(sizeof(attrs / "(")-1);
  foreach(attrs / "(", string tmp)
    if (sizeof(tmp)) { // without empty '()'
      if ((ix = search(tmp, ":")) < 1) // missed ':' or is first char
	continue;
      //atypes[cnt] = (tmp / ":")[0];
      atypes[cnt] = tmp[..(ix-1)];
      //tmparr = tmp[(sizeof(atypes[cnt])+1)..] / ",";
      tmparr = tmp[(ix+1)..] / ",";
  DEBUGLOG(sprintf("DEB: tmparr: %O\n",tmparr));
      vcnt = sizeof(tmparr); // + 1;
      tmpvals = allocate(vcnt+flg);
      for (ix=0; ix<vcnt; ix++) {
	tmpvals[ix+flg] = (sscanf(tmparr[ix], "'%s'", aval))? aval : "";
      }
      if(flg)
	tmpvals[0] = op;
      avals[cnt] = tmpvals;
      cnt++;
    } // if

    /*if (avals[al] != ")") {
      // Missed right ')'
      return (0);
    }*/

  rv = mkmapping(atypes,avals);
  DEBUGLOG(sprintf("DEB: mapping: %O\n",rv));
  return rv;
}

string ldap_tag(string tag_name, mapping args,
		    object request_id, object f,
		    mapping defines, object fd)
{
  if (args->op && args->dn) {

    if (args->parse) {
      args->attr = parse_rxml(args->attr, request_id, f, defines);
    }

    string host = query("hostname");
    string basedn = query("basedn");
    string user = query("user");
    string password = query("password");
    int scopenum, rv, attrop;
    object con = 0, en = 0;
    mixed error;
    function dir_connect = request_id->conf->dir_connect;
    mapping(string:array(string)) attrval = ([]);

    if (args->host) {
      host = args->host;
      user = "";
      password = "";
    }
    if (args->basedn) {
      basedn = args->basedn;
      user = "";
      password = "";
      dir_connect = 0;
    }
    if (args->user) {
      user = args->user;
      password = "";
      dir_connect = 0;
    }
    if (args->password) {
      password = args->password;
      dir_connect = 0;
    }
    if (dir_connect) {
      error = catch(con = dir_connect(host));
    } else {
      //host = (lower_case(host) == "localhost")?"":host;
      error = catch(con = Protocols.LDAP.client(host));
      error |= catch(con->bind(user,password));
    }
    if (error || !objectp(con)) {
      ldap_last_error = "Couldn't connect to LDAP server." + "";
      return("<h1>Couldn't connect to LDAP server</h1><br>\n" +
	     ((master()->describe_backtrace(error)/"\n")*"<br>\n"));
    }

    /* add, delete or modify ? */
    status_connect_server = "host: " + host +
			    (sizeof(user)?(", user: "+user):"") +
			    (sizeof(password)?(", password: "+password):"");
    status_connect_last = ctime(time());
    status_connect_nums++;
    con->set_basedn(basedn);
    if (args->scope)
      switch (args->scope) {
          case "onelevel": scopenum = 1; break;
	  case "subtree": scopenum = 2; break;
	  default: scopenum = 0;
      }
    con->set_scope(scopenum);

    attrop = 0;
    if(args->op == "replace")
      attrop = 2; // ldap->modify with flag 'replace'
    if (args->attr && (args->op != "delete"))
      if(!(attrval = read_attrs(args->attr, attrop))) {
	// error
	ldap_last_error = "Attribute parse error: " + args->attr;
        return("<h1>Attribute parse error:" + args->attr + "</h1><br>\n" +
	       ((master()->describe_backtrace(error)/"\n")*"<br>\n"));
      }

    DEBUGLOG(args->op);
    DEBUGLOG(sprintf("%O",attrval));
    switch (args->op) {
      case "add": error = catch(rv = con->add(args->dn,attrval)); break;
      case "delete": error = catch(rv = con->delete(args->dn)); break;
      case "modify": error = catch(rv = con->modify(args->dn,attrval)); break;
      case "replace": error = catch(rv = con->modify(args->dn,attrval,1)); break;
      default:  ldap_last_error = "Operation \"" + args->op + "\" is unknown.";
		return("<h1>Operation \"" + args->op + "\" is unknown.</h1>\n" +
		((master()->describe_backtrace(error)/"\n")*"<br>\n"));
    }

    con->unbind();

    if (error || rv) {
      ldap_last_error = "LDAP Operation \"" + args->op + "\" failed: " + con->error_string();
      return("<h1>" + ldap_last_error + "</h1>\n" +
	     ((master()->describe_backtrace(error)/"\n")*"<br>\n"));
    }

    DEBUGLOG(rv?"<false>":"<true>");
    return(rv?"<false>":"<true>");
  }

  return("<!-- Missing attribute op= and/or dn= ! --><false>");

}

// Subcontainer <LDAPFOR> support functions

#define SUBTAG_VAL_S    "<ldapfor"
#define SUBTAG_VAL_E    "</ldapfor"
#define TAG_E           ">"

int find_subc0(string strbody) {
// Returns first char of the appearance of subtag

  int ix = 0, addrv = 0, cnt = 0;
  string strh = lower_case(strbody);

  if ((addrv = search(strh[ix..], SUBTAG_VAL_S))<0)
      return(-1);
  cnt = ix + addrv;
  ix += addrv + 1;
  if ((addrv = search(strh[ix..], TAG_E))<0)
      return(-1);
  ix += addrv + 1;
  if ((addrv = search(strh[ix..], SUBTAG_VAL_E))<0)
      return(-1);
  ix += addrv + 1;
  if ((addrv = search(strh[ix..], TAG_E))<0)
      return(-1);
  ix += addrv + 1;

  return(cnt);
}


array(int)|int find_subc(string strbody) {
// Returns first & last position of subcontainer

  int ix = 0, addrv = 0, cnt = 0;
  string strh = lower_case(strbody);

  if ((addrv = search(strh[ix..], SUBTAG_VAL_S))<0)
      return(-1);
  cnt = ix + addrv;
  ix += addrv + 1;
  if ((addrv = search(strh[ix..], TAG_E))<0)
      return(-1);
  ix += addrv + 1;
  if ((addrv = search(strh[ix..], SUBTAG_VAL_E))<0)
      return(-1);
  ix += addrv + 1;
  if ((addrv = search(strh[ix..], TAG_E))<0)
      return(-1);
  ix += addrv + 1;

  return(({cnt, ix-1}));
}

string recurse_parse_ldapfor(string contents, mapping m, object request_id)
{

  return parse_html(contents,([]),
	(["ldapfor":
	  lambda(string tag, mapping args, string contents, mapping m,
		 object request_id)
	  {
	     
	     if(args->attr)
		m->attr = lower_case(args->attr);
	     else
		contents = "<!-- Missing attribute attr= ! --><false>";
	     if(args->index)
		m->index = (int)args->index;
	     if(args->step)
		m->step = (int)args->step;
	     if(args->max)
		m->max = (int)args->max;
	     m->body = contents;
	     return("");
	  }
	]), m, request_id);
}

mapping(string:mixed) parse_subc(string contents, object id) {

    mapping m = (["attr":"","index":1,"step":1,"max":0,"body":""]);

    recurse_parse_ldapfor(contents, m, id);
    if(m->body)
      return (m);
    return(([]));
}

string ldapoutput_tag(string tag_name, mapping args, string contents,
		     object request_id, object f,
		     mapping defines, object fd)
{
  if (args->filter) {

    if (args->parse) {
      args->filter = parse_rxml(args->filter, request_id, f, defines);
    }

    string host = query("hostname");
    string basedn = query("basedn");
    string user = query("user");
    string password = query("password");
    object con = 0, en;
    array(mapping(string:mixed)) result;
    function dir_connect = request_id->conf->dir_connect;
    mixed error;
    string atype;
    mapping m = (["attr":"","index":0,"step":1,"max":0,"body":""]);

    if (args->host) {
      host = args->host;
      user = "";
      password = "";
    }
    if (args->basedn) {
      basedn = args->basedn;
      user = "";
      password = "";
      dir_connect = 0;
    }
    if (args->user) {
      user = args->user;
      password = "";
      dir_connect = 0;
    }
    if (args->password) {
      password = args->password;
      dir_connect = 0;
    }
    if (dir_connect) {
      error = catch(con = dir_connect(host));
    } else {
      host = (lower_case(host) == "localhost")?"":host;
      error = catch(con = Protocols.LDAP.client(host));
      error |= catch(con->bind(user,password));
    }
    if (error || !objectp(con)) {
      contents = "<h1>Couldn't connect to LDAP-server</h1><br>\n" +
	((master()->describe_backtrace(error)/"\n")*"<br>\n");
      return(contents);
    }
    status_connect_server = "host: " + host +
			    (sizeof(user)?(", user: "+user):"") +
			    (sizeof(password)?(", password: "+password):"");
    status_connect_last = ctime(time());
    status_connect_nums++;

    con->set_basedn(basedn);
    if (args->scope) {
      int scopenum;
      switch (args->scope) {
        case "onelevel": scopenum = 1; break;
        case "subtree": scopenum = 2; break;
        default: scopenum = 0;
      }
      con->set_scope(scopenum);
    }

    if (error = catch(en = con->search(args->filter))) {
      ldap_last_error = "LDAP search \"" + args->filter + "\" failed: " + con->error_string();
      contents = "<h1>" + ldap_last_error + "</h1>\n" +
	((master()->describe_backtrace(error)/"\n")*"<br>\n");
    }
    con->unbind();

    if (objectp(en) && en->num_entries()) {
      string nullvalue="";
      array parsed_content_array = ({});
      array(string) content_array; // = contents/"#";
      mapping(string:array(string)) res;
      array(string) res_array = ({});
      int ix, cnt;
      string contents2;
      array pos;

      DEBUGLOG(sprintf("entries: %d",en->num_entries()));
      DEBUGLOG(sprintf("%O",en->fetch()));
      if (args->nullvalue) {
	nullvalue = (string)args->nullvalue;
      }

      // Preprocess subcontainer
      contents2 = contents;
      while(arrayp(pos = find_subc(contents2))) {
	if(pos[0])
	  parsed_content_array += ({contents2[..(pos[0]-1)]});
	parsed_content_array += ({parse_subc(contents2[pos[0]..pos[1]], request_id)});
	contents2 = contents2[(pos[1]+1)..];
	if(!sizeof(contents2))
	  break;
      } // while
      if (sizeof(contents2))
	  parsed_content_array += ({contents2}); // trailing text

      //DEBUGLOG(sprintf("DEB: preparsed: $%O$",parsed_content_array));

      // Walking through all entries
      for( ; ; ) {
        res=en->fetch();
	int i;

	contents2 = "";
	foreach(parsed_content_array, mixed elem) {
	  if (stringp(elem))
	    contents2 += elem;
	  else
	    if (res[elem->attr] || !zero_type(res[elem->attr])) {
	      ix = sizeof(res[elem->attr]);
	      cnt = 0;
	      for (i=(elem->index)-1; i < ix; i+=elem->step) {
		if (elem->max)
		  if (cnt++ >= elem->max)
		    break;
		contents2 += replace (elem->body, "#"+elem->attr+"#",
				     "#"+elem->attr+":"+(i+1)+"#");
	      }
	    } else
#if 1
		if(((elem->attr == "labeledurianchor")
		  || (elem->attr == "labeleduriuri")
		  || (elem->attr == "labeledurilabel")) && res->labeleduri) {
		  // optimization remark: the body is closer bellow -^
		  ix = sizeof(res->labeleduri);
		  cnt = 0;
		  for (i=(elem->index)-1; i < ix; i+=elem->step) {
		    if (elem->max)
		      if (cnt++ >= elem->max)
			break;
		      contents2 += replace (elem->body, "#"+elem->attr+"#",
				     "#"+elem->attr+":"+(i+1)+"#");
		  }
	        } else
#endif
                  if (zero_type(args["norem"]))
	            contents2 += "<!-- Missing attribute \"" + elem->attr +
		 		"\" ! -->"; // + elem->body;
	}
	//DEBUGLOG(sprintf("DEB: preparsed_2: $%s$",contents2));
	content_array = contents2 / "#";

	for (i=0; i < sizeof(content_array); i++) {
	  int ord = 0;
	  if (i & 1) {
	    atype = lower_case((content_array[i] / ":")[0]);
	    //DEBUGLOG(sprintf("DEB2: atype: %s",atype));
	    if (sizeof(content_array[i] / ":") == 2)
	      ord = ((int)(content_array[i] / ":")[1]) - 1;
	    if((atype == "labeledurianchor") || (atype == "labeleduriuri")
		  || (atype == "labeledurilabel"))
	      atype = "labeleduri";
	    //if (!zero_type(res[atype]) || res[atype]) {
	    if (!zero_type(res[atype])) {
	      string value = "";
	      if (sizeof(res[atype]) > ord) {
	        value = (string)res[atype][ord];
		// special attribute processing
		atype = lower_case((content_array[i] / ":")[0]);
		if((atype == "labeledurianchor") || (atype == "labeleduriuri")
		  || (atype == "labeledurilabel")) {
		  int ix = search(value, " "); // cut leadings ' ' ?
		  string uriuri = (value / " ")[0];
		  string urilabel;

		  if(ix > 1) // URI Label exists!
		    urilabel = value[(ix+1)..]; // after 1.space to end
		  else
		    urilabel = uriuri;
		  switch (atype) {
		    case "labeleduriuri":
			value = uriuri;
			break;
		    case "labeledurilabel":
			value = urilabel;
			break;
		    case "labeledurianchor":
			value = "<a href=\"" + uriuri + "\">" + urilabel + "</a>";
			break;
		  } //case
		}
	      }
	      res_array += ({ ((value=="")?nullvalue:value) }) + ({});
	    } else if (atype == "dn") {
	      /* Get DN */
		;
	    } else if (content_array[i] == "") {
	      /* Dual #'s to get one */
	      res_array += ({ "#" }) + ({});
	    } else {
                if (zero_type(args["norem"]))
	          res_array += ({"<!-- Missing attribute " + 
			    (content_array[i] / ":")[0] + " -->"}) + ({});
	    }
	  } else {
	    res_array += ({ content_array[i] });
	  }
	} // for
        if(!en->next()) 
	  break;
      } // for ( ; ; )
      contents = (res_array * "") + "<true>";
    } else {
      contents = "<false>";
    } // if (en && sizeof

#if 0
    if (result && sizeof(result)) {
      contents = do_output_tag( args, result, contents, request_id )
        + "<true>";
    } else {
      contents = "<false>";
    }
#endif

  } else
    contents = "<!-- No filter specified! --><false>";

  //DEBUGLOG(sprintf("DEB3: contents: %s",contents));
  DEBUGLOG((contents[-6..] == "<true>") ? "<true>" : "<false>");
  return(contents);
}


string ldapelse_tag(string tag_name, mapping args, string contents,
		   object request_id, mapping defines)
{
  string contents2 = replace(contents, "#ldaperror#", "I don't know ;-(");
  return(make_container("else", args, contents2));
}

string dumpid_tag(string tag_name, mapping args,
		  object request_id, mapping defines)
{
  return(sprintf("<pre>ID:%O\n</pre>\n",
		 mkmapping(indices(request_id), values(request_id))));
}

/*
 * Hook in the tags
 */

mapping query_tag_callers()
{
  return( ([ "ldap":ldap_tag, "dumpid":dumpid_tag ]) );
}

mapping query_container_callers()
{
  return( ([ "ldapoutput":ldapoutput_tag, "ldapelse":ldapelse_tag ]) );
}

/*
 * Setting the defaults
 */

void create()
{
  defvar("hostname", "localhost", "Defaults:  LDAP server location", 
	 TYPE_STRING, "Specifies the default LDAP directory server hostname.\n");
  defvar("basedn", "", "Defaults: LDAP search base DN",
	 TYPE_STRING,
	 "Specifies the distinguished name to use as a base for queries.\n");
  defvar("user", "", "Defaults:  username",
	 TYPE_STRING,
	 "Specifies the default username to use for access.\n"
	 "<br><p><b>DEPRECATED!</b>");
  defvar("password", "", "Defaults:  password",
	 TYPE_STRING,
	 "Specifies the default password to use for access.\n"
	 "<br><p><b>DEPRECATED!</b>");
}

/*
 * More interface functions
 */

object conf;

void start(int level, object _conf)
{
  if (_conf) {
    conf = _conf;
  }
}

void stop()
{
}

string status()
{
  if (status_connect_nums)
    return(sprintf("<p>Last connected to %s [ %s]<br>Number of connections: %d<br><p>Last error: %s<br>\n",
		   status_connect_server, status_connect_last,
		   status_connect_nums, sizeof(ldap_last_error) ? ldap_last_error : "[none]"));
  return("<p><font color=red>Zero connections.</font><br>\n");
}

