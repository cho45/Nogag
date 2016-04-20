#!/usr/bin/env node

const mjAPI = require("mathjax-node/lib/mj-page.js");
const hljs = require('highlight.js');
const jsdom = require("jsdom").jsdom;
const minify = require('html-minifier').minify;


mjAPI.start();
mjAPI.config({
	tex2jax: {
		inlineMath: [["\\(","\\)"]],
		displayMath: [ ["$$", "$$"] ]
	},
	extensions: ["tex2jax.js"]
});

function processWithString (html) {
	console.log('processWithString');
	return Promise.resolve(html).
		then(processMathJax).
		then(processMinify);
}

function processWithDOM (html) {
	console.log('processWithDOM');
	var document = jsdom();
	document.body.innerHTML = html;
	var dom = document.body;
	return Promise.resolve(dom).
		then(processHighlight).
		then( (dom) => dom.innerHTML );
}


function processHighlight (node) {
	console.log('processHighlight');
	var codes = node.querySelectorAll('pre.code');
	for (var i = 0, it; (it = codes[i]); i++) {
		if (/lang-(\S+)/.test(it.className)) {
			console.log('highlightBlock', it);
			hljs.highlightBlock(it);
		}
	}
	return Promise.resolve(node);
}

function processMathJax (html) {
	console.log('processMathJax');
	if (!html.match(/\\\(|\$\$/)) {
		return Promise.resolve(html);
	}
	return new Promise( (resolve, reject) => {
		mjAPI.typeset({
			html: html,
			renderer: "SVG",
			inputs: ["TeX"],
			ex: 6,
			width: 40
		}, function (result) {
			console.log('typeset done');
			console.log(result);

			resolve(result.html);
		});
	});
}

function processMinify (html) {
	return Promise.resolve(minify(html, {
		collapseBooleanAttributes: true,
		collapseInlineTagWhitespace: true,
		collapseWhitespace: true,
		minifyCSS: true,
		minifyJS: true,
		removeAttributeQuotes: true,
		removeOptionalTags: true,
		removeRedundantAttributes: true,
		removeScriptTypeAttributes: true,
		removeStyleLinkTypeAttributes: true,
		sortAttributes: true,
		sortClassName: true,
		useShortDoctype: true
	}));
}

const http = require('http');
const url = require('url');
http.createServer(function (req, res) {
	var html = '';
	var location = url.parse(req.url, true);
	req.on('readable', function () {
		var chunk = req.read();
		console.log('readable');
		if (chunk) html += chunk.toString('utf8');
	});
	req.on('end', function() {
		console.log('end');

		if (location.query.minifyOnly) {
			Promise.resolve(html).
				then(processMinify).
				then( (html) => {
					console.log('done');
					res.writeHead(200, {'Content-Type': 'text/plain; charset=utf-8'});
					res.end(html);
				}).
				catch( (e) => {
					console.log(e);
					res.writeHead(200, {'Content-Type': 'text/plain; charset=utf-8'});
					res.end(html);
				});
		} else {
			Promise.resolve(html).
				then(processWithDOM).
				then(processWithString).
				then( (html) => {
					console.log('done');
					res.writeHead(200, {'Content-Type': 'text/plain; charset=utf-8'});
					res.end(html);
				}).
				catch( (e) => {
					console.log(e);
					res.writeHead(200, {'Content-Type': 'text/plain; charset=utf-8'});
					res.end(html);
				});
		}
	});
}).listen(13370, '127.0.0.1');
console.log('Server running at http://127.0.0.1:13370/');
