// This is Roxen state mechanism. Copyright © 1999, Idonex AB.
//
// $Id: state.pike,v 1.5 1999/08/11 13:11:24 grubba Exp $

#define CHKSPACE "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

string register_state_consumer(string name, object id) {

  if(!id->misc->state)
    id->misc+=(["state":(["keys":(<>),"values":([])])]);

  if(id->misc->state->keys[name]) {
    int prefix=0;
    while(id->misc->state->keys[(string)prefix+name])
      prefix++;
    name=(string)prefix+name;
  }

  id->misc->state->keys+=(<name>);
  return name;
}

int decode_state(string from, object id) {
  if(!from)
    return 0;

  int chksum=0;
  for(int i=1; i<sizeof(from); i++)
    chksum+=from[i];
  if(from[0] != CHKSPACE[chksum%64])
    return 0;

  mixed error=catch {
    from = MIME.decode_base64(from[1..]);
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

  if(!id->misc->state)
    id->misc+=(["state":(["keys":([]),"values":([]) ]) ]);
  foreach(indices(map),string tmp) {
    if(!id->misc->state->values[tmp])
      id->misc->state->values+=([tmp:map[tmp]]);
  }
  return 1;
}
  
array list_state_consumers(object id) {
  if(!id->misc->state) return ({});
  return indices(id->misc->state->keys);
}

string encode_state(object id) {
  if(!id->misc->state)
    return 0;
  return encode_state4real(id->misc->state->values);
}

private string encode_state4real(mapping state) {
  string from = encode_value(state);
  object gz = Gz;
  string to = MIME.encode_base64( gz->deflate()->deflate(from));
  to-="\r";
  to-="\n";
  int chksum=0;
  for(int i=0; i<sizeof(to); i++)
    chksum+=to[i];
  return CHKSPACE[chksum%64..chksum%64]+to;
}

mixed get_state(string key, object id) {
  if(id->misc->state && id->misc->state->values[key])
    return id->misc->state->values[key];
  return 0;
}

string alter_state(object id, string key, mixed value) {
  if(!id->misc->state)
    return "";

  if(id->misc->state->values[key])
    id->misc->state->values+=([key:value]);
  else
    id->misc->state->values[key]=value;

  return encode_state4real(id->misc->state->values);
}

string preview_altered_state(object id, string key, mixed value) {
  string ret="";

  if(!id->misc->state)
    return "";

  return encode_state4real(id->misc->state->values+([key:value]));
}
