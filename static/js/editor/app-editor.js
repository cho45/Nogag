Polymer({
	is: "app-editor",
	properties: {
		saving : {
			type: Boolean,
			value: false
		},

		entryJson : {
			type: String,
			value: ''
		},

		sk : {
			type: String,
			value: ''
		},

		progress : {
			type: String,
			value: ''
		},

		// DB 側の値
		entry : {
			type: Object,
			value: {
				id: null,
				title: '',
				body: '',
				status: null
			}
		},

		// 編集中の値
		form : {
			type: Object,
			value: {
				id: null,
				title: '',
				body: '',
				publishLater: false
			}
		},

		backup : {
			type: Object,
			value: {
				new: {}
			}
		},
		existingBackup : {
			type: Object,
			value: {}
		}
		
	},

	created: function () {
		this.google_client_id =  '980119139173.apps.googleusercontent.com';
		this.google_developer_key = 'AIzaSyCDevJrf8SOEfeSeYDOGT9e6jjGDNT6lM4';
		this.googleAPI = null;


		var loadScript = function (url) {
			return new Promise( function (resolve, reject) {
				var script = document.createElement('script');
				script.onload = resolve;
				script.onerror = reject;
				script.src = url;
				document.body.appendChild(script);
			});
		};

		var initGoogleAPI = new Promise( (resolve, reject) => {
			window['Nogag.Editor.initGoogleAPI'] = () => {
				delete window['Nogag.Editor.initGoogleAPI'];
				resolve();
			};
			loadScript('https://apis.google.com/js/api.js?onload=Nogag.Editor.initGoogleAPI').
				catch(reject);
		});

		var loadGoogle = function (name) {
			return new Promise( (resolve, reject) => {
				gapi.load(name, {'callback': resolve } );
			});
		};

		this.googleAPI = initGoogleAPI.
			then( () => {
				console.log('Google API Loaded');
			}).
			then( () => Promise.all([
				loadGoogle('auth'),
				loadGoogle('picker')
			])).
			then( () => {
				console.log('Google API Loaded / auth, picker');
			}).
			catch( (e) => alert(e) );
	},

	ready : function () {
		if (location.hash.match(/#openDialog-(.+)/)) {
			this.openDialog(this.$[RegExp.$1]);
		}

		this.entry = JSON.parse(this.entryJson);
		console.log(this.entry);

		this.set('form.id', this.entry.id);
		this.set('form.title', this.entry.title);
		this.set('form.body', this.entry.body);
		this.set('form.publishLater', this.entry.status === "scheduled");

		this.$.body.insertText = function (text, select) {
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

		this.$.body.addEventListener('keydown', function (e) {
			var key = (e.altKey?"Alt-":"")+(e.ctrlKey?"Control-":"")+(e.metaKey?"Meta-":"")+(e.shiftKey?"Shift-":"")+e.key;   
			console.log(key);
			if (key === 'Control-t') {
				body.insertText('\\(  \\)', 3); 
				e.preventDefault();
				e.stopPropagation();
			}
		});
	},

	attached: function () {
		this.$.backup.reload();

		var key = this.backupKeyForEntry(this.entry);
		var existingBackup = this.backup[key];
		// DBとバックアップが違う場合だけバックアップが存在することにする
		if (
			existingBackup &&
			(
				this.entry.title !== existingBackup.title ||
				this.entry.body  !== existingBackup.body
			)
		) {
			this.set('existingBackup', existingBackup);
		} else {
			// 保存時に消しているはずだが念のため
			delete this.backup[key];
			this.set('existingBackup', null);
		}

		setInterval( () => {
			// DBから変更がある場合はバックアップをとる
			if (
				this.entry.title !== this.form.title ||
				this.entry.body  !== this.form.body
			) {
				console.log('update backup');
				// update 
				this.backup[key] = {
					title : this.form.title,
					body  : this.form.body,
					time  : new Date().getTime()
				};
				this.$.backup.save();
				// 変更されたら復元可能状態から抜ける (復元ボタンを消す)
				this.set('existingBackup', null);
			}
		}, 3000);
	},

	saveEntry : function () {
		this.set('saving', true);
		this.set('progress', '');

		var data = new FormData();
		data.set('id', this.form.id);
		data.set('title', this.form.title);
		data.set('body', this.form.body);
		data.set('sk', this.sk);
		data.set('post_buffer', this.$.postBuffer.checked ? "1" : "");
		if (this.$.publishLater.checked) {
			var epoch = 
				this.entry.publish_at ||
				((Date.now() / 1000) + (60 * 60 * 24 * 30));

			data.set('publish_at',  epoch);
			data.set('status', 'scheduled');
		} else {
			data.set('status', 'public');
		}

		var req = new XMLHttpRequest();
		req.open("POST", '/api/edit');
		req.onload = (e) => {
			// 保存したらバックアップは削除
			var key = this.backupKeyForEntry(this.entry);
			delete this.backup[key];
			this.$.backup.save();

			var data = JSON.parse(req.responseText);
			location.href = data.location;
		};
		req.onerror = (e) => {
			this.set('saving', false);
			if (confirm('error ' + e + "\nRetry?")) {
				this.saveEntry();
			}
		};
		req.send(data);

		var self = this;
		(function progress () {
			var req = new XMLHttpRequest();
			req.open("GET", '/api/edit/progress');
			var timeout = setTimeout(function () {
				if (req.readyState !== 4) {
					req.abort();
					progress();
				}
			}, 5000);
			req.onload = (e) => {
				clearTimeout(timeout);

				var data = JSON.parse(req.responseText);

				self.set('progress', data.progress);
				setTimeout(() => {
					progress();
				}, 500);
			};
			req.onerror = (e) => {
				progress();
			};
			req.send(null);
		}).call(this);
	},

	initializeBackup : function () {
		this.backup = {};
	},

	backupKeyForEntry : function (entry) {
		return entry.id || 'new';
	},

	restoreBackup : function () {
		this.set('form.title', this.existingBackup.title);
		this.set('form.body', this.existingBackup.body);
	},

	openRestoreDialog : function () {
		this.openDialog(this.$.restoreDialog);
	},

	openTagDialog : function () {
		this.openDialog(this.$.tagDialog);
	},

	insertTag : function (e) {
		var tag = this.getDataArgFromEvent(e, 'data-tag');
		this.set('form.title',  '[' + tag + ']' + this.form.title);
		this.$.tagDialog.close();
		this.async( () => {
			this.$.title.focus();
		});
	},

	getDataArgFromEvent : function (e, name) {
		var target = Polymer.dom(e).path.filter(function (i) {
			return i.getAttribute && i.getAttribute(name);
		})[0];
		if (!target) {
			return null;
		}
		return target.getAttribute(name);
	},

	openDialog : function (dialog) {
		dialog.open();
		dialog.style.visibility = 'hidden';
		this.async( () => {
			dialog.refit();
			dialog.style.visibility = 'visible';
		}, 10);
	},

	oauthGoogle : function () {
		if (!this.google_access_token) {
			return new Promise( (resolve, reject) => {
				gapi.auth.authorize(
					{
						'client_id': this.google_client_id,
						'scope': [
							'https://www.googleapis.com/auth/photos',
							'https://www.googleapis.com/auth/drive.readonly',
							'https://www.googleapis.com/auth/photos.upload',
							'https://www.googleapis.com/auth/youtube'
						],
						'immediate': false
					},
					(result) => {
						console.log(result);
						if (result && !result.error) {
							this.google_access_token = result.access_token;
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

	openGooglePicker : function () {
		// hide software keyboard
		this.$.body.blur();
		this.$.title.blur();

		this.async( () => {

			var openPicker = (callback) => {
				return this.oauthGoogle().
					then(() => {
						console.log('google_access_token', this.google_access_token);
						var picker = new google.picker.PickerBuilder().
							setOAuthToken(this.google_access_token).
							// setOrigin(window.location.protocol + '//' + window.location.host).
							setDeveloperKey(this.google_developer_key).
							addView(new google.picker.PhotosView().setType('camerasync')).
							addView(google.picker.ViewId.PHOTOS).
							addView(google.picker.ViewId.PHOTO_UPLOAD).
							addView(google.picker.ViewId.YOUTUBE).
							// addView(google.picker.ViewId.MAPS).
							enableFeature(google.picker.Feature.MULTISELECT_ENABLED).
							setSize(window.innerWidth, window.innerHeight).
							setCallback(function (data) {
								console.log('openPicker', data);
								callback(data);
							}).
							build();

						picker.setVisible(true);
					});
			};

			openPicker( (data) => {
				if (data[google.picker.Response.ACTION] !== google.picker.Action.PICKED) return;

				var syntax = '';

				var docs = data[google.picker.Response.DOCUMENTS];

				for (var i = 0, doc; (doc = docs[i]); i++) {
					if (doc.type === 'photo') {
						var it = {
							url : doc.url,
							key: doc.mediaKey,
							image : doc.thumbnails[3].url.replace(/\/s\d+\//, '/s2048/')
						};
						var template = this.$.imagesTemplate.textContent;
						syntax    += template.replace(/@@(\w+)@@/g, function (_, name) { return it[name] }).replace(/\s+/g, ' ') + '\n';
					} else
					if (doc.type === 'location') {
						console.log(doc.thumbnails[3]);
						syntax += '<img src+"' + doc.thumbnails[3].url + '" alt="[MAP]"/>' + '\n';
					}
				}

				if (syntax) {
					this.$.body.insertText(syntax, true);
					this.set('form.body', this.$.body.value.replace(/\r\n/g, '\n'));
				}

				this.$.body.focus();
			});
		}, 100);
	},

	progressString : function () {
		if (this.progress) {
			return {
				'saving' : '保存中',
				'update-similar-entries': '関連エントリを構築中',
				'posting-new-job' : 'ジョブを投入中',
				'done' : '完了'
			}[this.progress] || this.progress;
		} else {
			return 'リクエスト中';
		}
	},

	strftime: function (format, date, locale) {
		if (typeof date === 'number') {
			date = new Date(date);
		}
		return strftime(format, date, locale);
	}
});
