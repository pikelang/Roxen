popups = new Array(0);

function checkPopupCoord(x, y, popup_index)
{
  if(popup_index < 0)
    return;
  p = popups[popup_index];
  //setStatus("x: "+x+", y: "+y+", i:"+p.inside+", p: "+popups.length+".");
  //alert("x: "+x+", y: "+y+", i:"+p.inside+", p: "+popups.length+".");
  if((x > p.x && x < p.x + p.w) && (y > p.y && y < p.y + p.h)) {
    if(!p.inside) p.inside = true;
  } else {
    if(p.inside) {
      clearToPopup(p.parent);
      if(popups.length == 0) {
	if(isNav4)
	  document.releaseEvents(Event.MOUSEMOVE);
	else
	  document.onMouseMove = 0; 
      }
    }
    checkPopupCoord(x, y, popup_index - 1);
  }
}

function popupMove(e)
{
  //showProps(e);
  checkPopupCoord(getEventX(e), getEventY(e), popups.length-1);
}

function popup_coord(name, parent, x, y, w, h)
{
  this.name = name;
  this.parent = parent;
  this.x = x;
  this.y = y;
  this.w = w;
  this.h = h;
  this.inside = false;
}

function clearToPopup(popup)
{
  if(popups.length <= 0)
    return;
  if(popup != popups[popups.length - 1].name) {
    hideTopPopup();
    clearToPopup(popup);
  }
}

function showPopup(name, parent, ox, oy, od, e)
{
  //if(getButton(e) != 3)
  //  return true;

  if(oy == 0)
    oy = 15;
  
  if(od == 0)
    od = 10;
  
  if(popups.length != 0) {
    if(popups[popups.length - 1].name == name)
      // The corect popup is allredy there.
      return retFromEvent(false);
  }
  
  clearToPopup(parent);
  
  var popup = getObject(name);
  var p_x = getTargetX(e);
  var p_y = getTargetY(e);
  
  var p_h = getObjectHeight(name);
  var p_w = getObjectWidth(name);
  var c_h = getClientHeight();
  var c_w = getClientWidth();
  var s_l = getScrollLeft();
  var s_t = getScrollTop();

  // If netscape add the parent offset.
  if(isNav4) {
    if(parent == "none" && getObject("menu")) {
      p_x += getObjectLeft("menu");
      p_y += getObjectTop("menu");
    } else if(parent != "none") {
      p_x += getObjectLeft(parent);
      p_y += getObjectTop(parent);
    }
  }

  // Offset the popup to a better place.
  if(parent != "none") {
    p_x += popups[popups.length - 1].w - od;
  } else {
    p_x += ox;
    p_y += oy;
  }
  
  
  //alert("px:"+p_x+" pw:"+p_w+" sl:"+s_l+" cw"+c_w);
  //If the popup is placed outside the screen move it inside.
  if(p_x + p_w > s_l + c_w)
    p_x = s_l + c_w - p_w;
  
  if(p_y + p_h > s_t + c_h)
    p_y = s_t + c_h - p_h;
  
  //alert("D, "+p_x);
  popups[popups.length] = new popup_coord(name, parent,
					  p_x, p_y - (parent == "none"?oy:0),
					  p_w, p_h + (parent == "none"?oy:0));
  //popups.push(new popup_coord(name, parent,
  //				p_x, p_y - (parent == "none"?oy:0),
  //				p_w, p_h + (parent == "none"?oy:0)));

  shiftTo(popup, p_x,  p_y);
  show(popup);
  if(isNav4) {
    document.captureEvents(Event.MOUSEMOVE);
    document.onMouseMove = popupMove;
  } else { 
    document.onmousemove = popupMove;
  }
  return retFromEvent(false);
}

function hidePopup(e)
{
  return;
}

function hideTopPopup()
{
  hide(getObject(popups[popups.length - 1].name));
  popups.length = popups.length - 1;
  //hide(getObject(popups.pop().name));
  return retFromEvent(false);
}
