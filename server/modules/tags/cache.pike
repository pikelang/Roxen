// This is a ChiliMoon module which provides cache tags.
//
// This module is open source software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation; either version 2, or (at your option) any
// later version.
//

#define _ok id->misc->defines[" _ok"]

constant cvs_version =
 "$Id: cache.pike,v 1.1 2004/05/31 02:43:31 _cvs_stephen Exp $";
constant thread_safe = 1;
constant module_unique = 1;

#include <module.h>
#include <request_trace.h>

inherit "module";


// ---------------- Module registration stuff ----------------

constant module_type = MODULE_TAG;
constant module_name = "Tags: Cache";
constant module_doc  =
 "This module provides cache tags.<br />"
 "<p>This module is open source software; you can redistribute it and/or "
 "modify it under the terms of the GNU General Public License as published "
 "by the Free Software Foundation; either version 2, or (at your option) any "
 "later version.</p>";

void create() {
  set_module_creator("Stephen R. van den Berg <srb@cuci.nl>");
}

string status() {
  return "";
}

class TagExpireTime {
  inherit RXML.Tag;
  constant name = "expire-time";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      int t,t2;
      t = t2 = (int)args["unix-time"]||time(1);
      if(!args->now) {
	t = Roxen.time_dequantifier(args, t);
	CACHE( max(t-t2,0) );
      }
      if(t==t2) {
	NOCACHE();
	id->add_response_header("Pragma", "no-cache");
	id->add_response_header("Cache-Control", "no-cache");
      }

      // It's meaningless to have several Expires headers, so just
      // override.
      id->set_response_header("Expires", Roxen.http_date(t));
      return 0;
    }
  }
}

class TagCache {
  inherit RXML.Tag;
  constant name = "cache";
  constant flags = (RXML.FLAG_GET_RAW_CONTENT |
		    RXML.FLAG_GET_EVALED_CONTENT |
		    RXML.FLAG_DONT_CACHE_RESULT |
		    RXML.FLAG_CUSTOM_TRACE);
  constant cache_tag_location = "tag_cache";
  constant disable_protocol_cache = 1;

  static class TimeOutEntry (
    TimeOutEntry next,
    // timeout_cache is a wrapper array to get a weak ref to the
    // timeout_cache mapping for the frame. This way the mapping will
    // be garbed when the frame disappears, in addition to the
    // timeout.
    array(mapping(string:array(int|RXML.PCode))) timeout_cache)
    {}

  static TimeOutEntry timeout_list;

  static void do_timeouts()
  {
    int now = time (1);
    for (TimeOutEntry t = timeout_list, prev; t; t = t->next) {
      mapping(string:array(int|RXML.PCode)) cachemap = t->timeout_cache[0];
      if (cachemap) {
	foreach (indices (cachemap), string key)
	  if (cachemap[key][0] < now) m_delete (cachemap, key);
	prev = t;
      }
      else
	if (prev) prev->next = t->next;
	else timeout_list = t->next;
    }
    roxen.background_run (roxen.query("mem_cache_gc"), do_timeouts);
  }

  static void add_timeout_cache (mapping(string:array(int|RXML.PCode)) timeout_cache)
  {
    if (!timeout_list)
      roxen.background_run (roxen.query("mem_cache_gc"), do_timeouts);
    else
      for (TimeOutEntry t = timeout_list; t; t = t->next)
	if (t->timeout_cache[0] == timeout_cache) return;
    timeout_list =
      TimeOutEntry (timeout_list,
		    set_weak_flag (({timeout_cache}), 1));
  }

  class Frame {
    inherit RXML.Frame;

    int do_iterate;
    mapping(string|int:mixed) keymap, overridden_keymap;
    string key;
    RXML.PCode evaled_content;
    int timeout, persistent_cache;

    // The following are retained for frame reuse.
    string content_hash;
    array(string|int) subvariables;
    mapping(string:RXML.PCode|array(int|RXML.PCode)) alternatives;

    static void add_subvariables_to_keymap()
    {
      RXML.Context ctx = RXML_CONTEXT;
      foreach (subvariables, string var) {
	array splitted = ctx->parse_user_var (var, 1);
	if (intp (splitted[0])) { // Depend on the whole scope.
	  mapping|RXML.Scope scope = ctx->get_scope (var);
	  if (mappingp (scope))
	    keymap[var] = scope + ([]);
	  else if (var == "form")
	    // Special case to optimize this scope.
	    keymap->form = ctx->id->real_variables + ([]);
	  else {
	    array indices = scope->_indices (ctx, var);
	    keymap[var] = mkmapping (indices, rows (scope, indices));
	  }
	}
	else
	  keymap[var] = ctx->get_var (splitted[1..], splitted[0]);
      }
    }

