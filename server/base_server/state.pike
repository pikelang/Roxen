// This is Roxen state mechanism. Copyright © 1999, Idonex AB.
//

string register_state_consumer(string name, object id) {

  if(!id->misc->state)
    id->misc->state=(["keys":([]),"values":([])]);

  if(search(indices(id->misc->state->keys),name)!=-1)
    return ((string)id->misc->state->keys[name]++)+name;

  id->misc->state->keys+=([name:0]);
  return name;
}

int decode_state(string from, object id) {
  if(!id->misc->state || !from)
    return 0;
  from = MIME.decode_base64(from);
  mixed error=catch {
    object gz = Gz;
    from = gz->inflate()->inflate(from);
  };
  if(arrayp(error)) return 0;
  mapping map=decode_value(from);
  if(!mappingp(map)) return 0;
  foreach(indices(map),string tmp)
    if(!id->misc->state->values[tmp])
      id->misc->state->values+=([tmp:map[tmp]]);
  return 1;
}
  
array list_state_consumers(object id) {
  if(!id->misc->state) return ({});
  return indices(id->misc->state->keys);
}

string encode_state(object id) {
  if(!id->misc->state)
    return "";
  return encode_state4real(id->misc->state->values);
}

private string encode_state4real(mapping state) {
  string from = encode_value(state);
  object gz = Gz;
  return MIME.encode_base64( gz->deflate()->deflate(from));
}

string get_state(string key, object id) {
  if(id->misc->state && id->misc->state->values[key])
    return id->misc->state->values[key];
  return "";
}

string alter_state(object id, string key, string value) {
  if(!id->misc->state)
    return "";

  if(id->misc->state->values[key])
    id->misc->state->values+=([key:value]);
  else
    id->misc->state->values[key]=value;

  return encode_state4real(id->misc->state->values);
}

string preview_altered_state(object id, string key, string value) {
  string ret="";

  if(!id->misc->state)
    return "";

  return encode_state4real(id->misc->state->values+([key:value]));
}
