function scroll_menu(menu)
{
  if(getObject(menu)) {
    shiftTo(menu, 0, getScrollTop());
  }
  setTimeout("scroll_menu(\""+menu+"\")", 100);
}

scroll_menu("menu");
//setTimeout("scroll_menu(\"menu\")", 1000);
