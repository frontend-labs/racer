/*! racer 17/03/2014 */
define(function(){var Debugger;return Debugger={storageElements:[],createSector:function(sector){var body;body=document.getElementsByTagName("body")[0],body.appendChild(sector)},updateSector:function(id,value){var sector;sector=document.getElementById(id),sector.innerHTML=value},isLiteralObject:function(element){var _test;return _test=element,"object"!=typeof element||null===element?!1:function(){for(;;)if(null===Object.getPrototypeOf(_test=Object.getPrototypeOf(_test)))break;return Object.getPrototypeOf(element)===_test}()},element:function(label,value){var sector;return this.isLiteralObject(value)&&(value=JSON.stringify(value)),-1===this.storageElements.indexOf(label)?(this.storageElements.push(label),sector=document.createElement("div"),sector.id=label,this.createSector(sector)):this.updateSector(label,value)}}});