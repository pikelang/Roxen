// This is the Roxen WebServer state mechanism.
// Copyright © 1999 - 2009, Roxen IS.
//
// $Id$

#ifdef STATE_HANDLER_DEBUG
# define STATE_WERR(X) werror("State: "+X+"\n")
#else
# define STATE_WERR(X)
#endif

//! This module defines a page state mechanism, i.e. a pike
//! object in which the "objects" on a page can register
//! their state. If the state in one object is altered the
//! state in the others are not lost, as would be the case
//! if all "objects" on the page made their own
//! <a href="page.html?variable=value"> links.
//!
//! The first thing your (tag) module would have to do,
//! once it has created a state object, is to register
//! itself in the page state object. This is done by
//! providing a suggested id, typically the name of the
//! tag. The registration method then returns the given id,
//! which may be a different one than the suggested id.
//!
//! @code
//!   string state_id = "my-tag";
//!   object state = Page_state(id);
//!   state_id = state->register_consumer(state_id, id);
//! @endcode
//!
//! Then it is a good idea to update the state object with
//! the current page state, as given in the encoded state
//! variable. This variable is typically URI-encoded and
//! sent in a forms variable between pages.
//!
//! @code
//!   if(id->real_variables->__state &&
//!      !state->uri_decode(id->real_variables->__state[0]))
//!     RXML.run_error("Error in state.\n");
//! @endcode
//!
//! It is now possible to retrieve the state associated
//! with your page object by calling the get method in the
//! state object.
//!
//! Typically you do not set or alter values in the page
//! state, since the state of the page is only altered by
//! user action, which happens upon page loads. Instead you
//! predict, for each action your object provides, what the
//! resulting state would be and use the encode or
//! uri_encode methods to get a representation of that state
//! that is somehow transfered to the next page. I.e. if
//! your object has two states, 1 and 2, the following code
//! would calculate the proper way to alter the state.
//!
//! @code
//!   string get_actions(string uri, int current_state,
//!                      object state) {
//!     // encode_revisit_url places the encoded state in the variable
//!     // __state by default.
//!     return "<a href='" + state->encode_revisit_url(id, 1) + "'>1</a><br />"
//!            "<a href='" + state->encode_revisit_url(id, 2) + "'>2</a>";
//!   }
//! @endcode


// --- State code -------------------------------------------

#define CHKSPACE "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz+/"

//!
class Page_state {

  RequestID id;
  int use_checksum=1;
  string stateid="";

  //! Initialize the state object
  void create(RequestID in) {
    id=in;
    if(!id->misc->state)
      id->misc+=(["state":(["keys":(<>),"values":([])])]);
  }

  string _sprintf() {
    return "Page_state("+stateid+")";
  }

  string register_consumer(string name)
  //! Register a new state consumer and return state consumer id.
  {
    if(id->misc->state->keys[name]) {
      int prefix=0;
      while(id->misc->state->keys[(string)prefix+name])
        prefix++;
      name=(string)prefix+name;
    }

    stateid=name;
    id->misc->state->keys+=(<name>);
    return name;
  }

  string use_session(void|string new_session_id) {
    new_session_id = new_session_id ||
      id->misc->state->session ||
      roxenp()->create_unique_id();

    id->misc->state->session = new_session_id;

    id->misc->state->values = (cache.get_session_data(new_session_id)||([])) |
      id->misc->state->values;

    return new_session_id;
  }

  int uri_decode(string from)
  {
    return decode(replace(from, ([ " ":"+",
				   "%2B":"+",
				   "%2F":"/",
				   "%3D":"=" ])));
  }

