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
	data : function (key) {
		return document.documentElement.getAttribute('data-' + key);
	},

	init : function () {
		DateRelative.updateAll();

		$('article').each(function () {
			Nogag.initEntry($(this));
		});

		if (Nogag.data('auth')) {
			Nogag.Editor.init();

			$('<li><a href="">新しいエントリ</a></li>').
				click(function () {
					Nogag.Editor.newEntry();
					return false;
				}).
				prependTo('#global-navigation ul');
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
