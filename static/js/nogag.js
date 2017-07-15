function webfontReady (font, opts) {
	if (!opts) opts = {};
	return new Promise(function (resolve, reject) {
		var canvas = document.createElement('canvas');
		var ctx = canvas.getContext('2d');
		var TEST_TEXT = "test.@01N日本語";
		var TEST_SIZE = "100px";

		var timeout = Date.now() + (opts.timeout || 3000);
		(function me () {
			ctx.font = TEST_SIZE + " '" + font + "', sans-serif";
			var w1 = ctx.measureText(TEST_TEXT).width;
			ctx.font = TEST_SIZE + " '" + font + "', serif";
			var w2 = ctx.measureText(TEST_TEXT).width;
			ctx.font = TEST_SIZE + " '" + font + "', monospace";
			var w3 = ctx.measureText(TEST_TEXT).width;
			// console.log(w1, w2, w3);
			if (w1 === w2 && w1 === w3) {
				resolve();
			} else {
				if (Date.now() < timeout) {
					setTimeout(me, 100);
				} else {
					reject('timeout');
				}
			}
		})();
	});
}

if (typeof IntersectionObserver === "undefined") {
	window.IntersectionObserver = function () { };
	window.IntersectionObserver.prototype = {
		observe: function () {}
	};
}

