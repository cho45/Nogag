function DateRelative () { this.init.apply(this, arguments) };
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
            this.unit     = 'second';
            this.isFuture = future;
            return this;
        }
        diff = Math.floor(diff / 60);
        if (diff < 60) {
            this.number   = diff;
            this.unit     = 'minute';
            this.isFuture = future;
            return this;
        }
        diff = Math.floor(diff / 60);
        if (diff < 24) {
            this.number   = diff;
            this.unit     = 'hour';
            this.isFuture = future;
            return this;
        }
        diff = Math.floor(diff / 24);
        if (diff < 365) {
            this.number   = diff;
            this.unit     = 'day';
            this.isFuture = future;
            return this;
        }
        diff = Math.floor(diff / 365);
        this.number   = diff;
        this.unit     = 'year';
        this.isFuture = future;
        return this;
    },
    valueOf : function () { return this.value }
};
DateRelative.update = function (target) {
    var dtrl = target._dtrl;
    if (!dtrl) {
        var dtf = target.getAttribute('datetime').match(/(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+)(?:\.(\d+))?Z/);
        target._dtrl = dtrl = new DateRelative(Date.UTC(+dtf[1], +dtf[2] - 1, +dtf[3], +dtf[4], +dtf[5], +dtf[6]));
    }
    dtrl.update();

    var locale = navigator.userAgent.split(/[();]\s*/)[4];
    var format;
    if (/ja/.test(locale)) {
        format = dtrl.number + {
            'second' : '秒',
            'minute' : '分',
            'hour'   : '時',
            'day'    : '日',
            'year'   : '年'
        }[dtrl.unit] + (dtrl.isFuture ? '後' : '前')
    } else {
        format = dtrl.number + ' ' +
                 dtrl.unit + (dtrl.number == 0 || dtrl.number > 1 ? 's ' : ' ') +
                 (dtrl.isFuture ? 'after' : 'ago');
    }
    target.innerHTML = format;
};
DateRelative.updateAll = function (parent) {
    parent = parent || document;
    var targets = parent.getElementsByTagName('time');
    for (var i = 0, len = targets.length; i < len; i++) {
        DateRelative.update(targets[i]);
    }
};
DateRelative.setupAutoUpdate = function (parent) {
    return setInterval(function () {
        DateRelative.updateAll(parent);
    }, 60 * 1000);
};