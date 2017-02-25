function DateRelative () { this.init.apply(this, arguments) }
DateRelative.prototype = {
	init : function (value) {
		this.value = value + 0;
	},
	update : function () {
		var diff   = Math.floor((new Date().getTime() - this.value) / 1000);
		if (typeof DateRelative.offset == 'number') {
			if (diff < 0) DateRelative.offset = -diff;
			diff = Math.max(diff - DateRelative.offset, 0);
		}
		var future = diff < 0;
		if (future) diff = -diff;
		if (diff < 60) {
			this.number   = diff;
			this.unit     = '\u79d2';
			this.isFuture = future;
			return this;
		}
		diff = Math.floor(diff / 60);
		if (diff < 60) {
			this.number   = diff;
			this.unit     = '\u5206';
			this.isFuture = future;
			return this;
		}
		diff = Math.floor(diff / 60);
		if (diff < 24) {
			this.number   = diff;
			this.unit     = '\u6642\u9593';
			this.isFuture = future;
			return this;
		}
		diff = Math.floor(diff / 24);
		if (diff < 31) {
			this.number   = diff;
			this.unit     = '\u65e5';
			this.isFuture = future;
			return this;
		}
		if (diff < 365) {
			this.number   = Math.floor(diff / 30);
			this.unit     = '\u30f6\u6708';
			this.isFuture = future;
			return this;
		}
		diff = Math.floor(diff / 365);
		this.number   = diff;
		this.unit     = '\u5e74';
		this.isFuture = future;
		return this;
	},
	valueOf : function () { return this.value }
};
DateRelative.update = function (target) {
	var dtrl = target._dtrl;
	if (!dtrl) {
		var datetime = target.getAttribute('datetime');
		if (!datetime) return;
		var dtf = datetime.match(/(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+)(?:\.(\d+))?Z/);
		target._dtrl = dtrl = new DateRelative(Date.UTC(+dtf[1], +dtf[2] - 1, +dtf[3], +dtf[4], +dtf[5], +dtf[6]));
	}
	dtrl.update();

	// var locale = navigator.userAgent.split(/[();]\s*/)[4];
	var format;
	format = dtrl.number +
		dtrl.unit +
		(dtrl.isFuture ? '\u5f8c' : '\u524d');
	target.textContent = format;
};
DateRelative.updateAll = function (parent) {
	parent = parent || document;
	var targets = parent.getElementsByTagName('time');
	for (var i = 0, it; (it = targets[i]); i++) {
		DateRelative.update(it);
	}
};
DateRelative.setupAutoUpdate = function (parent) {
	return setInterval(function () {
		DateRelative.updateAll(parent);
	}, 60 * 1000);
};
