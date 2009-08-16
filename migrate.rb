#!/usr/bin/env ruby

require 'migration'

m = Migration.new
m.migrate_all_posts
 

