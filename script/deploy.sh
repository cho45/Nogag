#!/bin/sh

optiwww.rb static/css/style.css
optiwww.rb static/js/nogag.js
rsync -av --update --exclude 'session/' --exclude 'db/' --exclude 'service/postprocess-js-daemon/log/main/' /srv/www/lowreal.net/Nogag-beta/  /srv/www/lowreal.net/Nogag
sudo svc -h /service/backend
