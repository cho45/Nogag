
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
		var id = article ? article.attr('data-id') : 'new';

		$.ajax({
			url : '/api/edit',
			type : "get",
			dataType : 'json',
			data : {
				id : id
			},
			success : function (res) {
				$(res.html).prependTo('#content .hfeed');
			}
		});
	},

	newEntry : function () {
		this.editEntry();
	}
};
