#!/usr/bin/env ruby

file = ARGV.shift


result = `sqlite3 -separator '\t' -batch '#{file}' 'select "theschwartz.count." || replace(funcname, "::", "_"), (select count(*) from job where job.funcid = funcmap.funcid), strftime("%s", "now") from funcmap;'`
puts result

