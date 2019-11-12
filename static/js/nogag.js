function webfontReady (font, opts) {
	if (!opts) opts = {};
	return new Promise(function (resolve, reject) {
		var canvas = document.createElement('canvas');
		var ctx = canvas.getContext('2d');
		var TEST_TEXT = "test.@01N日本語";
		var TEST_SIZE = "100px";

		var timeout = Date.now() + (opts.timeout || 5000);
		(function me () {
			ctx.font = TEST_SIZE + " '" + font + "', sans-serif";
			var w1 = ctx.measureText(TEST_TEXT).width;
			ctx.font = TEST_SIZE + " '" + font + "', serif";
			var w2 = ctx.measureText(TEST_TEXT).width;
			ctx.font = TEST_SIZE + " '" + font + "', monospace";
			var w3 = ctx.measureText(TEST_TEXT).width;
			console.log(w1, w2, w3);
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

		this.initSimilarEntries();
		this.initExif();
		this.initWebfont();
		this.initABC();

		(function () {
			if (Nogag.data('auth')) {
				var button = document.querySelector('.nogag-new');
				if (button) {
					button.addEventListener('click', function () {
						location.href = "/edit";
					});
				}
			}
		})();
	},

	initSimilarEntries : async function () {
		const similar = document.getElementById('preload-similar-entries').href;
		console.log('fetch', similar);
		const res = await fetch(similar);
		const data = await res.json();

		const ids = similar.match(/id=(\d+)/g);
		for (let i = 0, it; (it = ids[i]); i++) {
			const key = it.replace(/^id=/, '')
			let val = data.result[key] || '';
			if (data.ad)  {
				val += data.ad;
				data.ad = ""; // display once
			}
			if (!val) continue;

			const article = document.querySelector('article[data-id="' + key + '"]');
			const container = article.querySelector('.similar-entries');
			container.innerHTML = val;

			const trackbacks = article.querySelector('.content.trackbacks');
			if (trackbacks) {
				const links = trackbacks.getElementsByTagName('li');
				for (let j = 0, link; (link = links[j]); j++) {
					const duplicate = container.querySelector('li[data-id="' + link.getAttribute('data-id') + '"]');
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
	},

	initExif: async function () {
		const exif = document.getElementById('preload-exif-entries').href;
		const res = await fetch(exif);
		const data = await res.json();

		for (let key in data.result) if (data.result.hasOwnProperty(key)) {
			const val = data.result[key];
			if (!val || !val.model) continue;
			const target = document.querySelector('[data-href="' + key + '"]');
			const info =
				val.model + ' (' + val.make + ') ' +
				val.focallength + 'mm ' +
				'F' + val.fnumber + ' ' +
				'ISO' + val.iso + ' ' +
				(val.speed < 1 ? '1/' + Math.round(1/val.speed): val.speed ) + 'sec ';
			target.title = info;
		}
	},

	initWebfont: function () {
		webfontReady("Noto Serif JP").then(function () {
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

	initABC : function () {
		const targets = document.querySelectorAll('pre.lang-abc');
		for (var i = 0, it; (it = targets[i]); i++) {
			const notation = it.textContent;
			const container = document.createElement('div');
			container.setAttribute("class", "lang-abc");
			ABCJS.renderAbc(container, notation, {
				staffwidth: container.offsetWidth,
				add_classes: true,
				responsive: "resize"
			});
			it.parentNode.replaceChild(container, it);
		}
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
