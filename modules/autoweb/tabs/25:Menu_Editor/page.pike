inherit "roxenlib";
import AutoWeb;

object wa;

array wanted_buttons = ({ ({ "New...", (["path":"foo"]) }) });

array get_buttons(object id)
{
  return wanted_buttons;
}

void create (object webadm)
{
  wa = webadm;
}

string show_entry(object id, int i, string title, string url)
{
  string s="";
  s+=
    "<input type=radio name=item value="+i+((i==(int)id->variables->item)?" checked":"")+
    ">\0"+html_encode_string(title)+"\0"+
    html_encode_string(url)+"\1";
  return s;
}

string|mapping handle(string sub, object id)
{
  array items=MenuFile()->decode(AutoFile(id,"/top.menu")->read());
  if(!id->variables->item) id->variables->item="0";
  int item=(int)id->variables->item;
  array my_buttons=({ ({"Move up","up" }),
		      ({"Move down","down" }),
		      ({"Delete","delete" }),
		      ({"Edit...","edit" }) });
  if(id->variables->up&&item>0)
  {
    items=items[..item-2]+items[item..item]+items[item-1..item-1]+items[item+1..];
    id->variables->item=item-1;
  }
  if(id->variables->down&&item<sizeof(items)-1)
  {
    items=items[..item-1]+items[item+1..item+1]+items[item..item]+items[item+2..];
    id->variables->item=item+1;
  }
  if(id->variables->delete)
    items=items[..item-1]+items[item+1..];
  
  if(id->variables->delete||id->variables->up||id->variables->down||id->variables->delete)
    AutoFile(id,"/top.menu")->save(MenuFile()->encode(items));

  string s=
    "<form action=get action=.>"
    "<tablify nice modulo=1 cellseparator='\0' rowseparator='\1'>"
    "Select\0Title\0URL\1";
  for(int i=0;i<sizeof(items);i++)
    s+=show_entry(id,i,items[i]->title,items[i]->url);
  s+="</tablify>";
  
  s+="<table><tr>";
  foreach(my_buttons, array a)
    s+="<td><input type=submit name=\""+a[1]+"\" value=\""+a[0]+"\"></td>";
  s+="</tr></table></form>";
  return s;
}
