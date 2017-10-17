
protected mapping(string:mixed) _data;
protected .Key _key;

protected void create(mapping(string:mixed) data, .Key key)
{
  this::_data = data;
  this::_key = key;
}

public bool is_valid()
{
  return _data && _data->Status && _data->Status == "valid";
}

public int `id() { return _data->id; }
public .Key `key() { return _key; }
public mapping `account_key() { return _data->key; }
public string `agreement() { return _data->agreement; }
public array(string) `contact() { return _data->contact; }
public string `url() { return _data->url; }
public Calendar.Second `created_at() {
  return _data->createdAt && Calendar.dwim_time(_data->createdAt);
}
public string `initial_ip() { return _data->initalIp; }
public mapping(string:mixed) `raw() { return _data; }
