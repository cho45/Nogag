#!/usr/bin/env node

var mjAPI = require("mathjax-node/lib/mj-page.js");


mjAPI.start();
mjAPI.config({
	tex2jax: {
		inlineMath: [["\\(","\\)"]],
		displayMath: [ ["$$", "$$"] ]
	},
	extensions: ["tex2jax.js"]
});

var http = require('http');
http.createServer(function (req, res) {
	var html = [];
	req.on('readable', function () {
		var chunk = req.read();
		console.log('readable');
		if (chunk) html.push(chunk.toString('utf8'));
	});
	req.on('end', function() {
		console.log('end');
		console.log('html', html);

		mjAPI.typeset({
			html: html.join(""),
			renderer: "SVG",
			inputs: ["TeX"]
		}, function (result) {
			res.writeHead(200, {'Content-Type': 'text/plain; charset=utf-8'});
			res.end(result.html);
		});
	});
}).listen(13370, '127.0.0.1');
console.log('Server running at http://127.0.0.1:13370/');
