// This is a roxen module. Copyright © 2001 - 2009, Roxen IS.
//

#define _error id->misc->defines[" _error"]
//#define _extra_heads id->misc->defines[" _extra_heads"]

#include <module.h>
inherit "module";

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Tags: Session tag module";
constant module_doc  = #"\
This module provides the session tag which provides a variable scope
where user session data can be stored.";

protected string shared_db;
protected int db_ok;

protected void create (Configuration conf)
{
  defvar ("enable-shared-db", 0, "Enabled shared storage",
	  TYPE_FLAG, #"\
<p>Whether to store sessions in a database that can be shared between
servers.</p>

<p>Normally sessions are cached in RAM and are shifted out to disk
only when they have been inactive for some time. Enabling shared
storage disables all RAM caching, to make the sessions work across
servers in e.g. a round-robin load balancer. The drawback is more
expensive session handling.</p>");

  defvar ("shared-db", Variable.DatabaseChoice (
	    "shared", 0, "Shared database", #"\
The database to store sessions in. A table called \"session_cache\"
will be created in it."))
    ->set_invisibility_check_callback (lambda () {
					 return !query ("enable-shared-db");
				       });
  defvar ("use-prestate", 0,
	  "Use prestate as fallback",
	  TYPE_FLAG,
	  #"If set to Yes, prestates will be used as fallback for users without
cookie support. One or more redirects will then be issued by
&lt;force-session-id&gt; to retain the session either in a cookie or
in the prestate. See the documentation for &lt;force-session-id&gt;
for details. Note that the prestates affect SEO due to the redirects
that will serve the same pages through different url's. This setting
is therefore deprecated, but exists for backward compatibility."
	  );
}

void start() {
  query_tag_set()->prepare_context=set_entities;
  shared_db = query ("enable-shared-db") && query ("shared-db");
  if (shared_db)
    db_ok = cache.setup_session_table (shared_db);
  else
    db_ok = 1;
}

string status()
{
  if (!db_ok)
    return "<font color='red'>"
      "Not working - cannot connect to shared database."
      "</font>\n";
}


// --- &client.session; ----------------------------------------

class EntityClientSession {
  inherit RXML.Value;
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable = 0;
    if( query("use-prestate") ) {
      multiset prestates = filter(c->id->prestate,
				  lambda(string in) {
				  return has_prefix(in, "RoxenUserID="); } );

      // If there is both a cookie and a prestate, then we're in the process of
      // deciding session variable vehicle, and should thus return nothing.
      if(c->id->cookies->RoxenUserID && sizeof(prestates))
	return RXML.nil;
      // If there is a UserID cookie, use that as our session identifier.
      if(c->id->cookies->RoxenUserID)
	return ENCODE_RXML_TEXT(c->id->cookies->RoxenUserID, type);

      // If there is a RoxenUserID-prefixed prestate, use the first such
      // prestate as session identifier.
      if(sizeof(prestates)) {
	string session = indices(prestates)[0][12..];
	if(sizeof(session))
	  return ENCODE_RXML_TEXT(session, type);
      }
    } else {
      if ( c->id->cookies->RoxenUserID ) {
	return ENCODE_RXML_TEXT(c->id->cookies->RoxenUserID, type);
      }
    }
    // Otherwise return nothing.
    return RXML.nil;
  }
}

mapping session_entity = ([ "session":EntityClientSession() ]);

void set_entities(RXML.Context c) {
  c->extend_scope("client", session_entity + ([]));
}


// --- RXML Tags -----------------------------------------------

class TagSession {
  inherit RXML.Tag;
  constant name = "session";
  mapping(string:RXML.Type) req_arg_types = ([ "id" : RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit RXML.Frame;
    mapping vars;
    string scope_name;

    array do_enter(RequestID id) {
      if (!db_ok) run_error ("Shared db not set up.\n");
      NOCACHE();
      vars = cache.get_session_data(args->id, shared_db) || ([]);
      scope_name = args->scope || "session";
    }

    array do_return(RequestID id) {
      result = content;
      if(!sizeof(vars)) return 0;
      int timeout;
      if (args->life) timeout = (int) args->life + time (1);
      else if (shared_db) timeout = 900 + time (1);
      cache.set_session_data(vars, args->id, timeout,
			     shared_db || !!args["force-db"] );
    }
  }
}

class TagClearSession {
  inherit RXML.Tag;
  constant name = "clear-session";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  mapping(string:RXML.Type) req_arg_types = ([ "id" : RXML.t_text(RXML.PEnt) ]);

  class Frame {
    inherit RXML.Frame;

    array do_enter(RequestID id) {
      if (!db_ok) run_error ("Shared db not set up.\n");
      NOCACHE();
      cache.clear_session(args->id, shared_db);
    }
  }
}

class TagForceSessionID {
  inherit RXML.Tag;
  constant name = "force-session-id";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_enter(RequestID id) {
      if( query("use-prestate") ) {
	int prestate = sizeof(filter(id->prestate,
				     lambda(string in) {
				       return has_prefix(in, "RoxenUserID");
				     } ));

	string path_info = id->misc->path_info || "";

	// If there is no ID cooke nor prestate, redirect to the same page
	// but with a session id prestate set.
	if(!id->cookies->RoxenUserID && !prestate) {
	  multiset orig_prestate = id->prestate;
	  string session_id = roxen.create_unique_id();
	  id->prestate += (< "RoxenUserID=" + session_id >);

	  mapping r = Roxen.http_redirect(id->not_query + path_info, id, 0,
					  id->real_variables);
	  if (r->error)
	    RXML_CONTEXT->set_misc (" _error", r->error);
	  if (r->extra_heads)
	    RXML_CONTEXT->extend_scope ("header", r->extra_heads);

	  // Don't trust that the user cookie setting is turned on. The effect
	  // might be that the RoxenUserID cookie is set twice, but that is
	  // not a problem for us.
	  id->add_response_header( "Set-Cookie", Roxen.http_roxen_id_cookie(session_id) );
	  id->prestate = orig_prestate;
	  return 0;
	}

	// If there is both an ID cookie and a session prestate, then the
	// user do accept cookies, and there is no need for the session
	// prestate. Redirect back to the page, but without the session
	// prestate. 
	if(id->cookies->RoxenUserID && prestate) {
	  multiset orig_prestate = id->prestate;
	  id->prestate = filter(id->prestate,
				lambda(string in) {
				  return !has_prefix(in, "RoxenUserID");
				} );
	  mapping r = Roxen.http_redirect(id->not_query + path_info, id, 0,
					  id->real_variables);
	  id->prestate = orig_prestate;
	  if (r->error)
	    RXML_CONTEXT->set_misc (" _error", r->error);
	  if (r->extra_heads)
	    RXML_CONTEXT->extend_scope ("header", r->extra_heads);
	  return 0;
	}
      } else {
	if ( !id->cookies->RoxenUserID ) {
	  string session_id = roxen->create_unique_id();
	  id->add_response_header( "Set-Cookie", Roxen.http_roxen_id_cookie( session_id ) );
	  id->cookies->RoxenUserID = session_id;
	  return 0;
	}
      }
    }
  }
}


// --- Documentation  ------------------------------------------

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc = ([
  "session":#"<desc type='cont'><p>Creates a session bound scope. The session is
identified by a session key, given as an argument to the session tag.
The session key could be e.g. a value generated by
<ent>roxen.unique-id</ent> which is then transported by form
variables. An alternative which often is more convenient is to use the
variable client.session (provided by this module) together with the
<tag>force-session-id</tag> tag and the feature to set unique browser
id cookies in the http protocol module (located under the server ports
tab).</p>
<p>The following fragment sets up a new session with a variable in it</p>
<ex-box>
    <!-- Force a session ID if one doesn't exist -->
    <force-session-id />
    <session id='client.session' scope='mysession'>
      <!--
      Our current scope is now the 'mysession' scope. Any variables
      created in this scope will be accessible wherever the same
      session is set up at a later stage.
      -->

      <!-- Create a variable in the scope -->
      <set variable='_.message'>Hello World!</set>

      Variable 'message' in the scope 'mysession' is now created in session id &client.session;:<br/>
      &_.message;

    </session>
</ex-box>
<p>And the following fragment uses the same variable in another page</p>
<ex-box>
  <!-- Make sure things are not over cached -->
  <nocache>
    <!-- Force a session ID if one doesn't exist -->
    <force-session-id />

    <session id='client.session' scope='mysession'>
      <!--
	  Inside this container, we now have access to all the
	  variables from the mysession scope again
      -->

      Variable 'message' in the scope 'mysession' in session id &client.session;:<br/>
      &mysession.message;
    </session>
  </nocache>
</ex-box>
</desc>

<attr name='id' value='string' required='1'><p>The key that identifies
the session. Could e.g. be a name, an IP adress, a cookie or the value
of the special variable client.session provided by this module (see
above).</p></attr>

<attr name='life' value='number' default='900'><p>Determines how many
seconds the session is guaranteed to persist on the server side.</p>

<p>If the module isn't configured to use a shared database, then
values over 900 means that the session variables will be moved to a
disk based database when they have not been used within 900
seconds.</p></attr>

<attr name='force-db'><p>If used, the session variables will be
immediatly written to the database. Otherwise session variables are
only moved to the database when they have not been used for a while
(given that they still have \"time to live\", as determined by the
life attribute).</p>

<p>Setting this flag will increase the integrity of the session, since
the variables will survive a server reboot, but it will also decrease
performance somewhat.</p>

<p>If the module is configured to use a shared database then sessions
are always written immediately, regardless of this flag.</p></attr>

<attr name='scope' value='name' default='session'><p>The name of the
scope that is created inside the session tag.</p></attr>
",

  // ------------------------------------------------------------


  "clear-session":#"<desc tag='tag'><p>Clear a session from all its content.</p></desc>

<attr name='id' value='string' required='required'>
<p>The key that identifies the session.</p></attr>",

  // ------------------------------------------------------------

  "&client.session;":#"<desc type='entity'> <p><short>Contains a session key for the user or
nothing.</short> The session key is taken from the RoxenUserID cookie.</p>
<p>RoxenUserID cookie is set through the \"Set unique browser id cookies\" option in the http protocol
module (located under the server ports tab) or by using the <tag>force-session-id</tag> tag.</p>
<p>If configured to use prestate (which is deprecated) its value can be retrieved from:</p>
<list type='ul'>
  <item><p>Prestate that begins with \"RoxenUserID=\" if there is no RoxenUserID
           cookie.</p></item>
  <item><p>If both the cookie and such a prestate exists the
     client.session variable will be empty. This happens when
     <tag>force-session-id</tag> would generate a redirect, and
     can be used to skip the rest of the page (see the example
     for that tag).</p></item>
</list>
<p>Note that the Session tag module must be loaded for this entity to exist.</p></desc>",

  // ------------------------------------------------------------

  "force-session-id":#"<desc tag='tag'><p><short>Forces a session id to be set in the variable <ent>client.session</ent>.</short></p>
<p>Depending on the settings of this module, there are two ways the session cookie is set:</p>
<list type='ul'>
  <item>
    <p><b>Default</b><p>If no RoxenUserID cookie exists, headers to set the cookie
       is generated. The client.session variable is set and usable immediately during
       the request from then on. If the client do not support cookies or has cookies turned
       off, each request the force-session-id tag is used, the session key will have a
       different value.</p></item>
    <item><p><b>Deprecated</b></p>
          <p>If no RoxenUserID cookie exist, a redirect is made to the same page with
a prestate containing a newly generated session key together with a Set-Cookie
header with the same key as value. The prestate is used if the cookie cannot be set. If both the RoxenUserID cookie and the session prestate is set, it redirects back to the same page without any prestate. I.e. two redirects for client that supports cookies, and one redirect for clients that don't. Also note that the tag itself does not stop the RXML parser during these requests the redirects are made. This is why it is deprecated; the fallback only works as long as the prestate exists, secondly the search engines will have two urls containing the same content due to the redirects.</p></item>
  </list>

<p>The RoxenUserID cookie can  be set automatically by the HTTP protocol module. Look
at the option to enable unique browser id cookies under the server ports tab.</p>

<ex-box><force-session-id/>
  <!-- RXML code that uses &client.session;, e.g. as follows: -->
<session id='&client.session;'>
  ...
</session>
</ex-box>

<p>Deprecated (when module is configured to use prestate):</p>
<ex-box><force-session-id/>
<if variable='client.session'>
  <!-- client.session has a value when the RoxenUserID cookie exists or if cookie don't
       exist but the prestate that starts with \"RoxenUserID=\" does. -->
  <!-- RXML code that uses &client.session;, e.g. as follows: -->
  <session id='&client.session;'>
    ...
  </session>
</if>
</ex-box>

<p>Example of how to do a separate test to verify if a client supports cookies,
   server side:</p>
<ex-box><nocache>
  <if variable=\"form.test-cookie = 1\">
    <if variable=\"cookie.testing_cookie = 1\">
      Cookies work
    </if>
    <else>
     Your browser do not support cookies.
    </else>
  </if>
  <else>
    <set-cookie name=\"testing_cookie\" value=\"1\"/>
    <redirect to=\"&page.path;?test-cookie=1\"/>
  </else>
</nocache>
</ex-box>
</desc>",

]);
#endif
