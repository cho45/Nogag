/*

 JSDeferred Copyright (c) 2007 cho45 ( www.lowreal.net )

 http://github.com/cho45/jsdeferred

 License:: MIT

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
*/
function Deferred(){return this instanceof Deferred?this.init():new Deferred}Deferred.ok=function(a){return a};Deferred.ng=function(a){throw a;};
Deferred.prototype={_id:250149748310446,init:function(){this._next=null;this.callback={ok:Deferred.ok,ng:Deferred.ng};return this},next:function(a){return this._post("ok",a)},error:function(a){return this._post("ng",a)},call:function(a){return this._fire("ok",a)},fail:function(a){return this._fire("ng",a)},cancel:function(){(this.canceller||function(){})();return this.init()},_post:function(a,b){this._next=new Deferred;this._next.callback[a]=b;return this._next},_fire:function(a,b){var c="ok";try{b=
this.callback[a].call(this,b)}catch(d){if(c="ng",b=d,Deferred.onerror)Deferred.onerror(d)}Deferred.isDeferred(b)?b._next=this._next:this._next&&this._next._fire(c,b);return this}};Deferred.isDeferred=function(a){return!!(a&&a._id==Deferred.prototype._id)};Deferred.next_default=function(a){var b=new Deferred,c=setTimeout(function(){b.call()},0);b.canceller=function(){clearTimeout(c)};if(a)b.callback.ok=a;return b};
Deferred.next_faster_way_readystatechange="object"===typeof window&&"http:"==location.protocol&&!window.opera&&/\bMSIE\b/.test(navigator.userAgent)&&function(a){var b=new Deferred,c=(new Date).getTime();if(150>c-arguments.callee._prev_timeout_called){var d=!1,e=document.createElement("script");e.type="text/javascript";e.src="data:text/javascript,";e.onreadystatechange=function(){d||(b.canceller(),b.call())};b.canceller=function(){if(!d)d=!0,e.onreadystatechange=null,document.body.removeChild(e)};
document.body.appendChild(e)}else{arguments.callee._prev_timeout_called=c;var g=setTimeout(function(){b.call()},0);b.canceller=function(){clearTimeout(g)}}if(a)b.callback.ok=a;return b};
Deferred.next_faster_way_Image="object"===typeof window&&"undefined"!=typeof Image&&!window.opera&&document.addEventListener&&function(a){var b=new Deferred,c=new Image,d=function(){b.canceller();b.call()};c.addEventListener("load",d,!1);c.addEventListener("error",d,!1);b.canceller=function(){c.removeEventListener("load",d,!1);c.removeEventListener("error",d,!1)};c.src="data:image/png,"+Math.random();if(a)b.callback.ok=a;return b};
Deferred.next_tick="object"===typeof process&&"function"===typeof process.nextTick&&function(a){var b=new Deferred;process.nextTick(function(){b.call()});if(a)b.callback.ok=a;return b};Deferred.next=Deferred.next_faster_way_readystatechange||Deferred.next_faster_way_Image||Deferred.next_tick||Deferred.next_default;
Deferred.chain=function(){for(var a=Deferred.next(),b=0,c=arguments.length;b<c;b++)(function(b){switch(typeof b){case "function":var c=null;try{c=b.toString().match(/^\s*function\s+([^\s()]+)/)[1]}catch(g){}a="error"!=c?a.next(b):a.error(b);break;case "object":a=a.next(function(){return Deferred.parallel(b)});break;default:throw"unknown type in process chains";}})(arguments[b]);return a};
Deferred.wait=function(a){var b=new Deferred,c=new Date,d=setTimeout(function(){b.call((new Date).getTime()-c.getTime())},1E3*a);b.canceller=function(){clearTimeout(d)};return b};Deferred.call=function(a){var b=Array.prototype.slice.call(arguments,1);return Deferred.next(function(){return a.apply(this,b)})};
Deferred.parallel=function(a){1<arguments.length&&(a=Array.prototype.slice.call(arguments));var b=new Deferred,c={},d=0,e;for(e in a)a.hasOwnProperty(e)&&function(e,f){"function"==typeof e&&(e=Deferred.next(e));e.next(function(e){c[f]=e;if(0>=--d){if(a instanceof Array)c.length=a.length,c=Array.prototype.slice.call(c,0);b.call(c)}}).error(function(a){b.fail(a)});d++}(a[e],e);d||Deferred.next(function(){b.call()});b.canceller=function(){for(var b in a)a.hasOwnProperty(b)&&a[b].cancel()};return b};
Deferred.earlier=function(a){1<arguments.length&&(a=Array.prototype.slice.call(arguments));var b=new Deferred,c={},d=0,e;for(e in a)a.hasOwnProperty(e)&&function(e,f){e.next(function(d){c[f]=d;if(a instanceof Array)c.length=a.length,c=Array.prototype.slice.call(c,0);b.canceller();b.call(c)}).error(function(a){b.fail(a)});d++}(a[e],e);d||Deferred.next(function(){b.call()});b.canceller=function(){for(var b in a)a.hasOwnProperty(b)&&a[b].cancel()};return b};
Deferred.loop=function(a,b){var c={begin:a.begin||0,end:"number"==typeof a.end?a.end:a-1,step:a.step||1,last:!1,prev:null},d,e=c.step;return Deferred.next(function(){function a(f){if(f<=c.end){if(f+e>c.end)c.last=!0,c.step=c.end-f+1;c.prev=d;d=b.call(this,f,c);return Deferred.isDeferred(d)?d.next(function(b){d=b;return Deferred.call(a,f+e)}):Deferred.call(a,f+e)}return d}return c.begin<=c.end?Deferred.call(a,c.begin):null})};
Deferred.repeat=function(a,b){var c=0;return Deferred.next(function(){var d=(new Date).getTime();do{if(c>=a)return null;b(c++)}while(20>(new Date).getTime()-d);return Deferred.call(arguments.callee)})};Deferred.register=function(a,b){this.prototype[a]=function(){var a=arguments;return this.next(function(){return b.apply(this,a)})}};Deferred.register("loop",Deferred.loop);Deferred.register("wait",Deferred.wait);
Deferred.connect=function(a,b,c){var d,e;"string"==typeof b?(d=a,e=d[b],a=c||{}):(e=a,a=b||{},d=a.target);var g=a.args?Array.prototype.slice.call(a.args,0):[],f=isFinite(a.ok)?a.ok:a.args?a.args.length:void 0,h=a.ng;return function(){var a=(new Deferred).next(function(a){var b=this._next.callback.ok;this._next.callback.ok=function(){return b.apply(this,a.args)}}),b=g.concat(Array.prototype.slice.call(arguments,0));if(!(isFinite(f)&&null!==f))f=b.length;b.splice(f,0,function(){a.call(new Deferred.Arguments(arguments))});
isFinite(h)&&null!==h&&b.splice(h,0,function(){a.fail(arguments)});Deferred.next(function(){e.apply(d,b)});return a}};Deferred.Arguments=function(a){this.args=Array.prototype.slice.call(a,0)};Deferred.retry=function(a,b,c){c||(c={});var d=c.wait||0,e=new Deferred,g=function(){b(a).next(function(a){e.call(a)}).error(function(b){0>=--a?e.fail(["retry failed",b]):setTimeout(g,1E3*d)})};setTimeout(g,0);return e};Deferred.methods="parallel,wait,next,call,loop,repeat,chain".split(",");
Deferred.define=function(a,b){if(!b)b=Deferred.methods;a||(a=function(){return this}());for(var c=0;c<b.length;c++){var d=b[c];a[d]=Deferred[d]}return Deferred};this.Deferred=Deferred;