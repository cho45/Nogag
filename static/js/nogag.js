function dependon (check, src) {
	return function () {
		var ret = Deferred();
		check = new Function('try { return !!(' + check + ') } catch (e) { return false }');
		if (check()) {
			Deferred.next(function () { ret.call() });
		} else {
			var script = document.createElement('script');
			script.charset = 'utf-8';
			script.src = src;
			document.body.appendChild(script);
			setTimeout(function () {
				if (!check()) {
					setTimeout(arguments.callee, 100);
				} else {
					ret.call();
				}
			});
		}
		return ret;
	};
}

Nogag = {
	isTouch : /Android|iPhone|iPod|DSi|iPad/.test(navigator.userAgent),

	data : function (key) {
		return document.documentElement.getAttribute('data-' + key);
	},

	init : function () {

		$('article').each(function () {
			Nogag.initEntry($(this));
		});

		/*
		if (Nogag.data('permalink')) {
			var requestFullScreen = document.body.requestFullScreen || document.body.mozRequestFullScreen || document.body.webkitRequestFullScreen;
			if (requestFullScreen) {
				this.initPhotoFullScreen();
			} else {
				$('a.picasa').each(function () {
					var src = $(this).find('img').attr('src');
					$(this).attr('href', src.replace('/s(9[06]0|1280)/', '/s2048/'));
				});
			}
		} else {
			$('article').each(function () {
				var $article = $(this);
				var permalink = $article.find('a[rel="bookmark"]').attr('href');
				$article.find('a.picasa').attr('href', permalink);
			});
		}
		*/
		$('a.picasa').each(function () {
			var src = $(this).find('img').attr('src');
			src =  src.replace(/\/s(9[06]0|1280)\//, '/s2048/');
			$(this).attr('href', src);
		});

		DateRelative.updateAll();

		if (window.devicePixelRatio > 1) {
			$(window).load(function () {
				// console.log('upgrading img');
				setTimeout(function () {
					$('a.picasa img').each(function () {
						var $this = $(this);
						var src = $this.attr('src').replace(/\/s(9[06]0|1280)\//, '/s2048/');
						console.log(src);
						var img = new Image();
						img.src = src;
						// console.log('loading ' + src);
						img.onload = function () {
							$this.attr('src', src);
							// console.log('upgraded');
						};
					});
				}, 500);
			});
		}
		
		$('a.picasa img').each(function () {
			var $this = $(this);
			var src = $this.attr('src').replace(/\/s900\//, '/s960/');
			console.log(src);
			var img = new Image();
			img.src = src;
			// console.log('loading ' + src);
			img.onload = function () {
				$this.attr('src', src);
				// console.log('upgraded');
			};
		});

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

	initPhotoFullScreen : function () {
		var foo = $('a.picasa').colorbox({
			fixed       : true,
			rel         : 'picasa',
			photo       : true,
			returnFocus : false,
			loop        : false,
			width       : window.screen.width,
			height      : window.screen.height,
			title       : function () {
				// return '<a href="' + $(this).attr('href') + '" target="_blank" class="symbol">D</a>';
				return '';
			},
			onOpen : function () {
				var target = document.getElementById('colorbox');
				if (target.requestFullScreen) {
					target.requestFullScreen();
				} else
				if (target.mozRequestFullScreen) {
					target.mozRequestFullScreen();
				} else
				if (target.webkitRequestFullScreen) {
					target.webkitRequestFullScreen();
				}

				document.addEventListener("fullscreenchange", function () {
					if (document.fullscreenElement || document.fullScreenElement) {
						$.colorbox.resize();
					} else {
						document.removeEventListener("fullscreenchange", arguments.callee);
						$.colorbox.close();
					}
				}, false);
				document.addEventListener("mozfullscreenchange", function () {
					if (document.mozFullScreenElement || document.mozFullscreenElement) {
						$.colorbox.resize();
					} else {
						document.removeEventListener("mozfullscreenchange", arguments.callee);
						$.colorbox.close();
					}
				}, false);
				document.addEventListener("webkitfullscreenchange", function () {
					if (document.webkitFullscreenElement || document.webkitFullScreenElement) {
						$.colorbox.resize();
					} else {
						document.removeEventListener("webkitfullscreenchange", arguments.callee);
						$.colorbox.close();
					}
				}, false);
			},
			onComplete : function () {
				$.colorbox.resize();
			},
			onClosed : function () {
				if (document.exitFullscreen) {
					document.exitFullscreen();
				} else
				if (document.cancelFullScreen) {
					document.cancelFullScreen();
				} else
				if (document.mozCancelFullScreen) {
					document.mozCancelFullScreen();
				} else
				if (document.webkitCancelFullScreen) {
					document.webkitCancelFullScreen();
				}
			},
			href        : function () {
				// 'http://lh3.ggpht.com/-2HEEdNCVIRQ/Tt-ewB6vY8I/AAAAAAAABbs/eyTknRFTB-k/s900/IMG_9578-1920.jpg'
				var src = $(this).find('img').attr('src');
				return src.replace('/s(9[06]0|1280)/', '/s2048/');
			}
		});
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
//				var lang = Nogag.langs[RegExp.$1.toLowerCase()];
//				if (!lang) return;
//				var pre  = $(this);
//				var code = pre.text();
//
//				Deferred.chain(
//					dependon('ace', '/js/ace/ace.js'),
//					dependon('require("ace/mode/' + lang.toLowerCase() + '_highlight_rules")', '/js/ace/mode-' + lang.toLowerCase() + '.js')
//				).
//				next(function () {
//					var Tokenizer = require("ace/tokenizer").Tokenizer;
//
//					var rules = require("ace/mode/" + lang.toLowerCase() + "_highlight_rules")[lang + 'HighlightRules'];
//					var tokenizer = new Tokenizer(new rules().getRules());
//
//					var parent = document.createDocumentFragment();
//
//					var state = 'start';
//					var lines = code.split(/\n/);
//
//					return Deferred.repeat(lines.length, function (i) {
//						var line = document.createElement('span');
//						line.className = 'line';
//
//						var tokens = tokenizer.getLineTokens(lines[i], state);
//						for (var j = 0, it; (it = tokens.tokens[j]); j++) {
//							if (it.type == 'text') {
//								line.appendChild(document.createTextNode(it.value));
//							} else {
//								var span = document.createElement('span');
//								span.className = it.type;
//								span.appendChild(document.createTextNode(it.value));
//								line.appendChild(span);
//							}
//						}
//
//						line.appendChild(document.createElement('br'));
//						parent.appendChild(line);
//
//						state = tokens.state;
//					}).
//					next(function () {
//						pre.empty().append(parent);
//					});
//				}).
//				error(function (e) {
//					alert(e);
//				});
			}
		});
	}
};
