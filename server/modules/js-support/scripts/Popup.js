// -*- java -*-
// This file is part of Roxen WebServer. Copyright (c) 1999 - 2009, Roxen IS.

popups = new Array(0);

//  Extra help function that can be overridden when page coordinates are
//  non-standard (e.g. due to canvas positioning tricks).
function get_vertical_offset()
{
  return 0;
}


// Removes all hide timers.
function clearHideTimers(from)
{
  for(var i = from; i >= 0; i--)
    if(popups[i].hide_timer) {
      clearTimeout(popups[i].hide_timer);
      popups[i].hide_timer = null;
    }
}

function checkPopupCoord(x, y, popup_index)
{
  var parent = (popup_index > 0 ? popups[popup_index - 1].name : "none");
  if(popup_index < 0)
    return;
  p = popups[popup_index];
  //setStatus("x:"+x+", y:"+y+", i:"+p.inside+", p:"+popup_index+
  //		    ", p.x:"+p.x+", p.y:"+p.y+", p.w:"+p.w+", p.h:"+p.h+
  //		    ", p.t:"+p.hide_timer+".");
  //alert("x: "+x+", y: "+y+", i:"+p.inside+", p: "+popups.length+".");
  if((x > p.x && x < p.x + p.w) && (y > p.y && y < p.y + p.h)) {
    p.inside = true;
    p.never_inside = false;
    clearHideTimers(popup_index);
  } else {
    if(p.inside) {
      if(!p.hide_timer) {
	p.hide_timer = setTimeout("clearToPopup('"+parent+"')", p.properties.hide_delay);
      }
      if(popups.length == 0)
	releaseMouseEvent();
    } else if (p.never_inside && p.properties.init_hide_delay > 0) {
	clearHideTimers(popup_index);
	p.hide_timer = setTimeout("clearToPopup('"+parent+"')", 
				  p.properties.init_hide_delay);
    }
    checkPopupCoord(x, y, popup_index - 1);
  }
}

function popupMove(e)
{ 
  checkPopupCoord(getEventX(e), getEventY(e), popups.length-1);
}

function PopupInfo(name, x, y, w, h, properties)
{
  this.name = name;
  this.x = x;
  this.y = y;
  this.w = w;
  this.h = h;
  this.properties = properties;
  this.inside = false;
  this.never_inside = true;
  this.hide_timer = null;
}

function addPopup(name, properties)
{
  popups[popups.length] =
    new PopupInfo(name, getObjectLeft(name),
		  getObjectTop(name) - get_vertical_offset(),
		  getObjectWidth(name), getObjectHeight(name), properties);
}


//  Needs to be called if a popup if resized dynamically so that we'll
//  detect mouse inside/outside correctly.
function resizePopup(name)
{
  if (popups.length == 0)
    return;
  var p = popups[popups.length - 1];
  if (p.name == name) {
    p.w = getObjectWidth(name);
    p.h = getObjectHeight(name);
    p.never_inside = true;
    p.inside = false;
    if (p.hide_timer) {
      clearTimeout(p.hide_timer);
      p.hide_timer = null;
    }
  }
}


// Remove all popups above the given one.
function clearToPopup(popup)
{
  // Remove all hide timers
  clearHideTimers(popups.length - 1);
  while(popups.length > 0 && popup != popups[popups.length - 1].name)
  {
    var p = popups[popups.length - 1];
    hide(p.name);
    if (p.properties.hide_callback)
      p.properties.hide_callback(p.name);
    popups.length--;
  }
}

function boundPopup(name, want_x, want_y)
{
  //  If caller provides <want_x, want_y> we use that instead of the current
  //  popup location.
  var p_l = want_x ? want_x : getObjectLeft(name);
  var p_t = want_y ? want_y : getObjectTop(name);
  var p_h = getObjectHeight(name);
  var p_w = getObjectWidth(name);
  var c_h = getClientHeight() - 8;
  var c_w = getClientWidth() - 8;
  var s_l = getScrollLeft();
  var s_t = getScrollTop();
  
  if((p_l + p_w - s_l) > c_w)
    p_l = Math.max(0, c_w - p_w + s_l);
  
  if((p_t + p_h - s_t) > c_h)
    p_t = Math.max(0, c_h - p_h + s_t);
  
  shiftTo(name, p_l, p_t);
  //alert(p_w+'×'+p_h+'(a)'+p_l+','+p_t+' '+c_w+'×'+c_h+'(a)'+s_l+','+s_t);
}

