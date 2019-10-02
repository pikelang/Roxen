/*
 * By Francesco Chemolli
 * This is a Roxen module. Copyright © 2000 - 2009, Roxen IS.
 */

constant cvs_version="$Id$";


#include <module.h>
inherit "throttlelib";
string filter_type="(by time)";
string rules_doc=
#"<p>Throttling rules. One rule per line, with crontab-like syntax: <br />
<tt>min hour mday month wday modifier [fix]</tt> <br />
The fields can be space- or tab-separated, and valid values are 
comma-separated lists of values or ranges or increments.</p><p>
For instance, the following are valid values (for the hour field):<br />
<tt>1,5,17</tt> means 1, 5 or 17<br />
<tt>12-14</tt> means 12, 13 or 14<br />
<tt>9-12,18-20</tt> means 9, 10, 11, 12, 18, 19 or 20<br />
<tt>3/6</tt> means 3,9,15,21</p><p>
Valid ranges are<br />
<table>
<tr><td>min</td><td>0-59</td></tr>
<tr><td>hour</td><td>0-23</td></tr>
<tr><td>mday</td><td>1-31</td></tr>
<tr><td>month</td><td>1-12</td></tr>
<tr><td>wday</td><td>0-6 (0 is Sunday)</td></tr>
</table></p><p>
<tt>modifier</tt> can be one of: <br />
<tt>+integer</tt>: adds <tt>integer</tt> bytes/sec<br />
<tt>-integer</tt>: subtracts <tt>integer</tt> bytes/sec<br />
<tt>*float</tt>: multiplies the bandwidth by <tt>float</tt><br />
<tt>/float</tt>: dividfes the bandwidth by <tt>float</tt><br />
<tt>=integer</tt>: assigns the request <tt>integer</tt> bytes/sec<br />
<tt>nothrottle</tt>: the request shouldn't be throttled. Implies <tt>fix</tt>
</p><p>
The optional keyword <tt>fix</tt> will prevent further processing on the 
request's bandwidth</p>
<p>If more than one rule matches, only the first will be considered</p>";

#define ANY -1


constant module_type = MODULE_FILTER;
constant module_name = "Throttling: throttle by time";
constant module_doc  = 
#"This module will alter a request's bandwidth by time of the day";
constant module_unique=1;

#ifdef THROTTLING_DEBUG
#undef THROTTLING_DEBUG
#define THROTTLING_DEBUG(X) werror("Throttling by time: "+X+"\n")
#else
#define THROTTLING_DEBUG(X)
#endif

//I'll go the simple way, refreshing a cached value once a minute.
//the efficient way would be going for call_outs, but it would be quite harder
//to implement, and generally not worth it.

private array current_rule;
private mixed update_call_out;

#ifdef OLD
string|void update_rules(string new_rules) {
  THROTTLING_DEBUG("updating rules: "+new_rules);
  string s;
  s=::update_rules(new_rules);
  if (s) return s;
  if (rules)
    rulenames=sort(rulenames); //we really want them sorted now
                               //we'll use this kind of a cache.
  remove_call_out(update_call_out);
  update_call_out=0;
  update_current_rule();
}

void update_current_rule() {
  THROTTLING_DEBUG("updating current rule");
  update_call_out=call_out(update_current_rule,60);

  if (!rules) {
    THROTTLING_DEBUG("empty rules. Bailing out..");
    return;
  }
  mapping(string:int) tm=localtime(time(1));
  string now=(string)(tm->hour)+(string)(tm->min);
  THROTTLING_DEBUG("now is "+now+", rules are "+(indices(rules)*", "));
  foreach(sort(indices(rules)),string rule) {
    THROTTLING_DEBUG("examining: "+rule);
    if (rule >= now) {
      current_rule=rules[rule];
      THROTTLING_DEBUG("selected rule "+rule);
      return;
    }
  }
  THROTTLING_DEBUG("no rule selected");
  current_rule=0; //no rule found
}

#else
//inefficient, but easy to implement. And if you can't spare a few usec
//every minute, you just need another server.
void update_current_rule() {
  THROTTLING_DEBUG("updating current rule");
  update_call_out=call_out(update_current_rule,60);
  if (!rules) {
    THROTTLING_DEBUG("empty rules. Bailing out..");
    return;
  }
  mapping(string:int) tm=localtime(time(1));
  array(int) target=({tm->min,tm->hour,tm->mday,tm->mon+1,tm->wday});
  foreach(indices(rules),array(multiset(int)) rule) {
    THROTTLING_DEBUG(sprintf("matching rule %O",rule));
    int failed=0;
    for(int j=0;j<5;j++) {
      THROTTLING_DEBUG("examining target "+target[j]+" against "+
                       ((array(string))indices(rule[j])*","));
      if (!(rule[j][ANY]) && !(rule[j][target[j]])) {
        THROTTLING_DEBUG("failed");
        failed=1;
        break;
      } else {
        THROTTLING_DEBUG("matched");
      }
    }
    if (!failed) {
      THROTTLING_DEBUG("Found");
      current_rule=rules[rule];
      return;
    }
  }
  THROTTLING_DEBUG("Not found");
  current_rule=0;
}
#endif

