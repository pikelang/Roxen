#if efun(YpDomain)
class YpMap {
#define error(X) throw( ({ (X), backtrace() }) );
  inherit YpDomain : dm;
  string m_map;

  void `[]=(){
    error("Cannot assign to yp database\n");
  }
  
  void `->=(){
    error("Cannot assign to yp database\n");
  }

  string `[](string ind)
  {
    if(!stringp(ind)) error("Index not a string\n");
    return dm::match(m_map, ind);
  }

  int _sizeof()
  {
    return sizeof(dm::all(m_map));
  }
  
  static private mapping _map;

  array (string) _indices()
  {
    mapping m2;
    if(!_map)
    {
      m2 = _map = dm::all(m_map);
    } else {
      m2=_map;
      _map=0;
    }
    return indices(m2);
  }

  array (string) _values()
  {
    mapping m2;
    if(!_map)
    {
      m2 = _map = dm::all(m_map);
    } else {
      m2=_map;
      _map=0;
    }
    return values(m2);
  }

  mapping cast(string to)
  {
    if(to != "mapping") error("Cannot cast to "+to+"\n");
    return dm::all(m_map);
  }

  mapping all() { return dm::all(m_map); }

  void map(function over) { dm::map(m_map, over); }
  string match(string key) { return dm::match(m_map,key); }
  string server() { return dm::server(m_map); }
  int order() { return dm::order(m_map); }

  void create(string m, string|void domain)
  {
    m_map = m;
    if(!m_map) error("Must pass map to YpMap()\n");
    if(domain)
      dm::create(domain);
    else
      dm::create();
  }
};

void create()
{
  add_constant("YpMap", YpMap);
}
#else
#error YP not available
#endif
