// This is a roxen module. Copyright © 2000, Roxen IS.
//

#include <module.h>
inherit "module";

constant cvs_version = "$Id: session_scope.pike,v 1.1 2000/05/16 16:32:42 nilsson Exp $";
constant thread_safe = 1;
constant module_type = MODULE_PARSER;
constant module_name = "Session scope module";
constant module_doc  = "This module provides a session persistent variable scope.";
constant module_unique = 1;

void create() {
  defvar("cookie", "RoxenUserID", "Session cookie", TYPE_STRING, 
	 "What cookie should be used for session identification. If the cookie 'RoxenUserID' is used, "
         "and \"Set unique user id cookies\" is selected for the port, cookie management will be "
	 "automatic (e.g. it will be set automatically if not preset).");
}

void start(int num, Configuration conf) {
  query_tag_set()->prepare_context=set_entities;
}

void set_entities(RXML.Context c) {
  c->extend_scope("session", session_scope);
}

RXML.Scope session_scope = ScopeSession();

string session_id(RequestID id) {
  string session=id->cookies[query("cookie")];
  if(!session)
    session=id->remoteaddr+id->request_headers["user-agent"];
  return session;
}

class ScopeSession {
  inherit RXML.Scope;

  mapping find_session_mapping(RequestID id) {
    return get_from_cache(session_id(id));
  }

  mixed `[] (string var, void|RXML.Context c, void|string scope) {
    if(!c) return ([])[0];
    if(var=="id") return session_id(c->id);
    return find_session_mapping(c->id)[var];
  }

  mixed `[]= (string var, mixed val, void|RXML.Context c, void|string scope_name) {
    if(!c) return ([])[0];
    return find_session_mapping(c->id)[var]=val;
  }

  array(string) _indices(void|RXML.Context c) {
    if(!c) return ({});
    return ({"id"})+indices(find_session_mapping(c->id));
  }

  void m_delete (string var, void|RXML.Context c, void|string scope_name) {
    if(!c) return;
    predef::m_delete(find_session_mapping(c->id), var);
  }
}

class TagResetSession {
  inherit RXML.Tag;
  constant name="reset-session";
  constant flags=RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(args->session="all") {
	the_cache=({ ([]) });
	return 0;
      }

      string session;
      if(args->session)
	session=args->session;
      else
	session=session_id(id);

      remove_from_cache(session);
      return 0;
    }
  }
}

// ---------- Multiple bucket cache --------

array(mapping) the_cache=({ ([]) });
int shifted;

mapping get_from_cache(string key) {
  if(shifted<time(1)) {
    shifted=time(1)+15*60; // Next gc in 15 minutes.
    the_cache=({ ([]) })+the_cache[..2];
  }

  if( the_cache[0][key] )
    return the_cache[0][key];

  foreach( the_cache[1..], mapping bucket )
    if(bucket[key])
      return the_cache[0][key]=bucket[key];

  mapping scope=([]);
  the_cache[0][key]=scope;
  return scope;
}

void remove_from_cache(string key) {
  foreach(the_cache, mapping bucket)
    if(bucket[key]) m_delete(bucket, key);
}
