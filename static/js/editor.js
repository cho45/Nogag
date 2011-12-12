Deferred.define();

Nogag.Editor = {
	init : function () {
		if (document.getElementById('test')) this.test();
	},

	test : function () {
		var parent  = $('#images');
		var list    = $('#images-items');
		var preview = $('#images-preview');
		var actions = $('#images-actions');

		var template = list.find('.item');

		preview.click(function () {
			preview.hide();
		});

		var page = 1;
		var limit = 24;
		actions.
			find('.left').
				click(function () {
					if (preview.is(':visible')) {
						Nogag.Editor.Picasa.get(+preview.attr('data-index') - 1).next(showPreview).error(function (e) {
							alert(e);
						});
					} else {
						if (page > 1) loadPage(--page);
					}
				}).
			end().
			find('.right').
				click(function () {
					if (preview.is(':visible')) {
						Nogag.Editor.Picasa.get(+preview.attr('data-index') + 1).next(showPreview).error(function (e) {
							alert(e);
						});
					} else {
						loadPage(++page);
					}
				}).
			end();
		loadPage(page);

		function loadPage (page) {
			actions.find('.page').text('Load: ' + page);
			list.empty();
			return loop(limit, function (n) {
				var index = (page - 1) * limit + n;
				return Nogag.Editor.Picasa.get(index).next(function (it) {
					if (!it) return;
					var thumbnail = it.media$group.media$thumbnail[0].url;

					var link = $.grep(it.link, function (_) { return _.rel == 'alternate' && _.type == 'text/html'; })[0].href;

					var item = template.clone();
					item.
						find('img.thumbnail').
							attr({
								alt : it.title.$t,
								src : thumbnail
							}).
							click(function () {
								showPreview(it);
							}).
						end().
						find('a.link').
							attr({
								title : it.title.$t,
								href  : link
							}).
						end().
						appendTo(list);
				});
			}).
			next(function () {
				actions.find('.page').text('Page: ' + page);
			}).
			error(function (e) {
				alert(e);
			});
		}

		function showPreview (it) {
			var image     = it.content.src;
			preview.attr('data-index', it.index);
			preview.find('img').attr('src', image).end().show();
			var itpage = Math.ceil( (it.index + 1) / 24);
			if (itpage != page) {
				page = itpage;
				loadPage(itpage);
			}
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
					container.prependTo('#content .entries');
				}
				Nogag.Editor.initEditForm(container, article);
			}
		});
	},

	newEntry : function () {
		Nogag.Editor.editEntry();
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

Nogag.Editor.Picasa = {
	get : function (n, end) {
		var self = this;
		if (end) {
			if (self._done || n < self._data.length) {
				return next(function () { return self._data.slice(n, end) });
			} else {
				return self._loadNext(end - n + 1).next(function () {
					return self._data.slice(n, end);
				});
			}
		} else {
			if (self._done || n < self._data.length) {
				return next(function () { return self._data[n] });
			} else {
				return self._loadNext().next(function () {
					return self._data[n];
				});
			}
		}
	},

	_done : false,
	_data : [],
	_loadNext : function (num) {
		var self = this;

		var ret = new Deferred();
		$.ajax({
			url : 'http://picasaweb.google.com/data/feed/base/user/cho101101?alt=json&kind=photo&hl=ja&callback=?',
			dataType: 'jsonp',
			data : {
				'fields'      : 'entry(title,link,content,media:group)',
				'start-index' : self._data.length + 1,
				'max-results' : num || 24,
				'imgmax'      : '900',
				'thumbsize'   : '144c'
			},
			success : function (res) {
				if (!res.feed.entry.length) self._done = true;
				var i = self._data.length;
				self._data = self._data.concat(res.feed.entry);
				for (var it; (it = self._data[i]); i++) {
					it.index = i;
				}
				ret.call();
			},
			error : function (e) {
				ret.fail(e);
			}
		});
		return ret;
	}
};
