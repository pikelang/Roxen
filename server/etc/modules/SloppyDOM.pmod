// $Id: SloppyDOM.pmod,v 1.10 2004/12/01 16:58:11 mast Exp $

//! A somewhat DOM-like library that implements lazy generation of the
//! node tree, i.e. it's generated from the data upon lookup. There's
//! also a little bit of XPath evaluation to do queries on the node
//! tree.
//!
//! Implementation note: This is generally more pragmatic than
//! @[Parser.XML.DOM], meaning it's not so pretty and compliant, but
//! more efficient.
//!
//! Implementation status: There's only enough implemented to parse a
//! node tree from source and access it, i.e. modification functions
//! aren't implemented. Data hiding stuff like NodeList and
//! NamedNodeMap are not implemented, partly since it's cumbersome to
//! meet the "live" requirement. Also, @[Parser.HTML] is used in XML
//! mode to parse the input. Thus it's too error tolerant to be XML
//! compliant, and it currently doesn't handle DTD elements, like
//! @tt{"<!DOCTYPE"@}, or the XML declaration (i.e. @tt{"<?xml
//! version='1.0'?>"@}.
//!
//! @note
//! This belongs in @[Parser.XML] in Pike, but it's here for the time
//! being until it has stabilized a bit.

// Created 2002-02-14 by Martin Stjernholm

Document parse (string source, void|int raw_values)
//! Normally entities are decoded, and @[Node.xml_format] will encode
//! them again. If @[raw_values] is nonzero then all text and attribute
//! values are instead kept in their original form.
{
  return Document (source, raw_values);
}

//class DOMImplementation {}
//class NodeList {}
//class NamedNodeMap {}

class Node
//!  Basic node.
{
  // NodeType
  constant ELEMENT_NODE                 = 1;
  constant ATTRIBUTE_NODE               = 2;
  constant TEXT_NODE                    = 3;
  constant CDATA_SECTION_NODE           = 4;
  constant ENTITY_REFERENCE_NODE        = 5;
  constant ENTITY_NODE                  = 6;
  constant PROCESSING_INSTRUCTION_NODE  = 7;
  constant COMMENT_NODE                 = 8;
  constant DOCUMENT_NODE                = 9;
  constant DOCUMENT_TYPE_NODE           = 10;
  constant DOCUMENT_FRAGMENT_NODE       = 11;
  constant NOTATION_NODE                = 12;

  Node parent_node;
  Document owner_document;

  string get_node_value() {return 0;}
  void set_node_value (string value);

  string get_node_name();
  int get_node_type();
  Node get_parent_node() {return parent_node;}
  //NodeList get_child_nodes();
  Node get_first_child() {return 0;}
  Node get_last_child() {return 0;}
  Node get_previous_sibling()
    {return parent_node && parent_node->_get_child_by_pos (pos_in_parent - 1);}
  Node get_next_sibling()
    {return parent_node && parent_node->_get_child_by_pos (pos_in_parent + 1);}

  //NamedNodeMap get_attributes() {return 0;}
  Document get_owner_document() {return owner_document;}

  Node insert_before(Node new_child, Node ref_child);
  Node replace_child(Node new_child, Node old_child);
  Node remove_child(Node old_child);
  Node append_child(Node new_child);
  int has_child_nodes() {return 0;}
  Node clone_node (int|void deep);

  string get_text_content()
  //! If the @tt{raw_values@} flag is set in the owning document, the
  //! text is returned with entities and CDATA blocks intact.
  //!
  //! @seealso
  //! @[parse]
  {
    String.Buffer res = String.Buffer();
    _text_content (res);
    return res->get();
  }

  string xml_format()
  //! Returns the formatted XML that corresponds to the node tree.
  //!
  //! @note
  //! Not DOM compliant.
  {
    String.Buffer res = String.Buffer();
    _xml_format (res);
    return res->get();
  }

  // Internals.

  static constant class_name = "Node";

  /*protected*/ int pos_in_parent;

  /*protected*/ Document _get_doc() {return owner_document;}
  /*protected*/ void _text_content (String.Buffer into);
  /*protected*/ void _xml_format (String.Buffer into);
  /*protected*/ void _destruct_tree() {destruct (this_object());}

  static string sprintf_name (int flag) {return "";}
  static string sprintf_attr (int flag) {return "";}
  static string sprintf_content (int flag) {return "";}

  string _sprintf (int flag)
  {
    switch (flag) {
      case 'O':
	return "SloppyDOM." + class_name + "(" + sprintf_name ('O') + ")";
      case 'V':
	string res = sprintf_name ('V') + sprintf_attr ('V');
	string c = sprintf_content ('V');
	if (sizeof (c))
	  if (has_value (c, "\n") || sizeof (c) > 50)
	    res += (sizeof (res) ? ":" : "") + "\n  " + replace (c, "\n", "\n  ");
	  else
	    res += (sizeof (res) ? ": " : "") + c;
	return "SloppyDOM." + class_name + "(" + res + ")";
    }
  }
}

