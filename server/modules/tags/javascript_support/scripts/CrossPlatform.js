// -*- java -*-
// This file is part of Internet Server. Copyright (c) 1999 - 2001, Roxen IS.

// Global variables
var isNav4 = false, isIE4 = false, isNav5 = false, isMac = false,
    isMacIE50 = false;
var insideWindowWidth;
var range = "";
var styleObj = "";

// Create a dummy event variable for non navigator browsers.
if(window.event + "" == "undefined")
  event = null;

if (navigator.appVersion.charAt(0) == "4") {
  if (navigator.appName == "Netscape") {
    isNav4 = true;
    insideWindowWidth = window.innerWidth;
  } else {
    if (navigator.platform == "MacPPC")
      isMac = true;
    isIE4 = true;
    range = "all.";
    styleObj = ".style";
  }
} else if(navigator.appVersion.charAt(0) == "5") {
  if (navigator.appName == "Netscape") {
    isNav5 = true;
    insideWindowWidth = window.innerWidth;
  }
}

//  MSIE 5.0 for Mac breaks FileLoader object after first use...
isMacIE50 = isMac && navigator.appVersion.match("MSIE 5.0");


// Convert object name string or object reference
// into a valid object reference
function getObject(obj)
{
  if (typeof obj == "string") {
    if (isNav5)
      return document.getElementById(obj);
    else
      return eval("document." + range + obj);
  }
  else
    return obj;
}

// Positioning an object at a specific pixel coordinate
function shiftTo(obj, x, y) {
  var theObj = getObject(obj);
  if (isNav4) {
    theObj.moveTo(x,y);
  } else if (isNav5) {
    theObj.style.left = x;
    theObj.style.top = y;
  } else {
    theObj.style.pixelLeft = x;
    theObj.style.pixelTop = y;
  }
}

// Moving an object by x and/or y pixels
function shiftBy(obj, deltaX, deltaY) {
  var theObj = getObject(obj);
  if (isNav4) {
    theObj.moveBy(deltaX, deltaY);
  } else {
    theObj.style.pixelLeft += deltaX;
    theObj.style.pixelTop += deltaY;
  }
}

// Setting the z-order of an object
function setZIndex(obj, zOrder) {
  if (isNav4) getObject(obj).zIndex = zOrder;
  else getObject(obj).style.zIndex = zOrder;
}

// Setting the background color of an object
function setBGColor(obj, color) {
  if (isNav4) {
    getObject(obj).bgColor = color;
  } else {
    getObject(obj).style.backgroundColor = color;
  }
}

// Setting the visibility of an object to visible
function show(obj) {
  if (isNav4) getObject(obj).visibility = "visible";
  else getObject(obj).style.visibility = "visible";
}

// Setting the visibility of an object to hidden
function hide(obj) {
  if (isNav4) getObject(obj).visibility = "hidden";
  else getObject(obj).style.visibility = "hidden";
}

function visible(obj) {
  theObj = getObject(obj);
  if (isNav4) return (theObj.visibility == "show");
  else return (theObj.style.visibility == "visible");
}

function hidden(obj) {
  theObj = getObject(obj);
  if (isNav4) return (theObj.visibility == "hide");
  else return (theObj.style.visibility == "hidden");
}

// Retrieving the x coordinate of a positionable object
function getObjectLeft(obj)  {
  if (isNav4) return getObject(obj).left;
  if (isNav5) return getObject(obj).offsetLeft;
  else return getObject(obj).style.pixelLeft;
}

// Retrieving the y coordinate of a positionable object
function getObjectTop(obj)  {
  if (isNav4) return getObject(obj).top;
  if (isNav5) return getObject(obj).offsetTop;
  else return getObject(obj).style.pixelTop;
}

// Retrieving the x coordinate of a non positionable object
function getRelativeObjectLeft(obj)  {
  alert(obj);
  if (isNav4) return getObject(obj).pageX;
  else return getObject(obj).offsetLeft;
}

// Retrieving the y coordinate of a non positionable object
function getRelativeObjectTop(obj)  {
  showProps(obj.offsetParent);
  if (isNav4) return getObject(obj).pageY;
  else return getObject(obj).offsetTop;
}

// Retrieving the height of a positionable object
function getObjectHeight(obj)  {
  if (isNav4) return getObject(obj).clip.height;
  else return getObject(obj).offsetHeight;
}

