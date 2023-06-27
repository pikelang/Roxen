import Parser.XML.Tree;

int main(int argc, array argv)
{
  string s=Stdio.stdin->read();
  Parser.XML.Tree tree=parse_input(s);

  foreach(tree->get_children(), Node node)
    switch(node->get_tag_name())
    {
      case "str":
      {
        Node orig_node, trans_node;
        foreach(node->get_children(), Node child)
        {
          if(child->get_tag_name()=="original")
            orig_node=child;
          if(child->get_tag_name()=="translate")
            trans_node=child;
        }
        trans_node->add_child(Node(XML_TEXT, "",
                                   ([]),
                                   translate(orig_node[0]->get_text(),
                                             "en", argv[1])));
        break;
      }
      
      case "language":
      {
        node->replace_child(node[0],
                            Node(XML_TEXT, "", ([]), argv[1]));
        break;
      }
    }
  
  
  write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"+tree->html_of_node());
}
    
string translate(string s, string from, string to)
{
  werror("%s",s);
  s=Protocols.HTTP.post_url_data("http://babelfish.altavista.com/translate.dyn",
                                        (["enc": "utf8",
                                          "doit": "done",
                                          "bblType": "urltext",
                                          "urltext": s,
                                          "lp": from+"_"+to]));

  if(!sscanf(s, "%*smethod=get>\r\n<textarea %*s>\r\n%s\r\n</textarea>", s))
    sscanf(s,"%*sbgcolor=white>\r\n%s\r\n</td>",s);

  werror(" -> %s\n",s);
  return s;
}