#define CHECK_CONTENT							\
  if (stringp (content))						\
    content = sloppy_parse_fragment (content, this_object());
#define NODE_AT(POS) (stringp (content[POS]) ? make_node (POS) : content[POS])

static class NodeWithChildren
{
  inherit Node;

  Node get_first_child()
  {
    CHECK_CONTENT;
    if (content && sizeof (content)) return NODE_AT (0);
    return 0;
  }

  Node get_last_child()
  {
    CHECK_CONTENT;
    if (content && sizeof (content)) return NODE_AT (-1);
    return 0;
  }

  int has_child_nodes() {return content && sizeof (content);}

  // Internals.

  static constant class_name = "NodeWithChildren";

  /*protected*/ string|array(string|Node) content;

  /*protected*/ Node _get_child_by_pos (int pos)
  {
    if (pos < 0) return 0;
    CHECK_CONTENT;
    if (content && pos < sizeof (content)) return NODE_AT (pos);
    return 0;
  }

  /*protected*/ void _destruct_tree()
  {
    if (arrayp (content))
      foreach (content, string|Node child)
	if (objectp (child)) child->_destruct_tree();
    destruct (this_object());
  }

  static Node make_node (int pos)
  {
    Document doc = _get_doc();
    string text = content[pos];
    Node node;
    if (has_prefix (text, "&")) {
      text = text[1..sizeof (text) - 2];
      if (string decoded = !doc->raw_values &&
	  (Parser.html_entities[text] || Parser.decode_numeric_xml_entity (text)))
	node = Text (doc, decoded);
      else
	node = EntityReference (doc, text);
    }
    else if (has_prefix (text, "<!--"))
      node = Comment (doc, text[4..sizeof (text) - 4]);
    else if (has_prefix (text, "<?")) {
      sscanf (text[..sizeof (text) - 3], "<?%[^ \t\n\r]%*[ \t\n\r]%s",
	      string target, string data);
      node = ProcessingInstruction (doc, target, data || "");
    }
    else if (has_prefix (text, "<![CDATA["))
      node = CDATASection (doc, text[8..sizeof (text) - 4]);
    else
      node = Text (doc, text);
    content[pos] = node;
    node->parent_node = this_object();
    node->pos_in_parent = pos;
    return node;
  }

  static void make_all_nodes()
  {
    CHECK_CONTENT;
    if (arrayp (content))
      for (int i = sizeof (content) - 1; i >= 0; i--)
	if (stringp (content[i]))
	  make_node (i);
  }

  static void format_attrs (mapping(string:string) attrs, String.Buffer into)
  {
    if (owner_document->raw_values)
      foreach (indices (attrs), string attr) {
	string var = attrs[attr];
	if (has_value (var, "\""))
	  into->add (" ", attr, "='", var, "'");
	else
	  into->add (" ", attr, "=\"", var, "\"");
      }
    else
      foreach (indices (attrs), string attr)
	into->add (" ", attr, "=\"",
		   // Serial replace's are currently faster than one parallell.
		   replace (replace (replace (attrs[attr],
					      "&", "&amp;"),
				     "<", "&lt;"),
			    "\"", "&quot;"),
		   "\"");
  }

