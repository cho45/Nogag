#!/usr/bin/env node

const jsdom = require("jsdom");
const { JSDOM } = jsdom;

// const mjAPI = require("mathjax-node");
const { mjpage } = require("mathjax-node-page");
const hljs = require('highlight.js');

const minify = require('html-minifier').minify;
const http = require('http');
const https = require('https');
const url = require('url');
const vm = require('vm');
const imageSize = require('image-size');

const HTTPS = {
	GET : function (url) {
		var body = '';
		return new Promise( (resolve, reject) => {
			https.get(
				url,
				(res) => {
					res.on('data', function (chunk) {
						body += chunk;
					});
					res.on('end', function() {
						res.body = body;
						resolve(res);
					})
				}
			).on('error', reject);
		});
	},

	getImageSize : function (imgUrl) {
		return new Promise( (resolve, reject) => {
			var options = url.parse(imgUrl);
			options.headers = {
				'Range': 'bytes=0-131072'
			};

			https.get(options, function (res) {
				console.log(options);
				console.log(res.statusCode);
				console.log(res.headers);
				var chunks = [];
				res.
					on('data', function (chunk) {
						chunks.push(chunk);
					}).
					on('end', function() {
						var buffer = Buffer.concat(chunks);
						try {
							resolve(imageSize(buffer));
						} catch (e) {
							reject(e);
						}
					});
			}).on('error', reject);
		});
	}
};

async function processWithString (html) {
	console.log('processWithString');
	html = await processMathJax(html);
	html = await processMinify(html);
	return html;
}

async function processWithDOM (html) {
	console.log('processWithDOM');
	const { document } = (new JSDOM(``, {
		features: {
			FetchExternalResources: false,
			ProcessExternalResources: false,
			SkipExternalResources: /./
		}
	})).window;
	document.body.innerHTML = html;

	var dom = document.body;
	dom = await processHighlight(dom);
	dom = await processImages(dom);
	dom = await processWidgets(dom);
	return dom.innerHTML;
}


async function processHighlight (node) {
	console.log('processHighlight');
	var codes = node.querySelectorAll('pre.code');
	for (var i = 0, it; (it = codes[i]); i++) {
		if (/lang-(\S+)/.test(it.className)) {
			console.log('highlightBlock', it);
			hljs.highlightBlock(it);
		}
	}
	return node;
}

async function processImages (node) {
	console.log('processImages');
	{
		var imgs = node.querySelectorAll('img[src*="googleusercontent"], img[src*="ggpht"]');
		for (var i = 0, img; (img = imgs[i]); i++) {
			img.src = img.src.
				replace(/^http:/, 'https:').
				replace(/\/s\d+\//g, '/s2048/');
		}
	}
	{
		var imgs = node.querySelectorAll('img[src*="cdn-ak.f.st-hatena.com"]');
		for (var i = 0, img; (img = imgs[i]); i++) {
			img.src = img.src.
				replace(/^http:/, 'https:');
		}
	}
	{
		var imgs = node.querySelectorAll('img[src*="ecx.images-amazon.com"]');
		for (var i = 0, img; (img = imgs[i]); i++) {
			img.src = img.src.
				replace(/^http:\/\/ecx\.images-amazon\.com/, 'https://images-na.ssl-images-amazon.com');
		}
	}

	// fill width/height
	var promises = [];
	{
		var imgs = node.querySelectorAll('img[src]');
		for (var i = 0, img; (img = imgs[i]); i++) (function (img) {
			if (!img.src) return;
			if (img.width || img.height) return;
			var promise = HTTPS.getImageSize(img.src).
				then( (size) => {
					img.width = size.width;
					img.height = size.height;
				}).
				catch( (e) => {
					console.log(e);
				});

			promises.push(promise);
		})(img);
	}
	await Promise.all(promises);
	return node;
}

async function processWidgets (node) {
	var promises = [];

	console.log('processWidgets');
	var iframes = node.querySelectorAll('iframe[src*="www.youtube.com"]');
	for (var i = 0, iframe; (iframe = iframes[i]); i++) {
		iframe.src = iframe.src.replace(/^http:/, 'https:');
	}

	var scripts = node.getElementsByTagName('script');
	for (var i = 0, it; (it = scripts[i]); i++) (function (it) {
		if (!it.src) return;
		if (it.src.match(new RegExp('https://gist.github.com/[^.]+?.js'))) {
			var promise = HTTPS.GET(it.src).
				then( (res) => {
					var written = '';
					vm.runInNewContext(res.body, {
						document : {
							write : function (str) {
								written += str;
							}
						}
					});
					var div = node.ownerDocument.createElement('div');
					div.innerHTML = written;
					div.className = 'gist-github-com-js';
					it.parentNode.replaceChild(div, it);
				}).
				catch( (e) => {
					console.log(e);
				});

			promises.push(promise);
		}
	})(it);

	await Promise.all(promises);
	return node;
}

async function processMathJax (html) {
	console.log('processMathJax');
	if (!html.match(/\\\(|\$\$/)) {
		return html;
	}
	return await new Promise( (resolve, reject) => {
		mjpage(
			html, 
			{
				MathJax: {
					tex2jax: {
						inlineMath: [["\\(","\\)"]],
							displayMath: [ ["$$", "$$"] ]
					},
						extensions: ["tex2jax.js"]
				},
			},
			{
				svg: true,
				inputs: ["TeX"],
				cjkCharWidth: 24,
				ex: 6,
				width: 40,
				speakText: false,
			},
			function (output) {
				resolve(output);
			}
		)
	});
}

async function processMinify (html) {
	return minify(html, {
		html5: true,
		customAttrSurround: [
			[/\[%\s*(?:IF|UNLESS)\s+.+?\s*%\]/, /\[%\s*END\s*%\]/]
		],
		decodeEntities: true,
		collapseBooleanAttributes: true,
		collapseInlineTagWhitespace: true,
		collapseWhitespace: true,
		conservativeCollapse: true,
		preserveLineBreaks: false,
		minifyCSS: true,
		minifyJS: true,
		removeAttributeQuotes: true,
		removeOptionalTags: true,
		removeRedundantAttributes: true,
		removeScriptTypeAttributes: true,
		removeStyleLinkTypeAttributes: true,
		processConditionalComments: true,
		removeComments: true,
		sortAttributes: true,
		sortClassName: false,
		useShortDoctype: true
	});
}
const port = process.env['PORT'] || 13370

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
					console.log(e.stack);
					res.writeHead(500, {'Content-Type': 'text/plain; charset=utf-8'});
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
					console.log(e.stack);
					res.writeHead(500, {'Content-Type': 'text/plain; charset=utf-8'});
					res.end(html);
				});
		}
	});
}).listen(port, '127.0.0.1');

console.log(process.versions);
console.log('Server running at http://127.0.0.1:' + port);
