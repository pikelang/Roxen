inherit "roxenlib";

string parse( RequestID id )
{
  return cache->status() + 
         (roxen->query("cache")?"<p>"+ roxen->get_garb_info():"");
}