  /*protected*/ void _text_content (String.Buffer into)
  {
    CHECK_CONTENT;
    if (arrayp (content))
      for (int i = 0; i < sizeof (content); i++) {
	string|Node child = content[i];
	if (objectp (child))
	  switch (child->node_type) {
	    case COMMENT_NODE:
	    case PROCESSING_INSTRUCTION_NODE:
	      break;
	    default:
	      child->_text_content (into);
	  }
	else
	  if (has_prefix (child, "&") || has_prefix (child, "<![CDATA["))
	    make_node (i)->_text_content (into);
	  else if (!has_prefix (child, "<!--") && !has_prefix (child, "<?"))
	    into->add (child);
      }
  }

  static void xml_format_children (String.Buffer into)
  {
    if (stringp (content)) into->add (content);
    if (arrayp (content))
      foreach (content, string|Node child)
	if (stringp (child)) into->add (child);
	else child->_xml_format (into);
  }

  static string sprintf_content (int flag)
  {
    if (stringp (content)) return sprintf ("%O", content);
    if (arrayp (content))
      return map (content, lambda (string|Node child) {
			     if (stringp (child)) return sprintf ("%O", child);
			     return child->_sprintf (flag);
			   }) * ",\n";
    return "";
  }
}

#define CHECK_LOOKUP_MAPPING if (!id_prefix) fix_lookup_mapping();

static int last_used_id = 0;

