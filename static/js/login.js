
(async function () {
	if (location.search.indexOf('invalid') !== -1) return;

	const cred = await navigator.credentials.get({
		password: true
	});
	console.log(cred);
	if (!cred) return;

	document.getElementById('username').value = cred.id;
	document.getElementById('password').value = cred.password;
	document.getElementById('login').submit();
})();


