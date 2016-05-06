#!/bin/sh

db=`perl -MNogag::Config -e 'print config->param("cache_db")'`
#sqlite3 db/test-cache.db < ./db/cache.sql