static class NodeWithChildElements
//!  Node with child elements.
{
  inherit NodeWithChildren;

  string get_attribute (string name);

  //NodeList get_elements_by_tag_name (string tag_name);

  array(Element) get_elements (string name)
  //! Lightweight variant of @[get_elements_by_tag_name] that returns
  //! a simple array instead of a fancy live NodeList.
  //!
  //! @note
  //! Not DOM compliant.
  {
    if (name == "*") {
      CHECK_CONTENT;
      if (!content) return ({});
      return filter (content,
		     lambda (string|Node child) {
		       return objectp (child) && child->node_type == ELEMENT_NODE;
		     });
    }
    else {
      CHECK_LOOKUP_MAPPING;
      return owner_document->_lookup_mapping[id_prefix + name] || ({});
    }
  }

  mapping(string:string)|Node|array(mapping(string:string)|Node)|string
    simple_path (string path, void|int xml_format)
  //! Access a node or a set of nodes through an expression that is a
  //! subset of an XPath RelativeLocationPath. It's one or more Steps
  //! separated by '/'. A Step consists of an AxisSpecifier followed
  //! by a NodeTest and then by an optional Predicate. There can
  //! currently be at most one Predicate in each Step.
  //!
  //! The currently allowed AxisSpecifier NodeTest combinations are:
  //!
  //! @ul
  //! @item
  //!   @tt{name@} to select all child elements with the given name.
  //!   The name can be @tt{"*"@} to select all.
  //! @item
  //!   @tt{@@name@} to select all attributes with the given name. The
  //!   name can be @tt{"*"@} to select all.
  //! @item
  //!   @tt{comment()@} to select all child comments.
  //! @item
  //!   @tt{text()@} to select all child text and CDATA blocks. Note
  //!   that all entity references are also selected, under the
  //!   assumption that they would expand to text only.
  //! @item
  //!   @tt{processing-instruction(name)@} to select all child
  //!   processing instructions with the given name. The name can be
  //!   left out to select all.
  //! @item
  //!   @tt{node()@} to select all child nodes, i.e. the whole content
  //!   of an element node.
  //! @endul
  //!
  //! A Predicate is on the form @tt{[PredicateExpr]@} where
  //! PredicateExpr currently can be in any of the following forms:
  //!
  //! @ul
  //! @item
  //!   An integer indexes one item in the selected set, according to
  //!   the document order. A negative index counts from the end of
  //!   the set.
  //! @item
  //!   @tt{@@name@} filters out the elements in the selected set that
  //!   has an attribute with the given name.
  //! @item
  //!   @tt{@@name="value"@} filters out the elements in the selected
  //!   set that has an attribute with the given name and value.
  //!   Either @tt{'@} or @tt{"@} may be used to delimit the string
  //!   literal.
  //! @endul
  //!
  //! If @[xml_format] is nonzero, the return value is an xml
  //! formatted string of all the matched nodes, in document order.
  //! Otherwise the return value is as follows:
  //!
  //! Attributes are returned as one or more index/value pairs in a
  //! mapping. Other nodes are returned as the node objects. If the
  //! expression is on a form that can give at most one answer then a
  //! single mapping or node is returned, or zero if there was no
  //! match. If the expression can give more answers then the return
  //! value is an array containing zero or more attribute mappings
  //! and/or nodes. The array follows document order.
  //!
  //! @note
  //! Not DOM compliant.
  {
#define NAME_OR_STAR_CC "^\0-)+,/;-@[-^`{-\xbf\xd7\xf7"
#define NAME_CC NAME_OR_STAR_CC "*"

    sscanf (path, "%*[ \t\n\r]%["NAME_OR_STAR_CC"]%*[ \t\n\r]%s", string name, path);

    void simple_path_error (string msg, mixed... args)
    {
      if (sizeof (args)) msg = sprintf (msg, @args);
      msg += sprintf ("%s node%s.\n", class_name,
		      this_object()->node_name ? " " + this_object()->node_name : "");
      error (msg);
    };

    mixed res;

    if (!sizeof (name)) {
      if (sscanf (path, "@%*[ \t\n\r]%["NAME_OR_STAR_CC"]%*[ \t\n\r]%s", name, path)) {
	if (!sizeof (name))
	  simple_path_error ("No attribute name after @ in ");
	mapping(string:string) attr = this_object()->attributes;
	if (!mappingp (attr))
	  simple_path_error ("Cannot access an attribute %O in ", name);
	if (name == "*")
	  res = attr + ([]);
	else if (string val = attr[name])
	  res = ([name: val]);
	else
	  return xml_format && "";
      }
      else simple_path_error ("Invalid path %O in ", path);
    }

    else if (has_prefix (path, "(")) {
      string arg;
      if (sscanf (path, "(%*[ \t\n\r]%["NAME_CC"]%*[ \t\n\r])%*[ \t\n\r]%s",
		  arg, path) != 5)
	simple_path_error ("Invalid node type expression in %O in ", name + path);
      if (sizeof (arg) && name != "processing-instruction")
	simple_path_error ("Cannot give an argument %O to the node type %s in ",
			   arg, name);

      if (name == "node") {
	if (xml_format && !sizeof (path)) {
	  res = String.Buffer();
	  xml_format_children (res);
	  return res->get();
	}
	else {
	  CHECK_CONTENT;
	  res = allocate (sizeof (content));
	  for (int i = sizeof (res) - 1; i >= 0; i--)
	    if (objectp (content[i])) res[i] = content[i];
	    else res[i] = i;
	}
      }

      else {
	CHECK_CONTENT;
	res = ({});

	switch (name) {
	  case "comment":
	    for (int i = 0; i < sizeof (content); i++) {
	      string|Node child = content[i];
	      if (objectp (child)) {
		if (child->node_type == COMMENT_NODE)
		  res += ({child});
	      }
	      else
		if (has_prefix (child, "<!--"))
		  res += ({i});
	    }
	    break;

	  case "text":
	    //normalize();
	    for (int i = 0; i < sizeof (content); i++) {
	      string|Node child = content[i];
	      if (objectp (child)) {
		if ((<TEXT_NODE, ENTITY_REFERENCE_NODE,
		      CDATA_SECTION_NODE>)[child->node_type])
		  res += ({child});
	      }
	      else
		if (!has_prefix (child, "<!--") && !has_prefix (child, "<?"))
		  res += ({i});
	    }
	    break;

	  case "processing-instruction":
	    if (sizeof (arg)) {
	      string scanfmt = "<?" + replace (arg, "%", "%%") + "%[ \t\n\r]";
	      for (int i = 0; i < sizeof (content); i++) {
		string|Node child = content[i];
		if (objectp (child)) {
		  if (child->node_type == PROCESSING_INSTRUCTION_NODE &&
		      child->node_name == arg)
		    res += ({child});
		}
		else
		  if (sscanf (child, scanfmt, string ws) &&
		      (sizeof (ws) || sizeof (child) == sizeof (arg) + 4))
		    res += ({i});
	      }
	    }
	    else
	      for (int i = 0; i < sizeof (content); i++) {
		string|Node child = content[i];
		if (objectp (child)) {
		  if (child->node_type == PROCESSING_INSTRUCTION_NODE)
		    res += ({child});
		}
		else
		  if (has_prefix (child, "<?"))
		    res += ({i});
	      }
	    break;

	  default:
	    simple_path_error ("Invalid node type %s in ", name);
	}
      }
    }

    else res = get_elements (name);

    if (has_prefix (path, "[")) {
    parse_predicate: {
	if (sscanf (path, "[%*[ \t\n\r]%d%*[ \t\n\r]]%*[ \t\n\r]%s",
		    int index, path) == 5) {
	  if (!index)
	    simple_path_error ("Invalid index 0 in expression %O in ", name + "[0]");

	  if (index > 0) {
	    if (index > sizeof (res)) return xml_format && "";
	    if (mappingp (res))
	      res = (mapping) ({((array) res)[index - 1]});
	    else
	      res = res[index - 1];
	  }
	  else {
	    if (index < -sizeof (res)) return xml_format && "";
	    if (mappingp (res))
	      res = (mapping) ({((array) res)[index]});
	    else
	      res = res[index];
	  }

	  if (intp (res)) res = make_node (res);
	  break parse_predicate;
	}

	if (sscanf (path,
		    "[%*[ \t\n\r]@%*[ \t\n\r]%["NAME_CC"]%*[ \t\n\r]%s",
		    string attr_name, string rest) == 5) {
	  string attr_value;
	  if (sscanf (rest, "]%*[ \t\n\r]%s", rest) == 2 ||
	      sscanf (rest, "=%*[ \t\n\r]'%[^']'%*[ \t\n\r]]%*[ \t\n\r]%s",
		      attr_value, rest) == 5 ||
	      sscanf (rest, "=%*[ \t\n\r]\"%[^\"]\"%*[ \t\n\r]]%*[ \t\n\r]%s",
		      attr_value, rest) == 5) {

	    if (mappingp (res)) {
	      if (!(attr_value ? res[attr_name] == attr_value : res[attr_name]))
		return xml_format && "";
	    }
	    else {
	      array(Node) filtered_res = ({});
	      foreach (res, int|Node elem) {
		if (intp (elem)) elem = make_node (elem);
		if (elem->node_type == ELEMENT_NODE &&
		    (attr_value ? elem->attributes[attr_name] == attr_value :
		     elem->attributes[attr_name]))
		  filtered_res += ({elem});
	      }
	      res = filtered_res;
	    }

	    path = rest;
	    break parse_predicate;
	  }
	}

	simple_path_error ("Invalid index expression in %O in ", name + path);
      }
    }

    else
      if (arrayp (res))
	for (int i = sizeof (res) - 1; i >= 0; i--)
	  if (intp (res[i])) res[i] = make_node (res[i]);

    if (sizeof (path)) {
      if (!has_prefix (path, "/"))
	simple_path_error ("Invalid expression %O after ", path);
      path = path[1..];

      if (arrayp (res))
	if (xml_format) {
	  String.Buffer collected = String.Buffer();
	  foreach (res, Node child)
	    if (string subres = child->simple_path && child->simple_path (path, 1))
	      collected->add (subres);
	  return collected->get();
	}
	else {
	  mixed collected = ({});
	  foreach (res, Node child)
	    if (mixed subres = child->simple_path && child->simple_path (path, 0))
	      collected += arrayp (subres) ? subres : ({subres});
	  return collected;
	}

      if (objectp (res) && res->simple_path)
	return res->simple_path (path, xml_format);
      else
	return xml_format ? "" : ({});
    }

    if (xml_format) {
      if (!res) return "";
      String.Buffer collected = String.Buffer();
      if (mappingp (res))
	format_attrs (res, collected);
      else
	res->_xml_format (collected); // Works both when res is Node and array(Node).
      return collected->get();
    }

    return res;
  }

  // Internals.

  static constant class_name = "NodeWithChildElements";

  static string id_prefix;

  static void fix_lookup_mapping()
  {
    id_prefix = (string) ++last_used_id + ":";
    CHECK_CONTENT;
    if (content) {
      mapping lm = _get_doc()->_lookup_mapping;
      foreach (content, string|Node child)
	if (objectp (child) && child->node_type == ELEMENT_NODE)
	  lm[id_prefix + child->node_name] += ({child});
    }
  }
}

