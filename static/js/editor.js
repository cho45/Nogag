Nogag.Backup = {
	init : function (parent) {
		var forms = parent.querySelectorAll('form[data-backup-key]');
		for (var i = 0, form; (form = forms[i]); i++) {
			this.setup(form);
		}
	},

	setup : function (form) {
		var key = form.getAttribute('data-backup-key');
		var backup = localStorage.getItem('backup-' + key);
		try {
			backup = JSON.parse(backup);
		} catch (e) {
			console.log(e);
			backup = null;
		}

		var backupTime = new Date(+localStorage.getItem('backupTime-' + key));
		var button = form.querySelector('button[data-action="restore-backup"]');
		console.log(backup);

		if (backup) {
			button.appendChild(document.createTextNode(' (' + backupTime + ')'));
			button.addEventListener('click', function (e) {
				form['title'].value = backup.title;
				form['body'].value = backup.body;
				button.style.display = 'none';
			}, false);
		} else {
			button.style.display = 'none';
		}

		setInterval(() => {
			this.save(form);
		}, 3000);
	},

	save : function (form) {
		var backup = {
			title : form['title'].value,
			body : form['body'].value
		};
		var backupTime = new Date().getTime();

		var key = form.getAttribute('data-backup-key');
		localStorage.setItem('backup-' + key, JSON.stringify(backup));
		localStorage.setItem('backupTime-' + key, backupTime);
		// console.log('save backup: ' + key);
	},

	clear : function (form) {
		var key = form.getAttribute('data-backup-key');
		localStorage.removeItem('backup-' + key);
		localStorage.removeItem('backupTime-' + key);
		console.log('clear backup: ' + key);
	}
};

Nogag.Editor = {
	google_client_id :  '980119139173.apps.googleusercontent.com',
	google_developer_key : 'AIzaSyCDevJrf8SOEfeSeYDOGT9e6jjGDNT6lM4',

	init : function () {
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

	openPicker : function (callback) {
		return Nogag.Editor.oauthGoogle().
		then(() => {
			console.log('google_access_token', Nogag.Editor.google_access_token);
			var picker = new google.picker.PickerBuilder().
				setOAuthToken(Nogag.Editor.google_access_token).
				// setOrigin(window.location.protocol + '//' + window.location.host).
				setDeveloperKey(Nogag.Editor.google_developer_key).
				addView(google.picker.ViewId.PHOTOS).
				addView(new google.picker.PhotosView().setType('camerasync')).
				addView(google.picker.ViewId.PHOTO_UPLOAD).
				addView(google.picker.ViewId.YOUTUBE).
				// addView(google.picker.ViewId.MAPS).
				setCallback(function (data) {
					console.log('openPicker', data);
					callback(data);
				}).
				build();

			picker.setVisible(true);
		});
	},

	editEntry : function (article) {
		var id = article ? article.getAttribute('data-id') : '';

		var req = new XMLHttpRequest();
		req.open("GET", '/api/edit?id=' + id + '&location=' + location.href , true);
		req.responseType = 'json';
		req.onload = function () {
			var data = req.response;
			var fragment = document.createRange().createContextualFragment(data.html);
			var container = fragment.querySelector('article');
			Nogag.Editor.initEditForm(container, article);
		};
		req.onerror = function (e) {
			alert(e);
		};
		req.send(null);
	},

	newEntry : function () {
		Nogag.Editor.editEntry();
	},

	initEditForm : function (container, article) {
		if (article) {
			article.parentNode.replaceChild(container, article);
		} else {
			var entries = document.querySelector('#content .entries');
			entries.insertBefore(container, entries.firstChild);
		}

		var form  = container.querySelector('form');
		var body  = form['body'];
		body.insertText = function (text, select) {
			var selectionStart = body.selectionStart;
			var selectionEnd = body.selectionEnd;
			body.value =
				body.value.substring(0, selectionStart) +
				text +
				body.value.substring(selectionEnd);
			body.selectionStart = selectionStart;
			if (typeof select === 'boolean' && select) {
				body.selectionEnd   = selectionStart + text.length;
			} else
			if (typeof select === 'number') {
				body.selectionStart = selectionStart + select;
				body.selectionEnd   = selectionStart + select;
			} else {
				body.selectionEnd   = selectionStart;
			}
		};

		var actions = {
			photo : function () {
				Nogag.Editor.openPicker( (data) => {
					console.log('data', data);
					if (data[google.picker.Response.ACTION] !== google.picker.Action.PICKED) return;

					var syntax;

					console.log(data);
					var doc = data[google.picker.Response.DOCUMENTS][0];
					if (doc.type === 'photo') {
						var it = {
							url : doc.url,
							image : doc.thumbnails[3].url.replace(/\/s\d+\//, '/s2048/')
						};
						var template = document.getElementById('images-template').innerText;
						syntax    = template.replace(/\{\{(\w+)\}\}/g, function (_, name) { return it[name] }).replace(/\s+/g, ' ');
					} else
					if (doc.type === 'location') {
						console.log(doc.thumbnails[3]);
						syntax = '<img src+"' + doc.thumbnails[3].url + '" alt="[MAP]"/>';
					}

					if (syntax) {
						body.insertText(syntax, true);
					}
				});
			},

			kousei : function () {
//				$.ajax({
//					url: "/api/kousei",
//					type : "GET",
//					data : {
//						sentence : body.val()
//					},
//					dataType: 'json',
//					success : function (data, status, xhr) {
//						container.find('button[data-action=kousei]').text('校正 (指摘' + data.result.length + ')');
//
//						for (var i = 0, it; (it = data.result[i]); i++) {
//							console.log([it.info, it.surface, it.word].join(' '));
//						}
//					}
//				});
			}
		};

		var buttons = container.querySelectorAll('.toolbar button');
		for (var i = 0, it; (it = buttons[i]); i++) {
			it.addEventListener('click', function (e) {
				e.preventDefault();
				e.stopPropagation();
				var action = e.target.getAttribute('data-action');
				if (actions[action]) actions[action]();
			});
		}

		body.addEventListener('keydown', function (e) {
			var key = (e.altKey?"Alt-":"")+(e.ctrlKey?"Control-":"")+(e.metaKey?"Meta-":"")+(e.shiftKey?"Shift-":"")+e.key;   
			console.log(key);
			if (key === 'Control-t') {
				body.insertText('\\(  \\)', 3); 
				e.preventDefault();
				e.stopPropagation();
			}
		});

		if (article) {
			form.addEventListener('submit', function (e) {
				e.preventDefault();
				e.stopPropagation();
				var req = new XMLHttpRequest();
				req.open("POST", form.action, true);
				req.onload = function (e) {
					var fragment = document.createRange().createContextualFragment(req.responseText);

					var newElement = fragment.querySelector('article[data-id="' + article.getAttribute('data-id') + '"]');
					container.parentNode.replaceChild(newElement, container);
					Nogag.initEntry(newElement);
					Nogag.Backup.clear(form);
					// MathJax.Hub.Typeset(newElement[0]);
				};
				req.onerror = function (e) {
				};
				req.send(new FormData(form));
			});
		}

		Nogag.Backup.init(container);

		body.focus();
	}
};
window['Nogag.Editor.initGoogleAPI'] = Nogag.Editor.initGoogleAPI;