array find_rule (mapping res, object id, 
                 array(string) rulenames, mapping rules) {
  return current_rule;
}

void start() {
  THROTTLING_DEBUG("starting");
  ::start();
  if (update_call_out) {
    remove_call_out(update_call_out);
    update_call_out=0;
  }
  update_current_rule(); //not needed, it will be called from update_rules
}

void stop() {
  remove_call_out(update_call_out);
  update_call_out=0;
  //::stop(); What happens if the function is not defined in the parent class?
}

array(int)max_values=({59,23,31,12,6});
//used to check the ranges in the columns

//the rules format here is a bit crazy, especially the index.
//It will be an array(multiset(int)), where the elements are enumerations of
//the moments contained in the parsed line.
array(mixed)|string|int parse_rules_line (string line) {
  int fix=0,j,max_value;
  float val=0;
  string cmd;
  array(string|multiset(int)) words;

  line=replace(line,"\t"," ");
  THROTTLING_DEBUG(" examining: '"+line+"'");
  if(!sizeof(line))
    return 0;
  line=handle_comments(line);
  words=(line/" ")-({""}); //({min, hour, mday, month, wday, operation, fix?})
  switch(sizeof(words)) {
  case 6:
    words+=({0});
    break;
  case 7:
    break;
  default:
    return "syntax error";
  }
  //now we're sure that sizeof(words)=7;
  for(j=0;j<5;j++) {
    multiset(int) val=(<>);
    max_value=max_values[j];
    array(string) ranges;

    THROTTLING_DEBUG("examining ranges: "+words[j]);
    if (words[j]=="*") {
      words[j]=(<ANY>);
      THROTTLING_DEBUG("recognized 'any'");
      continue;
    }
    ranges=words[j]/",";
    foreach(ranges,string s) {
      int pre,post;
      THROTTLING_DEBUG("examining range: "+s);
      if (sscanf(s,"%d/%d",pre,post)==2) {
        if (pre>max_value) return "value out of range: "+pre;
        for(int t=pre;t<=max_value;t+=post) {
          THROTTLING_DEBUG("adding value: "+t);
          val[t]=1;
        }
        continue;
      }
      if (sscanf(s,"%d-%d",pre,post)==2) {
        if (pre>max_value) return "value out of range: "+pre;
        if (post>max_value) return "value out of range: "+post;
        for(int t=pre;t<=post;t++) {
          THROTTLING_DEBUG("adding value: "+t);
          val[t]=1;
        }
        continue;
      }
      if (sscanf(s,"%d",pre)==1) {
        if (pre>max_value) return "value out of range: "+pre;
        THROTTLING_DEBUG("adding value: "+pre);
        val[pre]=1;
        continue;
      }
      THROTTLING_DEBUG("can't parse value");
      return "can't parse value: "+s;
    }
    if (!sizeof(val)) {
      THROTTLING_DEBUG("empty range");
      return "Can't parse ranges: "+words[j];
    }
    words[j]=val;
  }
  //now in words[0..4] we have the key. We need to decode the operation and fix
  array(multiset(int)) key=words[0..4];
  words=words[5..6]; //just to be more comfortable.
  if (lower_case(words[0])=="nothrottle") {
    THROTTLING_DEBUG("nothrottle");
    return ({key,({"!",0,1})});
  }
  if (sscanf(words[0],"%[-+*/=]%f",cmd,val) != 2) {
    THROTTLING_DEBUG("command not understood: '"+words[0]+"'");
    return "command not understood";
  }
  if (!((<"+","-","*","/","=","!">)[cmd])) {
    THROTTLING_DEBUG("unknown command");
    return "unknown command";
  }
  if (words[1]) {
    if (lower_case(words[1])=="fix") {
      fix=1;
    } else {
      THROTTLING_DEBUG("unknown keyword \""+words[1]+"\"");
      return "uknown keyword ["+words[1]+"]";
    }
  }
  return ({key,({cmd,val,fix})});
}