//class DocumentFragment {}

class Document
//! @note
//! The node tree is very likely a cyclic structure, so it might be an
//! good idea to destruct it when you're finished with it, to avoid
//! garbage. Destructing the @[Document] object always destroys all
//! nodes in it.
{
  inherit NodeWithChildElements;

  constant node_type = DOCUMENT_NODE;
  int get_node_type() { return DOCUMENT_NODE; }
  string get_node_name() { return "#document"; }

  //DOMImplementation get_implementation();
  //DocumentType get_doctype();

  Element get_document_element()
  {
    if (!document_element) {
      CHECK_CONTENT;
      foreach (content, string|Node node)
	if (objectp (node) && node->node_type == ELEMENT_NODE)
	  return document_element = node;
    }
    return document_element;
  }

#if 0
  // Disabled for now since the tree can't be manipulated anyway.
  Element create_element (string tag_name)
    {return Element (this_object(), tag_name);}
  //DocumentFragment create_document_fragment();
  Text create_text_node (string data)
    {return Text (this_object(), data);}
  Comment create_comment (string data)
    {return Comment (this_object(), data);}
  CDATASection create_cdata_section (string data)
    {return CDATASection (this_object(), data);}
  ProcessingInstruction create_processing_instruction (string target, string data)
    {return ProcessingInstruction (this_object(), target, data);}
  //Attr create_attribute (string name, string|void default_value);
  EntityReference create_entity_reference (string name)
    {return EntityReference (this_object(), name);}
#endif

  //NodeList get_elements_by_tag_name (string tagname);

  array(Element) get_elements (string name)
  //! Note that this one looks among the top level elements, as
  //! opposed to @[get_elements_by_tag_name]. This means that if the
  //! document is correct, you can only look up the single top level
  //! element here.
  //!
  //! @note
  //! Not DOM compliant.
  {
    if (name == "*") {
      CHECK_CONTENT;
      if (!content) return ({});
      return filter (content,
		     lambda (string|Node child) {
		       return objectp (child) && child->node_type == ELEMENT_NODE;
		     });
    }
    else {
      CHECK_LOOKUP_MAPPING;
      return _lookup_mapping[id_prefix + name] || ({});
    }
  }

  int get_raw_values() {return raw_values;}
  //! @note
  //! Not DOM compliant.

  static void create (void|string|array(string|Node) c, void|int raw_vals)
  {
    content = c;
    raw_values = raw_vals;
  }

  // Internals.

  static constant class_name = "Document";

  /*protected*/ int raw_values;
  static Element document_element = 0;
  /*protected*/ mapping(string:array(Node)) _lookup_mapping = ([]);

  /*protected*/ Document _get_doc() {return this_object();}

  /*protected*/ void _xml_format (String.Buffer into) {xml_format_children (into);}

  static void destroy()
  {
    if (arrayp (content))
      foreach (content, string|Node child)
	if (objectp (child)) child->_destruct_tree();
  }
}

