// This is Roxen state mechanism.
// Copyright © 1999 - 2000, Roxen IS.
//
// $Id: state.pike,v 1.15 2000/03/11 17:05:28 nilsson Exp $

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
    return "Page_state()";
  }

  // Register a new state consumer and return state consumer id
  string register_consumer(string name) {
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

  // Decode states from a URI safe string
  int uri_decode(string from) {
    return decode(replace(from,({"-","!","*"}),({"+","/","="})));
  }

  // Decode states from a string
  int decode(string from) {
    if(!from)
      return 0;

    if(use_checksum){
      int chksum=0;
      for(int i=1; i<sizeof(from); i++)
        chksum+=from[i];
      if(from[0] != CHKSPACE[chksum%64])
        return 0;
      from=from[1..];
    }

    mixed error=catch {
      from = MIME.decode_base64(from);
      object gz = Gz;
      from = gz->inflate()->inflate(from);
    };
    if(!intp(error) || error!=0) return 0;

    mapping map;
    mixed error=catch {
      map=decode_value(from);
    };
    if(!intp(error) || error!=0) return 0;
    if(!mappingp(map)) return 0;

    foreach(indices(map),string tmp) {
      if(!id->misc->state->values[tmp])
        id->misc->state->values+=([tmp:map[tmp]]);
    }
    return 1;
  }

  // List all registered state consumers
  array list_consumers() {
    return indices(id->misc->state->keys);
  }

  static string encode_state4real(mapping state) {
    string from = encode_value(state);
    object gz = Gz;
    string to = MIME.encode_base64( gz->deflate()->deflate(from), 1);

    if(use_checksum) {
      int chksum=0;
      for(int i=0; i<sizeof(to); i++)
        chksum+=to[i];
      to=CHKSPACE[chksum%64..chksum%64]+to;
    }

    return to;
  }

  // Get a specific state
  mixed get(void|string key) {
    return id->misc->state->values[key||stateid];
    return 0;
  }

  // Alter a state
  string alter(mixed value, void|string key) {
    id->misc->state->values[key||stateid]=value;
    return encode_state4real(id->misc->state->values);
  }

  // Encode present state into a string
  string encode(void|mixed value, void|string|array key) {
    if(value) {
      if(arrayp(key)) {
	if(!arrayp(value))
	  error("Bad argument 1 to encode. "
		"If key is an array then value also has to be an array.");

	if(sizeof(value) != sizeof(key))
	  error("encode called on arrays of different sizes (%d != %d).",
		sizeof(value), sizeof(key));
	
	return encode_state4real(id->misc->state->values+
				 mkmapping(key, value));
      }
      else
	return encode_state4real(id->misc->state->values+
				 ([key||stateid:value]));
    }
    return encode_state4real(id->misc->state->values);
  }

  // Encode present state into a URI safe string
  string uri_encode(void|mixed value, void|string|array key) {
    return replace(encode(value,key),({"+","/","="}),({"-","!","*"}));
  }

}