    static void make_key_from_keymap(RequestID id)
    {
      // Caching is not allowed if there are keys except '1' and
      // page.path, i.e. when different cache entries might be chosen
      // for the same page.
      array(string|int) keys = indices(keymap) - ({1}) - ({"page.path"});
      if (sizeof(keys)) {
	if (!args["enable-client-cache"])
	  NOCACHE();
	else if(!args["enable-protocol-cache"])
	  NO_PROTO_CACHE();
      }

      key = encode_value_canonic (keymap);
      if (!args["disable-key-hash"])
	key = Crypto.SHA1.hash(key);
    }

    array do_enter (RequestID id)
    {
      if( args->nocache || args["not-post-method"] && id->method == "POST" ) {
	do_iterate = 1;
	key = 0;
	TAG_TRACE_ENTER ("no cache due to %s",
			 args->nocache ? "nocache argument" : "POST method");
	id->cache_status->cachetag = 0;
	id->misc->cache_tag_miss = 1;
	return 0;
      }

      RXML.Context ctx = RXML_CONTEXT;

      overridden_keymap = 0;
      if (!args->propagate ||
	  (!(keymap = ctx->misc->cache_key) &&
	   (m_delete (args, "propagate"), 1))) {
	overridden_keymap = ctx->misc->cache_key;
	keymap = ctx->misc->cache_key = ([]);
      }

      if (args->variable) {
	if (args->variable != "")
	  foreach (args->variable / ",", string var) {
	    var = String.trim_all_whites (var);
	    array splitted = ctx->parse_user_var (var, 1);
	    if (intp (splitted[0])) { // Depend on the whole scope.
	      mapping|RXML.Scope scope = ctx->get_scope (var);
	      if (mappingp (scope))
		keymap[var] = scope + ([]);
	      else if (var == "form")
		// Special case to optimize this scope.
		keymap->form = id->real_variables + ([]);
	      else if (scope) {
		array indices = scope->_indices (ctx, var);
		keymap[var] = mkmapping (indices, rows (scope, indices));
	      }
	      else
		parse_error ("Unknown scope %O.\n", var);
	    }
	    else
	      keymap[var] = ctx->get_var (splitted[1..], splitted[0]);
	  }
      }

      if (args->profile) {
	if (mapping avail_profiles = id->misc->rxml_cache_cur_profile)
	  foreach (args->profile / ",", string profile) {
	    profile = String.trim_all_whites (profile);
	    mixed profile_val = avail_profiles[profile];
	    if (zero_type (profile_val))
	      parse_error ("Unknown cache profile %O.\n", profile);
	    keymap[" " + profile] = profile_val;
	  }
	else
      	  parse_error ("There are no cache profiles.\n");
      }

      if (args->propagate) {
	if (args->key)
	  parse_error ("Argument \"key\" cannot be used together with \"propagate\".");
	// Updated the key, so we're done. The surrounding cache tag
	// should do the caching.
	do_iterate = 1;
	TAG_TRACE_ENTER ("propagating key, is now %s",
			 RXML.utils.format_short (keymap, 200));
	key = keymap = 0;
	flags &= ~RXML.FLAG_DONT_CACHE_RESULT;
	return 0;
      }

      if(args->key) keymap[0] += ({args->key});

      if (subvariables) add_subvariables_to_keymap();

      if (args->shared) {
	if(args->nohash)
	  // Always use the configuration in the key; noone really
	  // wants cache tainting between servers.
	  keymap[1] = id->conf->name;
	else {
	  if (!content_hash) {
	    // Include the content type in the hash since we cache the
	    // p-code which has static type inference.
	    if (!content) content = "";
	    if (String.width (content) != 8) content = encode_value_canonic (content);
	    content_hash = Crypto.SHA1.hash(content+content_type->name);
	  }
	  keymap[1] = ({id->conf->name, content_hash});
	}
      }

      make_key_from_keymap(id);

      timeout = Roxen.time_dequantifier (args);

      // Now we have the cache key.

      object(RXML.PCode)|array(int|RXML.PCode) entry = args->shared ?
	cache_lookup (cache_tag_location, key) :
	alternatives && alternatives[key];

      int removed = 0; // 0: not removed, 1: stale, 2: timeout, 3: pragma no-cache

      if (entry) {
      check_entry_valid: {
	  if (arrayp (entry)) {
	    if (entry[0] < time (1)) {
	      removed = 2;
	      break check_entry_valid;
	    }
	    else evaled_content = entry[1];
	  }
	  else evaled_content = entry;
	  if (evaled_content->is_stale())
	    removed = 1;
	  else if (id->pragma["no-cache"] && args["flush-on-no-cache"])
	    removed = 3;
	}

	if (removed) {
	  if (args->shared)
	    cache_remove (cache_tag_location, key);
	  else
	    if (alternatives) m_delete (alternatives, key);
	}

	else {
	  do_iterate = -1;
	  TAG_TRACE_ENTER ("cache hit%s for key %s",
			   args->shared ?
			   (timeout ? " (shared timeout cache)" : " (shared cache)") :
			   (timeout ? " (timeout cache)" : ""),
			   RXML.utils.format_short (keymap, 200));
	  key = keymap = 0;
	  return ({evaled_content});
	}
      }

      keymap += ([]);
      do_iterate = 1;
      TAG_TRACE_ENTER ("cache miss%s, %s",
		       args->shared ?
		       (timeout ? " (shared timeout cache)" : " (shared cache)") :
		       (timeout ? " (timeout cache)" : ""),
		       removed == 1 ? "entry p-code is stale" :
		       removed == 2 ? "entry had timed out" :
		       removed == 3 ? "a pragma no-cache request removed the entry" :
		       "no entry");
      id->cache_status->cachetag = 0;
      id->misc->cache_tag_miss = 1;
      return 0;
    }

