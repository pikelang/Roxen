#include <module.h>
inherit "module";

constant cvs_version = "$Id: check_spelling.pike,v 1.2 1998/01/21 18:55:34 grubba Exp $";

#define FILE "etc/errordata"

/* no need to make this very big, it will seldom be used anyway */
#define READ_LINES 200

mapping (string:string) wrong_to_right_data = ([]);
mapping (string:string) right_to_wrong_data = ([]);

/* Use these only for checking single words */
string iswrong(string word)
{
  word=lower_case(word);
  return wrong_to_right_data[word];
}

string isright(string word)
{
  word=lower_case(word);
  return right_to_wrong_data[word];
}

array register_module()
{
  return ({
    MODULE_PARSER,
    "Spell checker",
      "Checks for and marks common misspellings inside the &lt;spell&gt; tag.<p>"
      " &lt;spell [help] [warn]&gt;text to spellcheck[&lt;/spell&gt;]<p>If "
      "warn is defined, all unknown words will be reported",
      0,1
  });
}

array (string) magic(string text,int warn);

string do_spell(string q, mapping args, string words)
{
  int w;
  if(args->warn) w = 1;
  if(args->help) return register_module()[2]+"<p>";
  return words + "<p><b>Spell checking report:</b><p>"+magic(words, w)*"<br>";
}

mapping query_container_callers()
{
  return (["spell":do_spell, ]);
}
  
/* startup code */
void start(int arg)
{
  mixed stat1,stat2;
  int e;
  if(arg) return;

  string l,*r,wrong,right;
  int e;

  l=Stdio.read_bytes(FILE);
  r=lower_case(l)/"\n";
  if(!r) r=({l});
  for(e=0;e<sizeof(r);e++)
  {
    if(strlen(r[e]))
    {
      if(r[e][0]=='#' || (sscanf(r[e],"%s=%s",wrong,right)!=2)) continue;
      wrong_to_right_data[wrong]=right;
      right_to_wrong_data[right]=wrong;
    }
  }

  catch
  {
    l=Stdio.read_bytes("/usr/dict/words");
    foreach(lower_case(l)/"\n", string w)
      right_to_wrong_data[w] = "";
  };
}

#define w_to_r wrong_to_right_data
#define r_to_w right_to_wrong_data

int right,wrong,unknown;
int deduced_right,deduced_wrong,names;

string status()
{
  int c;
  c=right+wrong+unknown+deduced_right+deduced_wrong+names+1;
  
  return (sprintf("<pre>Checked words          :%7d\n"+
		"Known correct words    :%7d\n"+
		"Known incorrect words  :%7d\n"+
		"Correct words          :%7d (%3d%%)\n"+
		"Misspelled words       :%7d (%3d%%)\n"+
		"Words probably correct :%7d (%3d%%)\n"+
		"Words probably wrong   :%7d (%3d%%)\n"+
		"Names                  :%7d (%3d%%)\n"+
		"Unknown words          :%7d (%3d%%)\n</pre>",
		c,
	        sizeof(r_to_w),
	        sizeof(w_to_r),
		right,right*100/c,
		wrong,wrong*100/c,
		deduced_right,deduced_right*100/c,
		deduced_wrong,deduced_wrong*100/c,
		names,names*100/c,
		unknown,unknown*100/c));
}

