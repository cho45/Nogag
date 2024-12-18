#!/bin/sh

optiwww.rb static/css/style.css
optiwww.rb static/js/nogag.js
optiwww.rb static/js/daterelative.js
optiwww.rb static/js/keyboard.js
optiwww.rb static/js/abcjs_basic_5.1.1-min.js
optiwww.rb static/js/balancetext/*.js
rsync -av --update --exclude 'session/' --exclude 'db/*.db' --exclude '.xslate_cache' --exclude 'service/postprocess-js-daemon/log/main/' /srv/www/lowreal.net/Nogag-beta/  /srv/www/lowreal.net/Nogag
rsync -av /srv/www/lowreal.net/Nogag-beta/node_modules/  /srv/www/lowreal.net/Nogag/node_modules/ 
sudo svc -h /service/backend
sudo svc -h /service/worker
sudo svc -h /service/postprocess-js-daemon
curl -s --head -H 'Cache-Control: no-cache' https://lowreal.net > /srv/www/lowreal.net.link.txt

