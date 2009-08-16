#!/usr/bin/env ruby

require 'modx'

modx = ModX.new('Blog')

modx.posts.each do |p|
  puts %Q{#{p.pid} [#{p.parent}] "#{p.pagetitle}" #{p.categories.join(',')}}
end

