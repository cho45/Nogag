
Nogag = {
	data : function (key) {
		return document.documentElement.getAttribute('data-' + key);
	},

	init : function () {
		DateRelative.updateAll();

		if (Nogag.data('auth')) {
			$('<li><a href="">新しいエントリ</a></li>').
				click(function () {
					Nogag.newEntry();
					return false;
				}).
				prependTo('#global-navigation ul');

			$('article.hentry').each(function () {
				var $this = $(this);
				$('<a href="">編集</a>').
					click(function () {
						Nogag.editEntry($this);
						return false;
					}).
					appendTo($this.find('.metadata'));
			});
		}
	},

	editEntry : function (article) {
		var self = this;
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
				self.initEditForm(container);
			}
		});
	},

	newEntry : function () {
		this.editEntry();
	},

	initEditForm : function (container) {
		var self = this;

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

		body.focus();
	}
};