string spellit(string word,int warn)
{
  string t,tmp,last;

  if(strlen(word)<2) return 0;

  if(word[0]=='\'' && word[strlen(word)-1]=='\'')
  {
    /* de-quote */
    word=word[1..strlen(word)-2];
    if(!strlen(word)) return 0;
  }

  if(t=w_to_r[word])
  {
    wrong++;
    return "\""+word+"\" is spelled \""+t+"\"";
  }
  if(t=r_to_w[word])
  {
    right++;
    return 0;
  }  

  if(warn<2)
  {
    switch(strlen(word))
    {
    default:

    case 3:
      last=word[strlen(word)-3..strlen(word)-1];
      /* -ves -> -f */
      if(last=="ves")
      {
	tmp=word[0..strlen(word)-4]+"f";
	if(t=w_to_r[tmp])
	{
	  deduced_wrong++;
	  return "\""+word+"\" (\""+tmp+"\" is spelled \""+t+"\")";
	}
	if(t=r_to_w[tmp])
	{
	  deduced_right++;
	  return 0;
	}  
      }

      /* -ies  & -ied-> -y */
      if(last=="ies" || last=="ied")
      {
	tmp=word[0..strlen(word)-4]+"y";
	if(t=w_to_r[tmp])
	{
	  deduced_wrong++;
	  return "\""+word+"\" (\""+tmp+"\" is spelled \""+t+"\")";
	}
	if(t=r_to_w[tmp])
	{
	  deduced_right++;
	  return 0;
	}  
      }

      if(last=="ing")
      {
	tmp=word[0..strlen(word)-4];
	if(t=w_to_r[tmp])
	{
	  deduced_wrong++;
	  return "\""+word+"\" (\""+tmp+"\" is spelled \""+t+"\")";
	}
	if(t=r_to_w[tmp])
	{
	  deduced_right++;
	  return 0;
	}  
  
	/* -ing -> -e */
	tmp+="e";
  
	if(t=w_to_r[tmp])
	{
	  deduced_wrong++;
	  return "\""+word+"\" (\""+tmp+"\" is spelled \""+t+"\")";
	}
	if(t=r_to_w[tmp])
	{
	  deduced_right++;
	  return 0;
	}  
      }

      /* -ion -> -e */
      if(last=="ion")
      {
	tmp=word[0..strlen(word)-4]+"e";
  
	if(t=w_to_r[tmp])
	{
	  deduced_wrong++;
	  return "\""+word+"\" (\""+tmp+"\" is spelled \""+t+"\")";
	}
	if(t=r_to_w[tmp])
	{
	  deduced_right++;
	  return 0;
	}  
      }

    case 2:
      last=word[strlen(word)-2..strlen(word)-1];

      /* -ed -> - */
      if(last=="ed")
      {
	tmp=word[0..strlen(word)-3];
  
	if(t=w_to_r[tmp])
	{
	  deduced_wrong++;
	  return "\""+word+"\" (\""+tmp+"\" is spelled \""+t+"\")";
	}
	if(t=r_to_w[tmp])
	{
	  deduced_right++;
	  return 0;
	}  
	tmp+="e";
	if(t=w_to_r[tmp])
	{
	  deduced_wrong++;
	  return "\""+word+"\" (\""+tmp+"\" is spelled \""+t+"\")";
	}
	if(t=r_to_w[tmp])
	{
	  deduced_right++;
	  return 0;
	}  
      }

      /* -'s */
      if(last=="'s")
      {
	tmp=word[0..strlen(word)-3];
  
	if(t=w_to_r[tmp])
	{
	  deduced_wrong++;
	  return "\""+word+"\" (\""+tmp+"\" is spelled \""+t+"\")";
	}
	if(t=r_to_w[tmp])
	{
	  deduced_right++;
	  return 0;
	}  
      }


    case 1:
      /* -s */

      if(word[-1]=='s')
      {
	tmp=word[0..strlen(word)-2];
  
	if(t=w_to_r[tmp])
	{
	  deduced_wrong++;
	  return "\""+word+"\" (\""+tmp+"\" is spelled \""+t+"\")";
	}
	if(t=r_to_w[tmp])
	{
	  deduced_right++;
	  return 0;
	}

      }
  
    case 0:
    }
#if 0
    if(find_living(word))
    {
      names++;
      return 0;
    }
#endif
  }
  unknown++;
  if(warn) return "\""+word+"\" is unknown to spellchecker";
  return 0;
}

string *unique(string *str)
{
  int e;
  mapping q;
  q=([]);
  str=str-({""," "});
  for(e=0;e<sizeof(str);e++) q[str[e]]=1;
  return indices(q);
}

string *magic(string text,int warn)
{
  string *words;
  int e;
  text=lower_case(text);
  text=replace(text,"-\n",""); 
  text=replace(text,"<"," "); 
  text=replace(text,">"," ");
  text=replace(text,"."," ");
  text=replace(text,":"," ");
  text=replace(text,";"," ");
  text=replace(text,"\t"," ");
  text=replace(text,"\n"," ");
  text=replace(text,"!"," ");
  text=replace(text,"|"," ");
  text=replace(text,"?"," ");
  text=replace(text,","," ");
  text=replace(text,"("," ");
  text=replace(text,")"," ");
  text=replace(text,"\""," ");

  words=text/" ";

  if(!words) return ({});

  words-=({"-",""});
//  words=regexp(words,"^[^/]");
//  words=regexp(words,"^[^0123456789]*$");

  words=Array.map(words,spellit,warn);
  words-=({0});
  return unique(words);
}
