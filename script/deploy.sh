#!/bin/sh

optiwww static/css/style.css
optiwww static/js/nogag.js
rsync -av --update --exclude 'session/' --exclude 'db/' /srv/www/lowreal.net/Nogag-beta/  /srv/www/lowreal.net/Nogag