//class Attr {}

class Element
{
  inherit NodeWithChildElements;

  string node_name;
  mapping(string:string) attributes;

  constant node_type = ELEMENT_NODE;
  int get_node_type() { return ELEMENT_NODE; }
  string get_node_name() { return node_name; }
  string get_tag_name() { return node_name; }

  //NamedNodeMap get_attributes();

  string get_attribute (string name)
    {return attributes[name] || "";}
  void set_attribute (string name, string value)
    {attributes[name] = value;}
  void remove_attribute (string name)
    {m_delete (attributes, name);}

  //Attr get_attribute_node (string name);
  //Attr set_attribute_node (Attr new_attr);
  //Attr remove_attribute_node (Attr old_attr);

  //void normalize();

  static void create (Document owner, string name, void|mapping(string:string) attr)
  {
    owner_document = owner;
    node_name = name;
    attributes = attr || ([]);
  }

  // Internals.

  static constant class_name = "Element";

  /*protected*/ void _xml_format (String.Buffer into)
  {
    into->add ("<", node_name);
    format_attrs (attributes, into);
    if (content && sizeof (content)) {
      into->add (">");
      xml_format_children (into);
      into->add ("</", node_name, ">");
    }
    else
      into->add (" />");
  }

  static string sprintf_name() {return node_name;}

