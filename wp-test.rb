#!/usr/bin/env ruby

require 'wordpress'

wp = Wordpress.new
wp.list_posts
wp.list_pages

