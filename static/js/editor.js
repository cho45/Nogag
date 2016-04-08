Nogag.Backup = {
	init : function (parent) {
		var self = this;
		var forms = parent.find('form[data-backup-key]');

		forms.each(function () {
			var $form = $(this);
			self.load($form);

			setInterval(function () {
				self.save($form);
			}, 3000);
		});
	},

	load : function (form) {
		var key = form.attr('data-backup-key');
		var backup = localStorage.getItem('backup-' + key);
		var backupTime = new Date(+localStorage.getItem('backupTime-' + key));

		if (backup) {
			var confirm = $('<p><a href="">restore backup</a> <span class="datetime"></span></p>');
			confirm.find('a').click(function () {
				form.deserialize(backup);
				confirm.remove();
				return false;
			});
			confirm.find('.datetime').text(backupTime);
			form.append(confirm);
		}
		console.log('load backup: ' + key);
	},

	save : function (form) {
		var backup = form.serialize();
		var backupTime = new Date().getTime();

		var key = form.attr('data-backup-key');
		localStorage.setItem('backup-' + key, backup);
		localStorage.setItem('backupTime-' + key, backupTime);
		// console.log('save backup: ' + key);
	},

	clear : function (form) {
		var key = form.attr('data-backup-key');
		localStorage.removeItem('backup-' + key);
		localStorage.removeItem('backupTime-' + key);
		console.log('clear backup: ' + key);
	}
};

Nogag.Editor = {
	google_client_id :  '980119139173.apps.googleusercontent.com',
	google_developer_key : 'AIzaSyCDevJrf8SOEfeSeYDOGT9e6jjGDNT6lM4',

	init : function () {
		if (document.getElementById('test')) this.test();
	},

	initGoogleAPI : function () {
		console.log('initGoogleAPI');
		Nogag.Editor.loadGoogle('auth');
		Nogag.Editor.loadGoogle('picker');
	},

	loadGoogle : function (name) {
		return new Promise( (resolve, reject) => {
			gapi.load(name, {'callback': resolve } );
		});
	},

	oauthGoogle : function () {
		if (!Nogag.Editor.google_access_token) {
			return new Promise( (resolve, reject) => {
				gapi.auth.authorize(
					{
						'client_id': Nogag.Editor.google_client_id,
						'scope': [
							'https://www.googleapis.com/auth/photos',
							'https://www.googleapis.com/auth/drive.readonly',
							'https://www.googleapis.com/auth/photos.upload',
							'https://www.googleapis.com/auth/youtube'
						],
						'immediate': false
					},
					function (result) {
						console.log(result);
						if (result && !result.error) {
							Nogag.Editor.google_access_token = result.access_token;
							resolve(result);
						} else {
							alert(result.error);
							reject(result);
						}
					}
				);
			});
		} else {
			return Promise.resolve();
		}
	},

	openPicker : function () {
		return Nogag.Editor.oauthGoogle().
		then(() => {
			return new Promise( (resolve, reject) => {
				var picker = new google.picker.PickerBuilder().
					setOAuthToken(Nogag.Editor.google_access_token).
					setDeveloperKey(Nogag.Editor.google_developer_key).
					addView(google.picker.ViewId.PHOTOS).
					addView(new google.picker.PhotosView().setType('camerasync')).
					addView(google.picker.ViewId.PHOTO_UPLOAD).
					addView(google.picker.ViewId.YOUTUBE).
					addView(google.picker.ViewId.MAPS).
					setCallback(function (data) {
						resolve(data);
					}).
					build();

				picker.setVisible(true);
			});
		}).
		catch((e) => {
			alert(e);
		});
	},

	editEntry : function (article) {
		if (article) {
			article = $(article);
		}
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
		// var title = container.find('input[name=title]');
		var body  = container.find('textarea[name=body]');

		var actions = {
			photo : function () {
				Nogag.Editor.openPicker().then( (data) => {
					if (data[google.picker.Response.ACTION] !== google.picker.Action.PICKED) return;

					var syntax;

					console.log(data);
					var doc = data[google.picker.Response.DOCUMENTS][0];
					if (doc.type === 'photo') {
						var it = {
							url : doc.url,
							image : doc.thumbnails[3].url.replace(/\/s\d+\//, '/s2048/')
						};
						syntax    = $('#images-template').text().replace(/\{\{(\w+)\}\}/g, function (_, name) { return it[name] }).replace(/\s+/g, ' ');
					} else
					if (doc.type === 'location') {
						console.log(doc.thumbnails[3]);
						syntax = '<img src+"' + doc.thumbnails[3].url + '" alt="[MAP]"/>';
					}

					if (syntax) {
						body.val( body.val() + "\n" + syntax);
					}
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
			if (key === 'RET') actions.kousei();
		});

		if (article) {
			form.submit(function () {
				$.ajax({
					url: form.attr('action'),
					type : "POST",
					cache: false,
					data : form.serializeArray(),
					success : function (data, status, xhr) {
						var newElement = $(data).find('article[data-id=' + article.attr('data-id') + ']');
						container.replaceWith(newElement);
						Nogag.initEntry(newElement[0]);
						Nogag.Backup.clear(form);
						MathJax.Hub.Typeset(newElement[0]);
					}
				});
				return false;
			});
		}

		Nogag.Backup.init(container);

		body.focus();
	}
};
window['Nogag.Editor.initGoogleAPI'] = Nogag.Editor.initGoogleAPI;

