/*
 * by Francesco Chemolli
 * (C) 1999 Idonex AB
 *
 * Notice: this might look ugly, it's been designed to be split into
 * a "library" program plus a tiny imlpementation module
 */

constant cvs_version="$Id";

#include <module.h>
inherit "module";

#ifdef THROTTLING_DEBUG
#undef THROTTLING_DEBUG
#define THROTTLING_DEBUG(X) perror("Throttling: "+X+"\n")
#else
#define THROTTLING_DEBUG(X)
#endif

#define THROW(X) throw( X+"\n" )


mapping rules;
//format: ([pattern:({command_type,value,0|1(fix)})])
//command_type is a string (+-*/=!), value a float
//if command_type==!, it means no throttling
array(string) rulenames; //needed to keep the rules in order.

//can throw if some rule could not be parsed.
void update_rules() {
  THROTTLING_DEBUG("by type: updating rules");
  rules=([]);
  rulenames=({});
  string line, *words, cmd;
  int lineno=0;
  foreach ( (replace(QUERY(rules),"\t"," ")/"\n"),line) {
    int fix=0;
    float val=0;
    string cmd;
    lineno++;
    if(!sizeof(line))
      continue;
    if(line[0]=='#')
      continue;
    words=(line/" ")-({""});
    
    if (words[1]=="nothrottle") {
      cmd="!";
      val=0;
    } else if (sscanf(words[1],"%[+-*/=]%f",cmd,val) != 2) {
      THROW("Could not parse rule at line "+lineno);
    }
    if (!((<"+","-","*","/","=","!">)[cmd]))
      THROW("Unknown command at line "+lineno);
    if (cmd=="!" || sizeof(words)>2 ) {
      if (cmd=="!" || words[2]=="fix") //don't change order, or it bangs!
        fix=1;
      else
        THROW("Unknown keyword at line "+lineno);
    }
    rules[words[0]]=({cmd,val,fix});
    rulenames+=({words[0]});
  }
  THROTTLING_DEBUG(sprintf("by type: rules are:\n%O\n",rules));
}

array register_module() {
  return ({
    MODULE_FILTER,
    "Throttling: throttle by type",
    "This module will alter the throttling definitions by content type",
    0,0});
}


string check_variable(string name, mixed value) {
  mixed err;
  switch (name) {
  case "rules":
    set(name,lower_case(value));
    err=catch(update_rules());
    if (err) {
      if (arrayp(err))
        return err[0];
      if (objectp(err))
        return err->describe();
    }
    return 0;
  }
}

void start() {
  update_rules();
}

array low_find_rule(string tomatch, mapping rules) {
  THROTTLING_DEBUG("by type: got request for "+tomatch);
  string s;
  foreach(rulenames,s) {
    THROTTLING_DEBUG("by type: examining "+s);
    if (glob(s,tomatch)) {
      THROTTLING_DEBUG("by type: **matched");
      return rules[s];
    }
  }
  THROTTLING_DEBUG("by type: **no match");
  return 0;
}

//override this for other similarly-working modules
array find_rule (mapping res, object id, mapping rules) {
  if (!res) return 0;
  return low_find_rule(res->type,rules);
}

void apply_rule(array rule, object id) {
  id->throttle=1;
  switch(rule[0]) {
  case "+": id->rate+=(int)rule[1];break;
  case "-": id->rate-=(int)rule[1];break;
  case "*": id->rate=(int)(id->rate*rule[1]);break;
  case "/": id->rate=(int)(id->rate/rule[1]);break;
  case "=": id->rate=(int)rule[1]; break;
  case "!": id->throttle=0; break;
  }
  if (rule[2])
    id->misc->fixthrottle=1;
}

mixed filter (mapping res, object id) {
  array rule;
  if (id->misc->fixthrottle)
    return 0;
  rule=find_rule(res,id,rules);
  if (!rule)
    return 0;
  apply_rule(rule,id);
}


void create() {
  defvar("rules","","Rules",TYPE_TEXT_FIELD,
#"Throttling rules. One rule per line, whose format is:<br>
<tt>type-glob modifier [fix]</tt><br>
<tt>type-glob</tt> is matched on the Content Type header.
(i.e. <tt>image/gif</tt> or <tt>text/html</tt>).<p>
<i>modifier</i> is the altering rule. There are six possible rule types:<br>
<tt>+{number}</tt> adds <i>number</i> bytes/sec to the request<br>
<tt>-{number}</tt> subtracts <i>number</i> bytes/sec to the request<br>
<tt>*{number}</tt> multiplies the bandwidth assigned to the request
  by <i>number</i> (a floating-point number)<br>
<tt>/{number}</tt> divides the bandwidth assigned to the request
  by <i>number</i> (a floating-point number)<br>
<tt>={number}</tt> assigns the request <i>number</i> bytes/sec of 
  bandwidth<br>
<tt>nothrottle</tt> asserts that the request is not to be throttled.
  It implies using <tt>fix</tt>.<p>
  The optional keyword <tt>fix</tt> will make the assigned bandwidth final.
The entries are scanned in order, and processing is stopped as soon as 
a match is found.<p>
Lines starting with <tt>#</tt> are considered comments.");
}
