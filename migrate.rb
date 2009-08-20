#!/usr/bin/env ruby

require 'migration'

m = Migration.new(Config.modx[:root_blog_template], Config.modx[:root_blog_content])
m.migrate_users
 m.migrate_all_posts

m = Migration.new(Config.modx[:root_pages_template], Config.modx[:root_pages_content])
m.migrate_users
m.migrate_all_pages

