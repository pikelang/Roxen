// -*- java -*-
// This file is part of ChiliMoon. Copyright (c) 1999 - 2001, Roxen IS.

function scroll_menu(menu)
{
  if(getObject(menu)) {
    shiftTo(menu, getObjectLeft(menu), getScrollTop());
  }
  setTimeout("scroll_menu(\""+menu+"\")", 100);
}

scroll_menu("menu");
//setTimeout("scroll_menu(\"menu\")", 1000);