Nogag = {
	data : function (key) {
		return document.documentElement.getAttribute('data-' + key);
	},

	initImages : function () {
		var canvas = document.createElement('canvas');
		var ctx = canvas.getContext('2d');

		/*
		var observer = new IntersectionObserver( function (entries) {
			for (let entry of entries) {
				if (entry.isIntersecting && entry.intersectionRatio > 0.90) {
					console.log(entry.intersectionRatio);
					entry.target.classList.add("intersecting");
				} else {
					entry.target.classList.remove("intersecting");
				}
			}
		}, {
			threshold: [0.25, 0.89, 0.90, 1.0]
		});
		*/

		var photos = document.querySelectorAll('a.picasa');
		var placeholders = {};
		for (var i = 0, it; (it = photos[i]); i++) (function (anchor) {
			var img = anchor.querySelector('img');
			var src = img.getAttribute('src');
			anchor.setAttribute('data-href', anchor.href);

			// observer.observe(it);

			// Loading placeholder
			var width = img.getAttribute('width');
			var height = img.getAttribute('height');
			var wRatio = width  / window.innerWidth;
			var hRatio = height / window.innerHeight;
			var ratio = Math.max(wRatio, hRatio);
			if (ratio > 1) {
				width  = Math.round(width  / ratio);
				height = Math.round(height / ratio);
			}
			// console.log('fill empty image', width, height, wRatio, hRatio);
			if (width && height) {
				if (!placeholders[ width + 'x' + height ]) {
					canvas.width = width;
					canvas.height = height;
					ctx.fillStyle = "#dddddd";
					ctx.fillRect(0, 0, width, height);
					placeholders[ width + 'x' + height ] = canvas.toDataURL('image/png');
				}
				img.src = placeholders[ width + 'x' + height ];
			}

			if (window.innerWidth > 1650) {
				// use fullsize
				src = src.replace(/\/s\d+\//, '/s0/');
			}

			var link = src.replace(/\/s(9[06]0|1280|2048)\//, '/s0/');

			anchor.href = link;

			if (src !== img.getAttribute('src')) {
				anchor.classList.add("loading");
				var loader = new Image();
				// console.log('upgrade loading ' + src);
				loader.onload = function () {
					img.src = src;
					// console.log('upgraded');
					anchor.classList.remove('loading')
				};
				loader.src = src;
			}
		})(it);

	},

	init : function () {
		var articles = document.querySelectorAll('article');
		for (var i = 0, it; (it = articles[i]); i++) {
			Nogag.initEntry(it);
		}

		DateRelative.updateAll();

//		var timer = null, current = null;
//		$(window).scroll(function () {
//			clearTimeout(timer);
//			timer = setTimeout(function () {
//				var sections = $('article > header').map(function () {
//					var $this = $(this);
//					var article = $this.parent();
//					return {
//						element : article,
//						start : $this.offset().top,
//						end   : $this.offset().top + article.height()
//					};
//				});
//
//				var scrollTop = $(window).scrollTop();
//				var section = null;
//				for (var i = 0, it; (it = sections[i]); i++) {
//					if (it.start < scrollTop && scrollTop < it.end) {
//						section = it;
//						break;
//					}
//				}
//
//				if (current !== section) {
//					if (current) current.element.removeClass('current');
//					if (section) section.element.addClass('current');
//					current = section;
//				}
//			}, 10);
//		}).scroll();

		(function () {
			var similar = document.getElementById('preload-similar-entries').href;
			var req = new XMLHttpRequest();
			req.open("GET", similar);
			req.onload = function (e) {
				var data = JSON.parse(req.responseText);
				var ids = similar.match(/id=(\d+)/g);
				for (var i = 0, it; (it = ids[i]); i++) {
					var key = it.replace(/^id=/, '')
					var val = data.result[key] || '';
					if (data.ad)  {
						val += data.ad;
						data.ad = ""; // display once
					}
					if (!val) continue;

					var article = document.querySelector('article[data-id="' + key + '"]');
					var container = article.querySelector('.similar-entries');
					container.innerHTML = val;

					var trackbacks = article.querySelector('.content.trackbacks');
					if (trackbacks) {
						var links = trackbacks.getElementsByTagName('li');
						for (var j = 0, link; (link = links[j]); j++) {
							var duplicate = container.querySelector('li[data-id="' + link.getAttribute('data-id') + '"]');
							if (duplicate) {
								duplicate.parentNode.removeChild(duplicate);
							}
						}
						if (!container.getElementsByTagName('li').length) {
							container.parentNode.removeChild(container);
						}
					}

					DateRelative.updateAll(container);
				}
			};
			req.onerror = function (e) {
			};
			req.send(null);
		})();

		(function () {
			var exif = document.getElementById('preload-exif-entries').href;
			var req = new XMLHttpRequest();
			req.open("GET", exif);
			req.onload = function (e) {
				var data = JSON.parse(req.responseText);
				for (var key in data.result) if (data.result.hasOwnProperty(key)) {
					var val = data.result[key];
					if (!val || !val.model) continue;
					var target = document.querySelector('[data-href="' + key + '"]');
					var info =
						val.model + ' (' + val.make + ') ' +
						val.focallength + 'mm ' +
						'F' + val.fnumber + ' ' +
						'ISO' + val.iso + ' ' +
						(val.speed < 1 ? '1/' + Math.round(1/val.speed): val.speed ) + 'sec ';
					target.title = info;
				}
			};
			req.onerror = function (e) {
			};
			req.send(null);

			if (Nogag.data('auth')) {
				var button = document.querySelector('.nogag-new');
				if (button) {
					button.addEventListener('click', function () {
						location.href = "/edit";
					});
				}
			}
		})();

		webfontReady("Sawarabi Mincho").then(function () {
			balance(document.querySelectorAll([
				'.entries article header h1 a',
				'.entries article header h2 a',
				'.entries article .content h1',
				'.entries article .content h2',
				'.entries article .content h3',
				'.entries article .content h4',
				'.entries article .content h5',
				'.entries article .content h6'
			].join(',')));
		});
	},

	initEntry : function (entry) {
		if (Nogag.data('auth')) {
			var button = entry.querySelector('.nogag-edit');
			if (button) {
				button.addEventListener('click', function () {
					location.href = "/edit?id=" + entry.getAttribute('data-id')
				});
			}
		}
	},

	loadScript : function (url) {
		return new Promise( function (resolve, reject) {
			var script = document.createElement('script');
			script.onload = resolve;
			script.onerror = reject;
			script.src = url;
			document.body.appendChild(script);
		});
	}
};

Nogag.initImages();

document.addEventListener('DOMContentLoaded', function () {
	Nogag.init();

	var req = new XMLHttpRequest();
	req.open("GET", '/.ip');
	req.onload = function (e) {
		var via = req.responseText;
		if (via.indexOf('IPv') !== 0) return;
		document.getElementById('global-navigation').setAttribute('data-ip-info', 'via ' + via);
	};
	req.onerror = function (e) {
	};
	req.send(null);
}, false);
