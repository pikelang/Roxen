#pike __REAL_VERSION__

inherit .Error;

protected mapping(string:string|int) d;
protected .HTTP.Result http_res;

protected void create(string json, void|.HTTP.Result http_res)
{
  d = Standards.JSON.decode(json);
  this::http_res = http_res;
  ::create(_sprintf('s'));
}

public string `type() { return d->type; }
public string `detail() { return d->detail; }
public int `status() { return d->status; }
public string `status_description() {
  return Protocols.HTTP.response_codes[status] || "Unknown";
}
public mapping `headers() {
  return http_res?->headers || ([]);
}

public bool is_bad_nonce() {
  return type == "urn:acme:badNonce" ||
         type == "urn:acme:error:badNonce";
}

string _sprintf(int t)
{
  switch (t)
  {
    case 'd': return sprintf("%d", status);
    case 's':
      return sprintf("ACME error: %s (%d: %s)", detail, status, type);
    default:
      return sprintf("%O(Status: %d, Detail: %s, Type: %s)",
                     object_program(this), status, detail, type);
  }
}
