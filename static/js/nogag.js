
Nogag = {
	data : function (key) {
		return document.documentElement.getAttribute('data-' + key);
	},

	init : function () {
		DateRelative.updateAll();

		$('article.hentry').each(function () {
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
					container.prependTo('#content .hfeed');
				}
				Nogag.initEditForm(container, article);
			}
		});
	},

	newEntry : function () {
		this.editEntry();
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
	}
};
