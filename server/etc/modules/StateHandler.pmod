// This is the Roxen WebServer state mechanism.
// Copyright © 1999 - 2000, Roxen IS.
//
// $Id: StateHandler.pmod,v 1.2 2001/01/25 23:21:39 nilsson Exp $

// This file defines a page state mechanism, i.e. a pike 
// object in which the "objects" on a page can register
// their state. If the state in one object is altered the
// state in the others are not lost, as would be the case
// if all "objects" on the page made their own
// <a href="page.html?variable=value"> links.
//
// The first thing your (tag) module would have to do,
// once it has created a state object, is to register
// itself in the page state object. This is done by
// providing a suggested id, typically the name of the
// tag. The registration method then returns the given id,
// which may be a different one than the suggested id.
//
//   string state_id = "my-tag";
//   object state = Page_state(id);
//   state_id = state->register_consumer(state_id, id);
//
// The it is a good idea to update the state object with
// the current page state, as given in the encoded state
// variable. This variable is typically URI-encoded and
// sent in a forms variable between pages.
//
//   if(id->variables->state &&
//      !state->uri_decode(id->variables->state))
//     RXML.run_error("Error in state.\n");
//
// It is now possible to retrieve the state associated
// with your page object by calling the get method in the
// state object.
//
// Typically you do not set or alter values in the page
// state, since the state of the page is only altered by
// user action, which happens upon page loads. Instead you
// predict, for each action your object provides, what the
// resulting state would be and use the encode or
// uri_encode methods to get a representation of that state
// that is somehow transfered to the next page. I.e. if
// your object has two states, 1 and 2, the following code
// would calculate the proper way to alter the state.
//
//   string get_actions(string uri, int current_state,
//                      object state) {
//     return "<a href='" + uri + "?state=" +
//            state->uri_encode(1) + "'>1</a><br />"
//            "<a href='" + uri + "?state=" +
//            state->uri_encode(2) + "'>2</a>";
//   }
//


// --- State code -------------------------------------------

#define CHKSPACE "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz+/"

class Page_state {

  RequestID id;
  int use_checksum=1;
  string stateid="";

  // Initialize the state object
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
  //! Decode states from a URI safe string.
  //! Returns 1 for success, 0 for failure.
  {
    return decode(replace(from,({"-","!","_"}),({"+","/","="})));
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
      if(from[0] != CHKSPACE[chksum%64])
        return 0;
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
    if(error) return 0;

    mapping new_state;
    if( catch(new_state=decode_value(from)) )
      return 0;
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

  static string low_encode_state(mapping state, void|mapping diff) {
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
    // The "_" here is better for NT filesystems for the manual dumps.
    return replace(encode(value,key),({"+","/","="}),({"-","!","_"}));
  }

}

string decode_session_id(string state) {
  if(!state) return 0;
  string session_id;
  sscanf(state, "%s$", session_id);
  return session_id;
}
