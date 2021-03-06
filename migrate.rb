#!/usr/bin/env ruby

require 'migration'

m = Migration.new(Config.wordpress_www, Config.modx[:root_blog_template], Config.modx[:root_blog_content])
m.migrate_users
m.migrate_all_posts

m = Migration.new(Config.wordpress_www, Config.modx[:root_pages_template], Config.modx[:root_pages_content])
m.migrate_users
m.migrate_all_pages

m = Migration.new(Config.wordpress_newsblog, Config.modx[:root_newsblog_template], Config.modx[:root_newsblog_content])
m.migrate_users
m.migrate_all_posts

