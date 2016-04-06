Nogag = {
	data : function (key) {
		return document.documentElement.getAttribute('data-' + key);
	},

	init : function () {

		var articles = document.querySelectorAll('article');
		for (var i = 0, it; (it = articles[i]); i++) {
			Nogag.initEntry($(it));
		}

		$('a.picasa').each(function () {
			var img = $(this).find('img');
			var src = img.attr('src');
			var link = src.replace(/\/s(9[06]0|1280)\//, '/s2048/');
			$(this).attr('href', link);
			if (window.devicePixelRatio > 1) {
				src = src.replace(/\/s(9[06]0|1280)\//, '/s2048/');
			} else {
				src = src.attr('src').replace(/\/s900\//, '/s960/');
			}
			var loader = new Image();
			loader.src = src;
			console.log('loading ' + src);
			loader.onload = function () {
				img.attr('src', src);
				console.log('upgraded');
			};
		});

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

			$('<li><a href="">New Entry</a></li>').
				click(function () {
					Nogag.Editor.newEntry();
					return false;
				}).
				appendTo('#global-navigation ul');
		}
	},

	initEntry : function (entry) {
		if (Nogag.data('auth')) {
			$('<a href="">編集</a>').
				click(function () {
					Nogag.Editor.editEntry(entry);
					return false;
				}).
				appendTo(entry.find('.metadata'));
		}

		Nogag.highlight(entry);
	},

	langs : {
		'perl'       : 'Perl',
		'ruby'       : 'Ruby',
		'javascript' : 'JavaScript',
		'html'       : 'Html',
		'css'        : 'Css'
	},
	highlight : function (container) {
		container.find('pre.code').each(function () {
			if (/lang-(\S+)/.test(this.className)) {
				hljs.highlightBlock(this);
			}
		});
	}
};