function TriggerCoord(e, parent_popup_pos, name)
{
  this.x = getTargetX(e);
  this.y = getTargetY(e);
  // If netscape add the parent offset.
  if(isNav4 && parent_popup_pos)
  {
    this.x += parent_popup_pos.x;
    this.y += parent_popup_pos.y;
  }
}

function PopupCoord(name)
{
  this.x = getObjectLeft(name);
  this.y = getObjectTop(name);
  this.h = getObjectHeight(name);
  this.w = getObjectWidth(name);
}

function showPopup(e, name, parent, properties)
{
  if(!properties)
    alert("No properties object for popup '"+name+"'.");
  if(popups.length != 0) {
    if(popups[popups.length - 1].name == name) {
      // The correct popup is allredy there.
      if(properties.hide_2nd_click) {
	clearToPopup(parent);
      }
      else if(popups[popups.length - 1].hide_timer) {
	clearTimeout(popups[popups.length - 1].hide_timer);
	popups[popups.length - 1].hide_timer = null;
	popups[popups.length - 1].inside = false;
      }
      return retFromEvent(false);
    }
  }
  clearToPopup(parent);

  var popup = getObject(name);

  if (!popup) { alert("Unknown object: " + name); return 0; }
  var parentCoord = (parent != "none"? new PopupCoord(parent): 0);
  var pos = new properties.LayerPosition(new TriggerCoord(e, parentCoord, name),
					 parentCoord, properties);
  shiftTo(popup, pos.x, pos.y + get_vertical_offset());
  if (!properties.dont_bound_popup)
      boundPopup(popup);
  addPopup(name, properties);
  show(popup);
  if(properties.init_hide_delay > 0) {
      popups[popups.length-1].hide_timer = setTimeout("clearToPopup('"+parent+"')", 
						    properties.init_hide_delay);
  }
  captureMouseEvent(popupMove);
  return retFromEvent(false);
}

function LayerPosition(trigger_pos, parent_popup_pos, properties)
{
  if (properties.absx) {
    this.x = properties.ox;
  } else {
    this.x = trigger_pos.x;
    if(parent_popup_pos && properties.pox)
      this.x += parent_popup_pos.w - properties.pox;
    else if(trigger_pos.w && properties.pox)
      this.x += trigger_pos.w - properties.pox;
    else
      this.x += properties.ox;
  }
  if (properties.absy) {
    this.y = properties.oy;
  } else {
    this.y = trigger_pos.y;
    if(parent_popup_pos && properties.poy)
      this.y += parent_popup_pos.h - properties.poy;
    else if(trigger_pos.h && properties.poy)
      this.y += trigger_pos.h - properties.poy;
    else
      this.y += properties.oy;
  }
}

function PopupProperties(ox, oy, absx, absy)
{
  this.hide_delay = 300;
  this.init_hide_delay = 0;
  this.ox = ox;
  this.oy = oy;
  this.pox = false;
  this.poy = false;
  this.absx = absx;
  this.absy = absy;
  this.hide_2nd_click = false;
  this.LayerPosition = LayerPosition;
  this.stay_put = false;
  
  this.setHide2ndClick =
    function() { this.hide_2nd_click = true; return this;};
  this.setHideDelay =
    function(hide_delay) { this.hide_delay = hide_delay; return this;};
  this.setInitialHideDelay =
    function(init_hide_delay) { this.init_hide_delay = init_hide_delay; return this;};
  this.setParentRightOffset =
    function(pox) { this.pox = pox; return this;};
  this.setParentBottomOffset =
    function(poy) { this.poy = poy; return this;};
  this.setPageX =
    function(x) { this.ox = x; this.absx = true; return this; };
  this.setPageY =
    function(y) { this.oy = y; this.absy = true; return this; };
}

// Default popup properties
default_props = new PopupProperties(15, 0);