  static string sprintf_attr()
  {
    if (sizeof (attributes))
      return "(" + map ((array) attributes,
			lambda (array pair) {
			  return sprintf ("%s=%O", pair[0], pair[1]);
			}) * ", " + ")";
    else
      return "";
  }
}

class CharacterData
{
  inherit Node;

  string node_value;

  string get_node_value() { return node_value; }
  void set_node_value(string data) {node_value = data;}
  string get_data() {return node_value;}
  void set_data (string data) {node_value = data;}
  int get_length() {return sizeof (node_value);}

  string substring_data (int offset, int count)
    {return node_value[offset..offset + count - 1];}
  void append_data (string arg)
    {node_value += arg;}
  void insert_data (int offset, string arg)
    {node_value = node_value[..offset - 1] + arg + node_value[offset..];}
  void delete_data (int offset, int count)
    {node_value = node_value[..offset - 1] + node_value[offset + count..];}
  void replace_data (int offset, int count, string arg)
    {node_value = node_value[..offset - 1] + arg + node_value[offset + count..];}

  // Internals.

  static constant class_name = "CharacterData";

  /*protected*/ void _text_content (String.Buffer into)
  {
    if (owner_document->raw_values) {
      // Serial replace's are currently faster than one parallell.
      into->add (replace (replace (replace (node_value,
					    "&", "&amp;"),
				   "<", "&lt;"),
			  ">", "&gt;"));
    }
    else
      into->add (node_value);
  }

  static string sprintf_content (int flag) {return sprintf ("%O", node_value);}
}

class Text
{
  inherit CharacterData;

  constant node_type = TEXT_NODE;
  int get_node_type() { return TEXT_NODE; }
  string get_node_name() { return "#text"; }

  //Text split_text (int offset);

  static void create (Document owner, string data)
  {
    owner_document = owner;
    node_value = data;
  }

  // Internals.

  static constant class_name = "Text";

  /*protected*/ void _xml_format (String.Buffer into)
  {
    // Serial replace's are currently faster than one parallell.
    into->add (replace (replace (replace (node_value,
					  "&", "&amp;"),
				 "<", "&lt;"),
			">", "&gt;"));
  }
}

class Comment
{
  inherit CharacterData;

  constant node_type = COMMENT_NODE;
  int get_node_type() { return COMMENT_NODE; }
  string get_node_name() { return "#comment"; }

  static void create (Document owner, string data)
  {
    owner_document = owner;
    node_value = data;
  }

  // Internals.

  static constant class_name = "Comment";

  /*protected*/ void _xml_format (String.Buffer into)
  {
    into->add ("<!--", node_value, "-->");
  }
}

class CDATASection
{
  inherit Text;

  constant node_type = CDATA_SECTION_NODE;
  int get_node_type() { return CDATA_SECTION_NODE; }
  string get_node_name() { return "#cdata-section"; }

  static void create (Document owner, string data)
  {
    owner_document = owner;
    node_value = data;
  }

  // Internals.

  static constant class_name = "CDATASection";

  /*protected*/ void _text_content (String.Buffer into)
  {
    if (owner_document->raw_values)
      into->add ("<![CDATA[", node_value, "]]>");
    else
      into->add (node_value);
  }

  /*protected*/ void _xml_format (String.Buffer into)
  {
    into->add ("<![CDATA[", node_value, "]]>");
  }
}

//class DocumentType {}
//class Notation {}
//class Entity {}

class EntityReference
{
  inherit Node;

  string node_name;

  constant node_type = ENTITY_REFERENCE_NODE;
  int get_node_type() { return ENTITY_REFERENCE_NODE; }
  string get_node_name() { return node_name; }

  //NodeList get_child_nodes();
  //Node get_first_child();
  //Node get_last_child();
  //Node get_previous_sibling();
  //Node get_next_sibling();

  static void create (Document owner, string name)
  {
    owner_document = owner;
    node_name = name;
  }

  // Internals.

  static constant class_name = "EntityReference";

  /*protected*/ void _text_content (String.Buffer into)
  {
    if (owner_document->raw_values)
      into->add ("&", node_name, ";");
    else
      if (string decoded = Parser.html_entities[node_name] ||
	  Parser.decode_numeric_xml_entity (node_name))
	into->add (decoded);
      else
	error ("Cannot decode entity reference %O.\n", node_name);
  }