// Retrieving the width of a positionable object
function getObjectWidth(obj)  {
  if (isNav4) return getObject(obj).clip.width;
  else return getObject(obj).offsetWidth;
}

// Retrieving the actual top scrollposition
function getScrollTop()  {
  if (isNav4||isNav5) return window.pageYOffset;
  else return document.body.scrollTop;
}

// Retrieving the actual left scrollposition
function getScrollLeft()  {
  if (isNav4||isNav5) return window.pageXOffset;
  else return document.body.scrollLeft;
}

// Set the actual top scrollposition
function deltaScroll(dx, dy) {
  if (isNav4) window.scroll(getScrollLeft() + dx, getScrollTop() + dy);
  else alert('scrollVertical not implemented for IE yet.');
}

// Set the actual left scrollposition
function scrollHorizontal(h)  {
  if (isNav4) window.pageXOffset = left;
  else document.body.scrollLeft = left;
}

// Retrieving the clients viewable hight
function getClientHeight()  {
  if (isNav4||isNav5) return innerHeight;
  else return document.body.clientHeight;
}

// Retrieving the clients viewable width
function getClientWidth()  {
  if (isNav4||isNav5) return innerWidth;
  else return document.body.clientWidth;
}

function showProps(o) {
  var result = "";
  count = 0;
  for (var i in o) {
    result += o + "." + i + "=" + o[i] + "\n";
    count++;
    if (count == 25) {
      alert(result);
      result = "";
      count = 0;
    }
  }
  alert(result);
}

function getEventX(e)
{
  if(isNav4||isNav5) {
    return e.pageX;
  }
  if(isIE4) {
    return window.event.clientX + document.body.scrollLeft;
  }
  return 0;
}

function getEventY(e)
{
  if(isNav4||isNav5) {
    return e.pageY;
  }
  if(isIE4) {
    return window.event.clientY + document.body.scrollTop;
  }
}

function getButton(e) {
  if(isNav4) {
    return e.which;
  }
  if(isIE4) {
    var b = window.event.button;
    if(b == 2) return 3;
    if(b == 4) return 2;
    return b;
  }
}

function getTarget(e)
{
  if(isNav4||isNav5){
    return e.target;
  }
  if(isIE4){
    return window.event.srcElement;
  }
}

function getRecursiveLeft(o)
{
  if(o.tagName == "BODY")
    return o.offsetLeft;
  return o.offsetLeft + getRecursiveLeft(o.offsetParent);
}

function getRecursiveTop(o)
{
  if(o.tagName == "BODY")
    return o.offsetTop;
  return o.offsetTop + getRecursiveTop(o.offsetParent);
}

function getTargetX(e)
{
  if(isNav4){
    return e.target.x;
  }
  if(isNav5){
    if (e.target.offsetParent == null)
      // Betst we can do?
      return e.pageX;
    elt = e.target;
    x = 0;
    while (elt.offsetParent != null) {
      x += elt.offsetLeft;
      elt = elt.offsetParent;
    }
    x += elt.offsetLeft;
    return x;
  }
  if(isIE4){
    return getRecursiveLeft(window.event.srcElement);
  }
}

function getTargetY(e)
{
  if(isNav4){
    return e.target.y;
  }
  if(isNav5){
    if (e.target.offsetParent == null)
      // Betst we can do?
      return e.pageY;
    elt = e.target;
    x = 0;
    while (elt.offsetParent != null) {
      x += elt.offsetTop;
      elt = elt.offsetParent;
    }
    x += elt.offsetTop;
    return x;
    // return e.target.offsetTop;
  }
  if(isIE4){
    return getRecursiveTop(window.event.srcElement);
  }
}

function captureMouseEvent(callback)
{
  if(isNav4)
  {
    document.captureEvents(Event.MOUSEMOVE);
    document.onMouseMove = callback;
  }
  else
    document.onmousemove = callback;
}

function releaseMouseEvent()
{
  if(isNav4)
    document.releaseEvents(Event.MOUSEMOVE);
  else
    document.onmousemove = null;
}

function retFromEvent(r)
{
  if(isIE4) window.event.returnValue=r;
  return r;
}

function setStatus(text)
{
  setTimeout("status=\""+text+"\"", 1);
}
