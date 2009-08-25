#!/usr/bin/env ruby

require 'wordpress'

wp = Wordpress.new(Config.wordpress_newsblog)
wp.list_posts
wp.list_pages

