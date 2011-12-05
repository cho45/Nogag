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
			$('<li><a href="">新しいエントリ</a></li>').
				click(function () {
					Nogag.newEntry();
					return false;
				}).
				prependTo('#global-navigation ul');
		}
	},

	initEntry : function (entry) {
		if (Nogag.data('auth')) {
			$('<a href="">編集</a>').
				click(function () {
					Nogag.editEntry(entry);
					return false;
				}).
				appendTo(entry.find('.metadata'));
		}

		Nogag.highlight(entry);
	},

	editEntry : function (article) {
		var id = article ? article.attr('data-id') : '';

		$.ajax({
			url : '/api/edit',
			type : "get",
			dataType : 'json',
			data : {
				id : id,
				location : location.href
			},
			success : function (res) {
				var container = $(res.html);
				if (article) {
					article.replaceWith(container);
				} else {
					container.prependTo('#content .entries');
				}
				Nogag.initEditForm(container, article);
			}
		});
	},

	newEntry : function () {
		Nogag.editEntry();
	},

	initEditForm : function (container, article) {
		var form  = container.find('form');
		var title = container.find('input[name=title]');
		var body  = container.find('textarea[name=body]');

		var actions = {
			kousei : function () {
				$.ajax({
					url: "/api/kousei",
					type : "GET",
					data : {
						sentence : body.val()
					},
					dataType: 'json',
					success : function (data, status, xhr) {
						container.find('button[data-action=kousei]').text('校正 (指摘' + data.result.length + ')');

						for (var i = 0, it; (it = data.result[i]); i++) {
							console.log([it.info, it.surface, it.word].join(' '));
						}
					}
				});
			}
		};

		container.find('.toolbar').delegate('button', 'click', function (e) {
			e.preventDefault();
			e.stopPropagation();
			var action = $(this).attr('data-action');
			actions[action]();
		});

		body.keypress(function (e) {
			var key = keyString(e);
			if (key == 'RET') actions.kousei();
		});

		if (article) {
			form.submit(function () {
				$.ajax({
					url: form.attr('action'),
					type : "POST",
					data : form.serializeArray(),
					success : function (data, status, xhr) {
						var newElement = $(data).find('article[data-id=' + article.attr('data-id') + ']');
						container.replaceWith(newElement);
						Nogag.initEntry(newElement);
					}
				});
				return false;
			});
		}

		body.focus();
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
