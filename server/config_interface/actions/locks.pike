/*
 * $Id$
 */
#include <config_interface.h>
#include <config.h>
#ifdef THREADS

inherit "wizard";
inherit "../logutil";

#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)     _STR_LOCALE("admin_tasks",X,Y)

constant action="debug_info";

string name= LOCALE(280, "Module lock status");
string doc = LOCALE(281,
                    "Shows various information about the module thread "
                    "locks in Roxen.");

string|mapping describe_module(object q)
{
  foreach (roxen->configurations, object c) {
    foreach (indices(c->modules), string m) {
      int w;
      mapping mod = c->modules[m];

      if (mod->enabled == q) {
        [string murl, string mname] = get_conf_url_to_module(c->name+"/"+m);

        return ([
          "url" : murl,
          "name" : mname,
          "filename" : roxen->filename(q)
        ]);
        // return sprintf("<a href=\"%s\">%s</a></td><td>%s",
        //                @get_conf_url_to_module(c->name+"/"+m), roxen->filename(q));
      }
      else if (mod->copies && !zero_type(search(mod->copies,q))) {
        [string murl, string mname] =
          get_conf_url_to_module(c->name+"/"+m+"#"+search(mod->copies,q));

        return ([
          "url" : murl,
          "name" : mname,
          "filename" : roxen->filename(q)
        ]);
        // return sprintf("<a href=\"%s\">%s</a></td><td>%s",
        //                @get_conf_url_to_module(c->name+"/"+m+"#"+search(mod->copies,q)),
        //                roxen->filename(q));
      }
    }
  }
  return ([
    "url" : UNDEFINED,
    "name" : LOCALE(12, "Unknown module"),
    "filename" : roxen->filename(q)
  ]);
  // return LOCALE(12, "Unknown module")+"</td><td>"+roxen->filename(q)+"";
}

string parse( RequestID id )
{
  mapping l = ([]), locks=([]), L=([]);
  foreach(roxen->configurations, object c) {
    if (c->locked) {
      l += c->locked;
    }
    if (c->thread_safe) {
      L += c->thread_safe;
    }
  }
  mapping res=([]);
  string data=("<cf-title>"+
               LOCALE(13, "Module lock status : Accesses to all modules")+
               "</cf-title><p>"+
               LOCALE(14, "Locked means that the access was done using a "
                      "serializing lock since the module was not thread-safe, "
                      "unlocked means that there was no need for a lock.")+
               "</p><p>"+
               LOCALE(15, "Locked accesses to a single module can inflict "
                      "quite a severe performance degradation of the whole "
                      "server, since a locked module will act as a bottleneck, "
                      "blocking access for all other threads that want to "
                      "access that module.")+
               "</p><p>"+
               LOCALE(16, "This is only a problem if a significant percentage "
                      "of the accesses are passed through non-threadsafe "
                      "modules.") +"</p>");
  array mods = (indices(L)+indices(l));
  mods &= mods;

  array rows = ({});

  foreach (mods, object q) {
    mapping m = describe_module(q);
    m->unlocked = (string) L[q];
    m->locked   = (string) l[q];
    rows += ({ m });
    // res[describe_module(q)]+=l[q];
    // locks[describe_module(q)]+=L[q];
  }


  // foreach(sort(indices(res)), string q)
  //   rows += ({ ({q,(string)(res[q]||""),(string)(locks[q]||"") }) });


  string tmpl = #"
    <table class='nice'>
      <thead>
        <tr>
        {{ #heads }}
          <th{{#class}} class='{{class}}'{{/class}}>{{ name }}</th>
        {{ /heads }}
        </tr>
      </thead>
      <tbody>
      {{ #rows }}
        <tr>
          <td>
            {{ #url }}<a href='{{ url }}'>{{ name }}</a>{{ /url }}
            {{ ^url }}<span>{{ name }}</span>{{ /url }}
          </td>
          <td>{{ filename }}</td>
          <td class='text-right'>{{ locked }}</td>
          <td class='text-right'>{{ unlocked }}</td>
        </tr>
      {{ /rows }}
      </tbody>
    </table>";

  mapping mctx = ([
    "heads" : ({
      ([ "name"  : LOCALE(17, "Module") ]),
      ([ "name"  : LOCALE(18, "File")   ]),
      ([ "name"  : LOCALE(19, "Locked"),
         "class" : "text-right" ]),
      ([ "name"  :  LOCALE(20, "Unlocked"),
         "class" : "text-right" ])
    }),
    "rows" : rows
  ]);

  string out = Roxen.render_mustache(tmpl, mctx);

  return data + out + "<p><cf-ok /></p>";
}
#endif /* THREADS */
