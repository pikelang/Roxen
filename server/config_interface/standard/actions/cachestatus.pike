inherit "roxenlib";

constant action = "status";
constant name = "Cache Status";
constant name_svenska = "Cachestatus";

constant doc = "Show information about the main memory cache in roxen";
constant doc_svenska = "Visa information om minnescachen i roxen";

string parse( RequestID id )
{
  return cache->status() +
         (roxen->query("cache")?"<p>"+ roxen->get_garb_info():"");
}
