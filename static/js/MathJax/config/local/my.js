MathJax.Hub.Config({
	tex2jax: {
		processClass: "content",
		preview: "TeX",
		inlineMath: [["\\(","\\)"]],
		displayMath: [ ["$$", "$$"] ]
	},
	"fast-preview": {
		Chunks: {EqnChunk: 10000, EqnChunkFactor: 1, EqnChunkDelay: 0},
		color: "inherit!important",
		updateTime: 30, updateDelay: 6,
		messageStyle: "none",
		disabled: true
	},
	showProcessingMessages: false,
	showMathMenu: false,
	"v1.0-compatible": false
});
// MathJax.Hub.Queue(["Typeset", MathJax.Hub]);

MathJax.Ajax.loadComplete("[MathJax]/config/local/my.js");
