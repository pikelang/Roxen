var isNav4 = false, 
    isIE4 = false, 
    isNav5 = false, 
    isMac = false,
    isMacIE50 = false;

var range="";
var last_popup = false;

if (navigator.appVersion.charAt(0) == "4") {
  if (navigator.appName == "Netscape") {
    isNav4 = true;
  } else {
    if (navigator.platform == "MacPPC")
      isMac = true;
    isIE4 = true;
    range = "all.";
  }
} else if(navigator.appVersion.charAt(0) == "5") {
  if (navigator.appName == "Netscape") {
    isNav5 = true;
    insideWindowWidth = window.innerWidth;
  }
}

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

