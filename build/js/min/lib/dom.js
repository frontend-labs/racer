/*! racer 17/03/2014 */
define(function(){var DOM;return DOM={get:function(id){return id instanceof HTMLElement||id===document?id:document.getElementById(id)},set:function(id,html){return DOM.get(id).innerHTML=html},on:function(ele,type,fn,capture){DOM.get(ele).addEventListener(type,fn,capture)},un:function(ele,type,fn,capture){return DOM.get(ele).removeEventListener(type,fn,capture)},show:function(ele,type){return DOM.get(ele).style.display=type||"block"},blur:function(ev){return ev.target.blur()},addClassName:function(ele,name){return DOM.toggleClassName(ele,name,!0)},removeClassName:function(ele,name){return DOM.toggleClassName(ele,name,!1)},toggleClassName:function(ele,name,flag){var classes,n;return ele=DOM.get(ele),classes=ele.className.split(" "),n=classes.indexOf(name),flag=("function"==typeof flag?flag(0>n):void 0)?void 0:flag,flag&&0>n?classes.push(name):n>=0&&classes.splice(n,1),ele.className=classes.join(" ")},storage:window.localStorage||{}}});