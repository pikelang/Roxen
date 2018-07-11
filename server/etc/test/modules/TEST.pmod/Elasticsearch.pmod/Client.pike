#pragma strict_types

private string elasticsearch_url;
private mapping(string:string) default_headers =
    ([ "Accept": "application/json; charset=UTF-8" ]);
private mapping(string:string) upload_json_headers = default_headers +
    ([ "Content-Type": "application/json; charset=UTF-8" ]);


protected void create(string elasticsearch_url)
{
  this::elasticsearch_url = elasticsearch_url;
}

public void prepare_index(string index, mapping(string:mixed) index_mapping)
{
  assert_connection();
  if (index_exist(index)) {
    werror("Index %s exists. Deleting it.\n", index);
    delete_index(index);
  }
  werror("Creating index %s.\n", index);
  create_index(index, index_mapping);
}

public bool index_exist(string index)
{
  bool exist = false;
  Protocols.HTTP.Query query;
  mixed e = catch {
    Standards.URI uri = make_uri(elasticsearch_url, "_cat", "indices");
    query = Protocols.HTTP.get_url(uri);
    if (query->status != 200) {
      error("Failed to read indices from elastic search. Status: %d.\n",
             query->status);
    }
    string data = query->data();
    exist = has_value(data, index);
  };
  if (query) {
    query->close();
    query = UNDEFINED;
  }
  if (e) {
    throw(e);
  }
  return exist;
}

public void assert_connection()
{
  Protocols.HTTP.Query query;
  mixed e = catch {
    query = Protocols.HTTP.get_url(elasticsearch_url);
    if (query->status != 200) {
      error("Failed to connect to elastic search. Status: %d.\n", query->status);
    }
  };
  if (query) {
    query->close();
    query = UNDEFINED;
  }
  if (e) {
    throw(e);
  }
}

public void create_index(string index, mapping(string:mixed) index_mapping)
{
  Protocols.HTTP.Query query;
  mixed e = catch {
    Standards.URI uri = make_uri(elasticsearch_url, index);
    string index_mappings_json =
      string_to_utf8(Standards.JSON.encode(index_mapping));
    query =
      Protocols.HTTP.do_method("PUT", uri, 0, upload_json_headers, 0,
                               index_mappings_json);
    if (query->status != 200) {
      error("Wrong return status when creating index. Status %d.\n",
             query->status);
    }
    mapping(string:mixed) data = //Assuming utf-8 here. Ok?
      (mapping(string:mixed))
        Standards.JSON.decode_utf8(query->data());
    if (data->acknowledged != Val.true) {
      error("Failed to create index. Result: %O\n", data);
    }
  };
  if (query) {
    query->close();
    query = UNDEFINED;
  }
  if (e) {
    throw(e);
  }
}

public void delete_index(string index)
{
  Protocols.HTTP.Query query;
  mixed e = catch {
    Standards.URI uri = make_uri(elasticsearch_url, index);
    query = Protocols.HTTP.do_method("DELETE", uri);
    if (query->status != 200) {
      error("Wrong return status when deleting index. Status %d.\n",
             query->status);
    }
    mapping(string:mixed) data = //Assuming utf-8 here. Ok?
      (mapping(string:mixed))
        Standards.JSON.decode_utf8([string] query->data());
    if (data->acknowledged != Val.true) {
      error("Failed to delete index. Result: %O\n", data);
    }
  };
  if (query) {
    query->close();
    query = UNDEFINED;
  }
  if (e) {
    throw(e);
  }
}

// So we don't have to worry about any / beeing where it should not be or any
// / not beeing where it should be.
private Standards.URI make_uri(string baseurl, string ... path)
{
  array(string) path_segments = ({});
  foreach (path, string segments) {
    foreach (segments / "/", string segment) {
      if (sizeof(segment)) {
        path_segments += ({segment});
      }
    }
  }
  string url = baseurl;
  while (has_suffix(url, "/")) {
    url = url[0..<1];
  }
  if (sizeof(path_segments)) {
    url += "/" + path_segments * "/";
  }
  return Standards.URI(url);
}
