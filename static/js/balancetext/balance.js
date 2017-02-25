/**
 * 
 * 引数は処理対象のノードリスト。ただし処理が行われると要素内容が置き換わるので、テキストノードのみを含むブロック要素を渡すこと
 *
 */
function balance (headings) {
	/*
	function measureText (parent, text) {
		var span = document.createElement('span');
		span.textContent = text;
		span.style.padding = "0";
		span.style.margin = "0";
		span.style.border = "none";
		span.style.whiteSpace = 'nowrap';
		parent.appendChild(span);
		var width = span.offsetWidth;
		parent.removeChild(span);
		return {
			width: width
		};
	}
	*/

	var canvas = document.createElement('canvas');
	var ctx = canvas.getContext('2d');
	// 区切りをカスタマイズした TinySegmenter を使うこと
	var segmenter = new TinySegmenter();
	if (balance.DEBUG > 1) {
		canvas.width = 1000;
		canvas.height = 500;
		document.body.appendChild(canvas);
	}

	for (var i = 0, it; (it = headings[i]); i++) {
		var text = it.textContent;
		var style = window.getComputedStyle(it, null);
		var height     = parseFloat(style.getPropertyValue('height'));
		var width      = parseFloat(style.getPropertyValue('width'));
		var lineHeight = parseFloat(style.getPropertyValue('line-height'));
		if (!width || !height) {
			if (balance.DEBUG) console.log('warn', 'node may be inline element');
			return;
		}
		if (!lineHeight) { // line-height: 'normal', 'inehrit' ...
			if (balance.DEBUG) console.log('warn', 'invalid line-height');
			return;
		}
		// inline 要素なら getClientRects().length で行数がえられるが、ブロック要素だとうまい方法がない?
		var lineCount = Math.round(height / lineHeight);

		if (lineCount === 1) {
			continue;
		}

		// 該当フォントがロード済みである必要あり
		// Firefox は font プロパティが空になる。
		ctx.font = [
			style.getPropertyValue('font-style'),
			style.getPropertyValue('font-variant'),
			style.getPropertyValue('font-weight'),
			style.getPropertyValue('font-stretch'),
			style.getPropertyValue('font-size'),
			style.getPropertyValue('font-family')
		].join(' ');
		if (balance.DEBUG) console.log(ctx.font);

		// 分割
		var segments = segmenter.segment(text);

		// 不適切な分割の補正 (スペースなしの英+数の連続は連結するなど)
		for (var j = 0, len = segments.length - 1; j < len; j++) {
			if (
				/[a-z0-9.-]$/i.test(segments[j]) && 
				/^[a-z0-9.-]/i.test(segments[j+1])
			) {
				segments[j] += segments[j+1];
				segments.splice(j+1, 1);
				len--;
				// さらに連続するケースもあるので再度処理する
				j--;
			}
		}

		segments = segments.
			map(function (seg) {
				return {
					text: seg,
					width: ctx.measureText(seg).width
				}
			});

		if (balance.DEBUG) console.log(segments.map(function (i) { return i.text }).join('" "'));

		var result = [[]];
		var minWidth = ctx.measureText(text).width / lineCount;
		var current = 0;
		if (balance.DEBUG) console.log(
			'height', height,
			'width', width,
			'lineCount', lineCount,
			'lineHeight', lineHeight, 
			'minWidth', minWidth,
			text, it.getClientRects()
		);
		/*
		 * 一行が minWidth 未満なら無条件に行に追加
		 * 行数が一定を超えないように一行が width 以内になるように調整
		 */
		var invalid = false;
		for (var j = 0, len = segments.length; j < len; j++) {
			var seg = segments[j];
			if (current + seg.width > minWidth) {
				if (result.length < lineCount) {
					result.unshift([seg]);
					current = seg.width;
				} else {
					// 最低行幅をオーバーするがとりあえず追加する
					result[0].push(seg);
					for (var k = 0; k < result.length; k++) {
						var w = result[k].reduce(function (r, i) { return r + i.width; }, 0);
						if (balance.DEBUG) {
							var t = result[k].reduce(function (r, i) { return r + i.text; }, '');
							console.log('over', k, w, '<', width, t, ctx.measureText(t));
							if (balance.DEBUG > 1) {
								if (k === 1) ctx.fillText(t, 50, 100);
							}
						}
						if (w < width) {
							// 最大行幅以内ならなにもしない
							break;
						} else {
							// 最大行幅も超えてしまう場合、行送りをする
							if (k !== result.length - 1) {
								// 最後の行が width 未満になるまで前の行に送る
								while (w > width) {
									var s = result[k].shift()
									w -= s.width;
									result[k + 1].push(s);
								}
							} else {
								// 送りを繰替えした結果 1行目の長さが width を超えてしまった
								// つまりこれは分割不可を意味する
								invalid = true;
								break;
							}
						}
					}
					current = result[0].reduce(function (r, i) { return r + i.width; }, 0);
				}
			} else {
				result[0].push(seg);
				current += seg.width;
			}
		}

		if (!invalid) {
			result.reverse();
			var result = result.map(function (i) {
				return i.map(function (s) {
					return s.text;
				}).join('')
			});
			if (balance.DEBUG) console.log(result.join(' | '));
			it.textContent = result.join('\n');
		} else {
			var result = segments.map(function (s) {
				return s.text;
			});
			if (balance.DEBUG) console.log('failed to break');
			result.push(result.pop().split('').join("\uFEFF"));
			it.textContent = result.join('');
		}
	}
}