    array do_return (RequestID id)
    {
      if (key) {
	mapping(string|int:mixed) subkeymap = RXML_CONTEXT->misc->cache_key;
	if (sizeof (subkeymap) > sizeof (keymap)) {
	  // The test above assumes that no subtag removes entries in
	  // RXML_CONTEXT->misc->cache_key.
	  subvariables = filter (indices (subkeymap - keymap), stringp);
	  // subvariables is part of the persistent state, but we'll
	  // come to state_update later anyway if it should be called.
	  add_subvariables_to_keymap();
	  make_key_from_keymap(id);
	}

	if (args->shared) {
	  cache_set(cache_tag_location, key, evaled_content, timeout);
	  TAG_TRACE_LEAVE ("added shared%s cache entry with key %s",
			   timeout ? " timeout" : "",
			   RXML.utils.format_short (keymap, 200));
	}
	else
	  if (timeout) {
	    if (args["persistent-cache"] == "yes") {
	      persistent_cache = 1;
	      RXML_CONTEXT->state_update();
	    }
	    if (!alternatives) {
	      alternatives = ([]);
	      if (!persistent_cache) add_timeout_cache (alternatives);
	    }
	    alternatives[key] = ({time() + timeout, evaled_content});
	    TAG_TRACE_LEAVE ("added%s timeout cache entry with key %s",
			     persistent_cache ? " (possibly persistent)" : "",
			     RXML.utils.format_short (keymap, 200));
	  }
	  else {
	    if (!alternatives) alternatives = ([]);
	    alternatives[key] = evaled_content;
	    if (args["persistent-cache"] != "no") {
	      persistent_cache = 1;
	      RXML_CONTEXT->state_update();
	    }
	    TAG_TRACE_LEAVE ("added%s cache entry with key %s",
			     persistent_cache ? " (possibly persistent)" : "",
			     RXML.utils.format_short (keymap, 200));
	  }
      }
      else
	TAG_TRACE_LEAVE ("");

      if (overridden_keymap) {
	RXML_CONTEXT->misc->cache_key = overridden_keymap;
	overridden_keymap = 0;
      }

      result += content;
      return 0;
    }

    array save()
    {
      if (persistent_cache && timeout && alternatives) {
	int now = time (1);
	foreach (alternatives; string key; array(int|RXML.PCode) entry)
	  if (entry[0] < now) m_delete (alternatives, key);
      }
      return ({content_hash, subvariables, persistent_cache,
	       persistent_cache && alternatives});
    }

    void restore (array saved)
    {
      [content_hash, subvariables, persistent_cache, alternatives] = saved;
    }
  }
}

