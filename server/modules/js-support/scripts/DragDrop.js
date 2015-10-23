// -*- java -*-
// This file is part of Roxen WebServer. Copyright (c) 1999 - 2009, Roxen IS.

var modifier;
var src_actions;
var src_path;
var src_name;
var src_url;
var dest_name
var icon = 0;
var timer = 0;

function dragMove(e)
{
  if(icon != 0) {
    if(getEventX(e) - 20 < getScrollLeft())
      deltaScroll(-2, 0);
    if(getEventX(e) + 20 > getScrollLeft() + getClientWidth())
      deltaScroll(2, 0);
    if(getEventY(e) - 20 < getScrollTop())
      deltaScroll(0, -2);
    if(getEventY(e) + 20 > getScrollTop() + getClientHeight())
      deltaScroll(0, 2);
    shiftTo(icon, getEventX(e) + 1, getEventY(e) + 1);
    return retFromEvent(false);
  }
  //return retFromEvent(false);
}

function dragStart()
{
  timer = 0;
  if(isNav4) {
    document.captureEvents(Event.MOUSEMOVE);
    document.onMouseMove = dragMove;
  }
  show(icon);
}

function dragStop()
{
  if(isNav4) document.releaseEvents(Event.MOUSEMOVE);
  icon = 0;
}

function dragDown(actions, path, name, url, icon_name, e)
{
  if(icon != 0 || getButton(e) != 1) {
    return retFromEvent(false);
  }
  icon = getObject(icon_name);
  shiftTo(icon, getEventX(e)+1, getEventY(e)+1);
  modifiers = e.modifiers;
  src_actions = actions;
  src_path = path;
  src_name = name;
  src_url = url;
  timer = setTimeout(dragStart, 200);
  return retFromEvent(true);
}

function dragUp(name, droppable, _onDrop, e)
{
  if(timer != 0 ) {
    clearTimeout(timer);
    dragStop();
    return;
  }
  if(icon != 0) {
    dest_name = name;
    hide(icon);
    icon = 0;
    if(dest_name == src_path)
      return;
    if(!droppable)
      return;
    eval(_onDrop);
    return retFromEvent(false);
  }
}

function dragCancel(e)
{
  var r = routeEvent(e);
  if(r == false) return false;
  if(timer != 0 ) {
    return true;
  }
  if(icon !=0 ) {
    hide(icon);
    dragStop();
    return false; 
  }
}

function dragOver(name)
{
  if(icon == 0 ) {
    setStatus("Click and drag to move '"+name+"'.");
    return;
  }
  setStatus("Move '"+src_path+"' to '"+name+"'.");
  return;
}

if (isNav4) {
  document.captureEvents(Event.MOUSEUP);
  document.onMouseUp = dragCancel;
} else {
  document.onMouseUp = dragCancel;
  document.onMouseMove = dragMove;
}