  int decode(string from)
  //! Decode states from a string.
  //! Returns 1 for success, 0 for failure.
  {
    if(!from)
      return 0;

    string session_id;
    sscanf(from, "%s$%s", session_id, from);

    if(use_checksum){
      int chksum=0;
      for(int i=1; i<sizeof(from); i++)
        chksum+=from[i];
      if(from[0] != CHKSPACE[chksum%64]) {
	report_fatal("Error in state checksum. (%O, %O)\n",
		     id->not_query, from);
        return 0;
      }
      from=from[1..];
    }

    if(session_id) {
      id->misc->state->session = id->misc->state->session || session_id;
      id->misc->state->values = (cache.get_session_data(session_id)||([])) |
	id->misc->state->values;
    }

    mixed error=catch {
      from = MIME.decode_base64(from);
      object gz = Gz;
      from = gz->inflate()->inflate(from);
    };
    if(error) {
      report_fatal("Error in state compression/transport encoding.\n");
      return 0;
    }

    mapping new_state;
    if( catch(new_state=decode_value(from)) ) {
      report_fatal("Error in state decode value.\n");
      return 0;
    }
    if(!new_state) return 1;
    if(!mappingp(new_state)) return 0;

    id->misc->state->values = id->misc->state->values | new_state;

    return 1;
  }

  array(string) list_consumers()
  //! List all registered state consumers.
  {
    return indices(id->misc->state->keys);
  }

  protected string low_encode_state(mapping state, void|mapping diff) {
    string session_id = id->misc->state->session;
    if(session_id) {
      cache.set_session_data(state, session_id);
      state = diff;
    }
    else if(diff)
      state = state + diff;

    string from = encode_value(state);
    object gz = Gz;
    string to = MIME.encode_base64( gz->deflate()->deflate(from), 1);

    if(use_checksum) {
      int chksum=0;
      for(int i=0; i<sizeof(to); i++)
        chksum+=to[i];
      to=CHKSPACE[chksum%64..chksum%64]+to;
    }

    if(session_id) to = session_id + "$" + to;

    return to;
  }

  mixed get(void|string key)
  //! Get a specific state.
  {
    return id->misc->state->values[key||stateid];
    return 0;
  }

  string alter(mixed value, void|string key)
  //! Alter a state.
  {
    id->misc->state->values[key||stateid]=value;
    return low_encode_state(id->misc->state->values);
  }

  //! @decl string encode()
  //! @decl string encode(mixed value)
  //! @decl string encode(mixed value, string key)
  //! @decl string encode(array value, array key)
  //! Encode present state into a string.
  string encode(void|mixed value, void|string|array key) {
    if(value) {
      if(arrayp(key)) {
	if(!arrayp(value))
	  error("Bad argument 1 to encode. "
		"If key is an array then value also has to be an array.");

	if(sizeof(value) != sizeof(key))
	  error("encode called on arrays of different sizes (%d != %d).",
		sizeof(value), sizeof(key));
	
	return low_encode_state(id->misc->state->values,
				 mkmapping(key, value));
      }
      else
	return low_encode_state(id->misc->state->values,
				 ([key||stateid:value]));
    }
    return low_encode_state(id->misc->state->values);
  }

  string uri_encode(void|mixed value, void|string|array key)
  //! Encode present state into a URI safe string.
  {
    return replace(encode(value,key), ([ "+":"%2B", "/":"%2F", "=":"%3D" ]));
  }

  string encode_revisit_url (RequestID id, mixed value,
			     void|string|array key, void|string var)
  //! Encode present state into an URL to revisit the current page,
  //! according to @[id]. The encoded state is passed in the variable
  //! @[var], which defaults to "__state" if not given. All other
  //! variables that was sent in the URL from the client are retained.
  //!
  //! @note
  //! The other variables in the URL have the values that were sent
  //! from the client and not the values they have currently. That's a
  //! feature, since the revisit URL will then "redo" the page in all
  //! respects except the state change. Variables that were passed as
  //! headers in a POST method are left out, which also is a feature
  //! for the same reason, considering the intended use of POST.
  {
    string other_vars;

    if (id->query) {
      other_vars = "&" + id->query;
      int i = search (other_vars, "&__state=");
      if (i >= 0) {
	int j = search (other_vars, "&", i + 1);
	other_vars = other_vars[..i - 1] + (j > 0 ? other_vars[j..] : "");
      }
    }
    else other_vars = "";

    // Use a relative url. It's shorter and doesn't give problems when
    // result p-code is replicated.
    return (id->not_query / "/")[-1] +
      "?" + (var || "__state") + "=" + uri_encode (value, key) + other_vars;
  }
}

string decode_session_id(string state) {
  if(!state) return 0;
  string session_id;
  sscanf(state, "%s$", session_id);
  return session_id;
}