class TagNocache
{
  inherit RXML.Tag;
  constant name = "nocache";
  constant flags = RXML.FLAG_DONT_CACHE_RESULT;
  class Frame
  {
    inherit RXML.Frame;
  }
}

class TagSetMaxCache {
  inherit RXML.Tag;
  constant name = "set-max-cache";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
  class Frame {
    inherit RXML.Frame;
    array do_return(RequestID id) {
      id->misc->cacheable = Roxen.time_dequantifier(args);
    }
  }
}

// --------------------- Documentation -----------------------

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([

//----------------------------------------------------------------------

"expire-time":#"<desc type='tag'><p><short hide='hide'>
 Sets client cache expire time for the document.</short>
 Sets client cache expire time for the document by sending the HTTP header
 \"Expires\". Note that on most systems the time can only be set to dates
 before 2038 due to operating software limitations.
</p></desc>

<attr name='now'>
 <p>Notify the client that the document expires now. The headers
 \"Pragma: no-cache\" and \"Cache-Control: no-cache\"
 will also be sent, besides the \"Expires\" header.</p>
</attr>

<attr name='unix-time' value='number'>
 <p>The exact time of expiration, expressed as a posix time integer.</p>
</attr>

<attr name='years' value='number'>
 <p>Add this number of years to the result.</p>
</attr>

<attr name='months' value='number'>
  <p>Add this number of months to the result.</p>
</attr>

<attr name='weeks' value='number'>
  <p>Add this number of weeks to the result.</p>
</attr>

<attr name='days' value='number'>
  <p>Add this number of days to the result.</p>
</attr>

<attr name='hours' value='number'>
  <p>Add this number of hours to the result.</p>
</attr>

<attr name='beats' value='number'>
  <p>Add this number of beats to the result.</p>
</attr>

<attr name='minutes' value='number'>
  <p>Add this number of minutes to the result.</p>
</attr>

<attr name='seconds' value='number'>
   <p>Add this number of seconds to the result.</p>

</attr>",

//----------------------------------------------------------------------

"set-max-cache":#"<desc type='tag'><p><short>
 Sets the maximum time this document can be cached in any ram
 caches.</short></p>

 <p>Default is to get this time from the other tags in the document
 (as an example, <xref href='../if/if_supports.tag' /> sets the time to
 0 seconds since the result of the test depends on the client used.</p>

 <p>You must do this at the end of the document, since many of the
 normal tags will override this value.</p>
</desc>

<attr name='years' value='number'>
 <p>Add this number of years to the time this page was last loaded.</p>
</attr>
<attr name='months' value='number'>
 <p>Add this number of months to the time this page was last loaded.</p>
</attr>
<attr name='weeks' value='number'>
 <p>Add this number of weeks to the time this page was last loaded.</p>
</attr>
<attr name='days' value='number'>
 <p>Add this number of days to the time this page was last loaded.</p>
</attr>
<attr name='hours' value='number'>
 <p>Add this number of hours to the time this page was last loaded.</p>
</attr>
<attr name='beats' value='number'>
 <p>Add this number of beats to the time this page was last loaded.</p>
</attr>
<attr name='minutes' value='number'>
 <p>Add this number of minutes to the time this page was last loaded.</p>
</attr>
<attr name='seconds' value='number'>
 <p>Add this number of seconds to the time this page was last loaded.</p>
</attr>",

//----------------------------------------------------------------------

"cache":#"<desc type='cont'><p><short>
 This tag caches the evaluated result of its contents.</short> When
 the tag is encountered again in a later request, it can thus look up
 and return that result without evaluating the content again.</p>

 <p>Nested <tag>cache</tag> tags are normally cached separately, and
 they are also recognized so that the surrounding tags don't cache
 their contents too. It's thus possible to change the cache parameters
 or completely disable caching of a certain part of the content inside
 a <tag>cache</tag> tag.</p>
 
 <note><p>This implies that many RXML tags that surrounds the inner
 <tag>cache</tag> tag(s) won't be cached. The reason is that those
 surrounding tags use the result of the inner <tag>cache</tag> tag(s),
 which can only be established when the actual context in each request
 is compared to the cache parameters. See the section below about
 cache static tags, though.</p></note>

 <p>Besides the value produced by the content, all assignments to RXML
 variables in any scope are cached. I.e. an RXML code block which
 produces a value in a variable may be cached, and the same value will
 be assigned again to that variable when the cached entry is used.</p>

 <p>When the content is evaluated, the produced result is associated
 with a key that is specified by the optional attributes \"variable\",
 \"key\" and \"profile\". This key is what the the cached data depends
 on. If none of the attributes are used, the tag will have a single
 cache entry that always matches.</p>

 <note><p>It is easy to create huge amounts of cached values if the
 cache parameters are chosen badly. E.g. to depend on the contents of
 the form scope is typically only acceptable when combined with a
 fairly short cache time, since it's otherwise easy to fill up the
 memory on the server simply by making many requests with random
 variables.</p></note>

 <h1>Shared caches</h1>

 <p>The cache can be shared between all <tag>cache</tag> tags with
 identical content, which is typically useful in <tag>cache</tag> tags
 used in templates included into many pages. The drawback is that
 cache entries stick around when the <tag>cache</tag> tags change in
 the RXML source, and that the cache cannot be persistent (see below).
 Only shared caches have any effect if the RXML pages aren't compiled
 and cached as p-code.</p>

 <p>If the cache isn't shared, and the page is compiled to p-code
 which is saved persistently then the produced cache entries can also
 be saved persistently. See the \"persistent-cache\" attribute for
 more details.</p>

 <note><p>For non-shared caches, this tag depends on the caching in
 the RXML parser to work properly, since the cache is associated with
 the specific tag instance in the compiled RXML code. I.e. there must
 be some sort of cache on the top level that can associate the RXML
 source to an old p-code entry before the cache in this tag can have
 any effect. E.g. if the RXML parser module in WebServer is used, you
 have to make sure page caching is turned on in it. So if you don't
 get cache hits when you think there should be, the cache miss might
 not be in this tag but instead in the top level cache that maps the
 RXML source to p-code.</p>

 <p>Also note that non-shared timeout caches are only effective if the
 p-code is cached in RAM. If it should work for p-code that is cached
 on disk but not in RAM, you need to add the attribute
 \"persistent-cache=yes\".</p></note>

 <h1>Cache static tags</h1>

 <note><p>Note that this is only applicable if the compatibility level
 is set to 2.5 or higher.</p></note>

 <p>Some common tags, e.g. <tag>if</tag> and <tag>emit</tag>, are
 \"cache static\". That means that they are cached even though there
 are nested <tag>cache</tag> tag(s). That can be done since they
 simply let their content pass through (repeated zero or more
 times).</p>

 <p>Cache static tags are always evaluated when the surrounding
 <tag>cache</tag> generates a new entry. Other tags are evaluated when
 the entry is used, providing they contain or might contain nested
 <tag>cache</tag> or <tag>nocache</tag>. This can give side effects;
 consider this example:</p>

<ex-box>
<cache>
  <registered-user>
    <nocache>Your name is &registered-user.name;</nocache>
  </registered-user>
</cache>
</ex-box>

 <p>Assume the tag <tag>registered-user</tag> is a custom tag that
 ignores its content whenever the user isn't registered. If it isn't
 cache static, the nested <tag>nocache</tag> tag causes it to stay
 unevaluated in the surrounding cache, and the test of the user is
 therefore kept dynamic. If it on the other hand is cache static, that
 test is cached and the cache entry will either contain the
 <tag>nocache</tag> block and a cached assignment to
 <ent>registered-user.name</ent>, or none of the content inside
 <tag>registered-user</tag>. The dependencies of the outer cache must
 then include the user for it to work correctly.</p>

 <p>Because of this, it's important to know whether a tag is cache
 static or not, and it's noted in the doc for all such tags.</p>

 <h1>Compatibility</h1>

 <p>If the compatibility level of the site is lower than 2.2 and there
 is no \"variable\" or \"profile\" attribute, the cache depends on the
 contents of the form scope and the path of the current page (i.e.
 <ent>page.path</ent>). This is often a bad policy since it's easy for
 a client to generate many cache entries.</p>

 <p>None of the standard RXML tags are cache static if the
 compatibility level is 2.4 or lower.</p>
</desc>

<attr name='variable' value='string'>
 <p>This is a comma-separated list of variables and scopes that the
 cache should depend on. The value can be an empty string, which is
 useful to only disable the default dependencies in compatibility
 mode.</p>

 <p>Since it's important to keep down the size of the cache, this
 should typically be kept to only a few variables with a limited set
 of possible values, or else the cache should have a timeout.</p>
</attr>

<attr name='key' value='string'>
 <p>Use the value of this attribute directly in the key. This
 attribute mainly exist for compatibility; it's better to use the
 \"variable\" attribute instead.</p>

 <p>It is an error to use \"key\" together with \"propagate\", since
 it wouldn't do what you'd expect: The value for \"key\" would not be
 reevaluated when an entry is chosen from the cache, since the nested,
 propagating <tag>cache</tag> isn't reached at all then.</p>
</attr>

<attr name='profile' value='string'>
 <p>A comma-separated list to choose one or more profiles from a set
 of preconfigured cache profiles. Which cache profiles are available
 depends on the RXML parser module in use; the standard RXML parser
 currently has none.</p>
</attr>

<attr name='shared'>
 <p>Share the cache between different instances of the
 <tag>cache</tag> with identical content, wherever they may appear on
 this page or some other in the same server. See the tag description
 for details about shared caches.</p>
</attr>

<attr name='persistent-cache' value='yes|no'>
  <p>If the value is \"yes\" then the cache entries are saved
  persistently, providing the RXML p-code is saved. If it's \"no\"
  then the cache entries are not saved. If it's left out then the
  default is to save if there's no timeout on the cache, otherwise
  not. This attribute has no effect if the \"shared\" attribute is
  used; shared caches can not be saved persistently.</p>
</attr>

<attr name='nocache'>
 <p>Do not cache the content in any way. Typically useful to disable
 caching of a section inside another cache tag.</p>
</attr>

<attr name='propagate'>
 <p>Propagate the cache dependencies to the surrounding
 <tag>cache</tag> tag, if there is any. Useful to locally add
 dependencies to a cache without introducing a new cache level. If
 there is no surrounding <tag>cache</tag> tag, this attribute is
 ignored.</p>

 <p>Note that only the dependencies are propagated, i.e. the settings
 in the \"variable\", \"key\" and \"profile\" attributes. The other
 attributes are used only if there's no surrounding <tag>cache</tag>
 tag.</p>
</attr>

<attr name='nohash'>
 <p>If the cache is shared, then the content won't be made part of the
 cache key. Thus the cache entries can be mixed up with other
 <tag>cache</tag> tags.</p>
</attr>

<attr name='not-post-method'>
 <p>By adding this attribute all HTTP requests using the POST method will
 be unaffected by the caching. The result will be calculated every time,
 and the result will not be stored in the cache. The contents of the cache
 will however remain unaffected by the POST request.</p>
</attr>

<attr name='flush-on-no-cache'>
 <p>If this attribute is used the cache will be flushed every time a client
 sends a pragma no-cache header to the server. These are e.g. sent when
 shift+reload is pressed in Netscape Navigator.</p>
</attr>

<attr name='enable-client-cache'>
</attr>

<attr name='enable-protocol-cache'>
</attr>

<attr name='years' value='number'>
 <p>Add this number of years to the time this entry is valid.</p>
</attr>
<attr name='months' value='number'>
 <p>Add this number of months to the time this entry is valid.</p>
</attr>
<attr name='weeks' value='number'>
 <p>Add this number of weeks to the time this entry is valid.</p>
</attr>
<attr name='days' value='number'>
 <p>Add this number of days to the time this entry is valid.</p>
</attr>
<attr name='hours' value='number'>
 <p>Add this number of hours to the time this entry is valid.</p>
</attr>
<attr name='beats' value='number'>
 <p>Add this number of beats to the time this entry is valid.</p>
</attr>
<attr name='minutes' value='number'>
 <p>Add this number of minutes to the time this entry is valid.</p>
</attr>
<attr name='seconds' value='number'>
 <p>Add this number of seconds to the time this entry is valid.</p>
</attr>",

// Intentionally left undocumented:
//
// <attr name='disable-key-hash'>
//  Do not hash the key used in the cache entry. Normally the
//  produced key is hashed to reduce memory usage and improve speed,
//  but since that makes it theoretically possible that two cache
//  entries clash, this attribute may be used to avoid it.
// </attr>

//----------------------------------------------------------------------

"nocache": #"<desc type='cont'><p><short>
 Avoid caching of a part inside a <tag>cache</tag> tag.</short> This
 is the same as using the <tag>cache</tag> tag with the nocache
 attribute.</p>

 <p>Note that when a part inside a <tag>cache</tag> tag isn't cached,
 it implies that any RXML tags that surround the <tag>nocache</tag>
 tag inside the <tag>cache</tag> tag also aren't cached.</p>
</desc>",

//----------------------------------------------------------------------


    ]);
#endif
