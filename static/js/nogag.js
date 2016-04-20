Nogag = {
	data : function (key) {
		return document.documentElement.getAttribute('data-' + key);
	},

	init : function () {

		var articles = document.querySelectorAll('article');
		for (var i = 0, it; (it = articles[i]); i++) {
			Nogag.initEntry(it);
		}

		var photos = document.querySelectorAll('a.picasa');
		for (var i = 0, it; (it = photos[i]); i++) (function (anchor) {
			var img = anchor.querySelector('img');
			var src = img.getAttribute('src');

			var link = src.replace(/\/s(9[06]0|1280)\//, '/s2048/');
			if (window.devicePixelRatio > 1) {
				src = src.replace(/\/s(9[06]0|1280)\//, '/s2048/');
			} else {
				src = src.replace(/\/s900\//, '/s960/');
			}

			anchor.href = link;

			if (src !== img.getAttribute('src')) {
				var loader = new Image();
				loader.src = src;
				console.log('upgrade loading ' + src);
				loader.onload = function () {
					img.src = src;
					console.log('upgraded');
				};
			}
		})(it);

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

		if (Nogag.data('auth')) {
			Nogag.Editor.init();

			var button = document.querySelector('.nogag-new');
			if (button) {
				button.addEventListener('click', function () {
					Nogag.Editor.newEntry();
				});
			}
		}
	},

	initEntry : function (entry) {
		if (Nogag.data('auth')) {
			var button = entry.querySelector('.nogag-edit');
			if (button) {
				button.addEventListener('click', function () {
					Nogag.Editor.editEntry(entry);
				});
			}
		}
	}
};

document.addEventListener('DOMContentLoaded', function () {
	Nogag.init();
}, false);