  static string sprintf_name() {return node_name;}

  /*protected*/ void _xml_format (String.Buffer into)
  {
    into->add ("&", node_name, ";");
  }
}

class ProcessingInstruction
{
  inherit Node;

  string node_name, node_value;

  constant node_type = PROCESSING_INSTRUCTION_NODE;
  int get_node_type() { return PROCESSING_INSTRUCTION_NODE; }
  string get_node_name() { return node_name; }
  string get_target() { return node_name; }
  string get_node_value() { return node_value; }

  void set_node_value (string data) {node_value = data;}
  string get_data() {return node_value;}
  void set_data (string data) {node_value = data;}

  static void create (Document owner, string t, string data)
  {
    owner_document = owner;
    node_name = t;
    node_value = data;
  }

  // Internals.

  static constant class_name = "ProcessingInstruction";

  /*protected*/ void _text_content (String.Buffer into)
  {
    if (owner_document->raw_values) {
      // Serial replace's are currently faster than one parallell.
      into->add (replace (replace (replace (node_value,
					    "&", "&amp;"),
				   "<", "&lt;"),
			  ">", "&gt;"));
    }
    else
      into->add (node_value);
  }

  /*protected*/ void _xml_format (String.Buffer into)
  {
    if (sizeof (node_value))
      into->add ("<?", node_name, " ", node_value, "?>");
    else
      into->add ("<?", node_name, "?>");
  }

  static string sprintf_name() {return node_name;}
  static string sprintf_content (int flag) {return sprintf ("%O", node_value);}
}

// Internals.

static int(0..0) return_zero() {return 0;}

static array sloppy_parser_container_callback (
  Parser.HTML p, mapping(string:string) args, string content, Node cur)
{
  if (Parser.HTML ent_p = p->entity_parser)
    foreach (indices (args), string arg)
      args[arg] = ent_p->finish (args[arg])->read();
  Element element = Element (cur->_get_doc(), p->tag_name(), args);
  element->parent_node = cur;
  element->content = p->tag_content();
  return ({element});
}

static array|int sloppy_parser_tag_callback (Parser.HTML p, string text, Node cur)
{
  if (text[-2] != '/') {
    sscanf (text, "<%[^ \t\n\r>]", text);
    p->add_container (text, sloppy_parser_container_callback);
    return 1;
  }
  mapping(string:string) args = p->tag_args();
  if (Parser.HTML ent_p = p->entity_parser)
    foreach (indices (args), string arg)
      args[arg] = ent_p->finish (args[arg])->read();
  Element element = Element (cur->_get_doc(), p->tag_name(), args);
  element->parent_node = cur;
  element->content = "";
  return ({element});
}

static array sloppy_parser_entity_callback (Parser.HTML p, string text, Node cur)
{
  text = p->tag_name();
  if (string chr = Parser.decode_numeric_xml_entity (text))
    return ({chr});
  EntityReference ent = EntityReference (cur->_get_doc(), text);
  ent->parent_node = cur;
  return ({ent});
}

static class SloppyParser
{
  inherit Parser.HTML;
  Parser.HTML entity_parser;
}

static SloppyParser sloppy_parser_template =
  lambda() {
    SloppyParser p = SloppyParser();
    p->lazy_entity_end (1);
    p->match_tag (0);
    p->xml_tag_syntax (3);
    p->mixed_mode (1);
    p->add_quote_tag ("!--", return_zero, "--");
    p->add_quote_tag ("![CDATA[", return_zero, "]]");
    p->add_quote_tag ("?", return_zero, "?");
    p->_set_tag_callback (sloppy_parser_tag_callback);
    p->_set_entity_callback ((mixed) return_zero); // Cast due to type inference bug.
    return p;
  }();

static array(string|Node) sloppy_parse_fragment (string frag, Node cur)
{
  Parser.HTML p = sloppy_parser_template->clone();
  if (!cur->_get_doc()->raw_values)
    p->entity_parser = Parser.html_entity_parser();
  p->set_extra (cur);
  array(string|Node) res = p->finish (frag)->read();
  for (int i = sizeof (res) - 1; i >= 0; i--)
    if (objectp (res[i])) res[i]->pos_in_parent = i;
  return res;
}
