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
		DateRelative.updateAll();

		$('article').each(function () {
			Nogag.initEntry($(this));
		});

		var requestFullScreen = document.body.requestFullScreen || document.body.mozRequestFullScreen || document.body.webkitRequestFullScreen;
		if (requestFullScreen) {
			this.initPhotoFullScreen();
		} else {
			$('a.picasa').each(function () {
				var src = $(this).find('img').attr('src');
				$(this).attr('href', src.replace('/s900/', '/s2048/'));
			});
		}

		if (window.devicePixelRatio > 1) {
			$(window).load(function () {
				// console.log('upgrading img');
				setTimeout(function () {
					$('a.picasa img').each(function () {
						var $this = $(this);
						var src = $this.attr('src').replace('/s900/', '/s2048/');
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


		if (Nogag.data('auth')) {
			Nogag.Editor.init();

			$('<li><a href="">新しいエントリ</a></li>').
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
				return src.replace('/s900/', '/s2048/');
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
		'javascript' : 'JavaScript',
		'html'       : 'Html',
		'css'        : 'Css'
	},
	highlight : function (container) {
		container.find('pre.code').each(function () {
			if (/lang-(\S+)/.test(this.className)) {
				var lang = Nogag.langs[RegExp.$1.toLowerCase()];
				if (!lang) return;
				var pre  = $(this);
				var code = pre.text();

				Deferred.chain(
					dependon('ace', '/js/ace/ace.js'),
					dependon('require("ace/mode/' + lang.toLowerCase() + '_highlight_rules")', '/js/ace/mode-' + lang.toLowerCase() + '.js')
				).
				next(function () {
					var Tokenizer = require("ace/tokenizer").Tokenizer;

					var rules = require("ace/mode/" + lang.toLowerCase() + "_highlight_rules")[lang + 'HighlightRules'];
					var tokenizer = new Tokenizer(new rules().getRules());

					var parent = document.createDocumentFragment();

					var state = 'start';
					var lines = code.split(/\n/);

					return Deferred.repeat(lines.length, function (i) {
						var line = document.createElement('span');
						line.className = 'line';

						var tokens = tokenizer.getLineTokens(lines[i], state);
						for (var j = 0, it; (it = tokens.tokens[j]); j++) {
							if (it.type == 'text') {
								line.appendChild(document.createTextNode(it.value));
							} else {
								var span = document.createElement('span');
								span.className = it.type;
								span.appendChild(document.createTextNode(it.value));
								line.appendChild(span);
							}
						}

						line.appendChild(document.createElement('br'));
						parent.appendChild(line);

						state = tokens.state;
					}).
					next(function () {
						pre.empty().append(parent);
					});
				}).
				error(function (e) {
					alert(e);
				});

			}
		});
	}
};
