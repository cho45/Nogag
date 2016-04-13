#!/bin/sh

optiwww.sh static/css/style.css
optiwww.sh static/js/nogag.js
rsync -av --update  /srv/www/lowreal.net/Nogag-beta/  /srv/www/lowreal.net/Nogag

