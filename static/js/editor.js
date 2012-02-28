Deferred.define();

Nogag.Editor = {
	init : function () {
		if (document.getElementById('test')) this.test();
	},

	test : function () {
		Nogag.Editor.Picasa.get().next(function (syntax) {
			alert(syntax);
		}).
		error(function (e) {
			alert(e);
		});
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
			photo : function () {
				Nogag.Editor.Picasa.get().next(function (syntax) {
					body.val( body.val() + "\n" + syntax);
					title.val('[photo]');
				}).
				error(function (e) {
					alert(e);
				});
			},

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
	page : 1,
	limit : 24,
	init : function () {
		var self = this;
		if (self.parent) return;
		self.parent  = $('#images');
		self.list    = $('#images-items');
		self.preview = $('#images-preview');
		self.actions = $('#images-actions');
		self.template = self.list.find('.item');

		self.preview.click(function () {
			self.preview.hide();
		});

		self.actions.
			find('.paste').
				click(function () {
					if (self.preview.is(':visible')) {
						Nogag.Editor.Picasa.Items.get(+self.preview.attr('data-index')).
						next(function (it) {
							self.preview.hide();
							self.parent.hide();
							$.colorbox.close();
							self.deferred.call(it.syntax);
						}).
						error(function (e) {
							self.deferred.fail(e);
						});
					}
				}).
			end().
			find('.left').
				click(function () {
					if (self.preview.is(':visible')) {
						Nogag.Editor.Picasa.Items.get(+self.preview.attr('data-index') - 1).
						next(function (it) {
							self.showPreview(it);
						}).
						error(function (e) {
							self.deferred.fail(e);
						});
					} else {
						if (self.page > 1) self.loadPage(--self.page);
					}
				}).
			end().
			find('.right').
				click(function () {
					if (self.preview.is(':visible')) {
						Nogag.Editor.Picasa.Items.get(+self.preview.attr('data-index') + 1).
						next(function (it) {
							self.showPreview(it);
						}).
						error(function (e) {
							self.deferred.fail(e);
						});
					} else {
						self.loadPage(++self.page);
					}
				}).
			end();

		self.loadPage(self.page);
	},

	get : function () {
		var self = this;
		self.init();

		self.deferred = new Deferred();
		$.colorbox({
			inline: true,
			href : self.parent.show()
		});
		return self.deferred;
	},

	showPreview : function (it) {
		var self = this;
		var image     = it.content.src;
		self.preview.attr('data-index', it.index);
		self.preview.find('img').attr('src', image).end().show();
		var page = Math.ceil( (it.index + 1) / 24);
		if (page != self.page) {
			self.page = page;
			self.loadPage(self.page);
		}
	},

	loadPage : function (page) {
		var self = this;
		self.actions.find('.page').text('Load: ' + self.page);
		self.list.empty();
		return loop(self.limit, function (n) {
			var index = (self.page - 1) * self.limit + n;
			return Nogag.Editor.Picasa.Items.get(index).next(function (it) {
				if (!it) return;

				var item = self.template.clone();
				item.
					find('img.thumbnail').
						attr({
							alt : it.title,
							src : it.thumbnail
						}).
						click(function () {
							self.showPreview(it);
						}).
					end().
					find('a.link').
						attr({
							title : it.title,
							href  : it.link
						}).
					end().
					appendTo(self.list);
			});
		}).
		next(function () {
			self.actions.find('.page').text('Page: ' + self.page);
		}).
		error(function (e) {
			alert(e);
		});
	}
};

Nogag.Editor.Picasa.Items = {
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
			url : 'http://picasaweb.google.com/data/feed/base/user/cho101101?alt=json&kind=photo&hl=ja&access=public&callback=?',
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
					it.index     = i;
					it.title     = it.title.$t;
					it.thumbnail = it.media$group.media$thumbnail[0].url;
					it.link      = $.grep(it.link, function (_) { return _.rel == 'http://schemas.google.com/photos/2007#canonical' && _.type == 'text/html'; })[0].href;
					it.image     = it.content.src;
					it.syntax    = $('#images-template').text().replace(/\{\{(\w+)\}\}/g, function (_, name) { return it[name] }).replace(/\s+/g, ' ');
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
