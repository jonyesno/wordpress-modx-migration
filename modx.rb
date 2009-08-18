require 'rubygems'
require 'mysql'
require 'ostruct'

class ModX

  attr_reader :posts, :post_template_id, :post_category_id

  def initialize(template)
    @db = Mysql.init
    @db.options(Mysql::SET_CHARSET_NAME, Config.modx[:charset])
    @db.real_connect(
      Config.modx[:host],
      Config.modx[:user],
      Config.modx[:pass],
      Config.modx[:db]
    )
    @db.query("SET NAMES #{Config.modx[:charset]}")
    
    @post_template_id = self.find_template_id(template)
    @post_category_id = self.find_category_id
    @posts = []
    self.load_posts
    STDERR.puts("[ModX] #{template} -> #{@post_template_id} : #{@post_category_id}")
  end

  def find_template_id(name)
    q = @db.query(%Q{select id from modx_site_templates
                        where templatename = "#{name}"
                        limit 1})
    unless q.num_rows == 1
      raise RuntimeError, "couldn't find template #{name}"
    end

    @post_template_id = q.fetch_row[0]
  end

  def find_category_id
    q = @db.query(%Q{select v.id
                     from modx_site_tmplvars as v join modx_site_tmplvar_templates as t
                     on v.id = t.tmplvarid
                     where v.name = "categories" and t.templateid = #{@post_template_id}})
    unless q.num_rows == 1
      raise RuntimeError, "couldn't discover 'categories' tmpvars id"
    end

    @post_category_id = q.fetch_row[0]
  end

  def find_content(opts)
    where = "template = #{@post_template_id}"
    if opts.has_key?(:pagetitle) 
      where += %Q{ and pagetitle = '#{Mysql::quote(opts[:pagetitle])}' }
    end
    if opts.has_key?(:pub_date)
      where += %Q{ and pub_date = #{opts[:pub_date]} }
    end

    q = @db.query(%Q{select id
                     from modx_site_content
                     where #{where}
                     limit 1})
    unless q.num_rows == 1
      # STDERR.puts "couldn't find content for template #{@post_template_id}: #{opts.keys.join(',')}"
      return nil
    end

    q.fetch_row[0]
  end

  def post_categories(post)
    q = @db.query(%Q{select value
                     from modx_site_tmplvar_contentvalues
                     where contentid = #{post} and tmplvarid = #{@post_category_id}})
    case 
    when q.num_rows == 0 
      [ ]
    when q.num_rows == 1
      q.fetch_row[0].split(/\|\|/)
    else
      raise RuntimeError, "multiple rows for categories for post #{post} (#{@post_category_id})"
    end
  end

  def load_posts
    q = @db.query(%Q{select * from modx_site_content
                         where template = #{@post_template_id}})
    
    q.each_hash do |p|
      os = OpenStruct.new(p)
      os.pid = p['id'].to_i # stash :id in :pid, since foo#id is reserved
      os.categories = post_categories(os.pid)
      @posts.push os
    end
  end

  def delete_post(post)
    p = self.find_content(:pagetitle => post[:pagetitle], :pub_date => post[:pub_date])

    return if p.nil?

    # categories
    if self.post_categories(p).length > 0
      @db.query(%Q{delete from modx_site_tmplvar_contentvalues
                   where contentid = #{p} and tmplvarid = #{@post_category_id} })
    end

    # comments: clear out jot_content, jot_fields 
    q = @db.query(%Q{select id from modx_jot_content where uparent = #{p}})
    q.each_hash do |jc| 
      @db.query(%Q{delete from modx_jot_fields where id = #{jc['id']}})
    end
    @db.query(%Q{delete from modx_jot_content where uparent = #{p}})

    # post itself
    @db.query(%Q{delete from modx_site_content
                 where pagetitle = '#{Mysql::quote(post[:pagetitle])}' and pub_date = #{post[:pub_date]}})
  end

    
  def add_post(post)
    STDERR.puts("[ModX:add_post] new post #{post[:pagetitle]}")

    i = %Q{insert into modx_site_content
           (#{post.keys.join(',')})
           values(#{post.keys.map {|k| post[k].is_a?(String) ? "'" + Mysql.quote(post[k]) + "'" : post[k] } .join(',') }) }
    @db.query(i)

    return @db.insert_id
  end

  def add_post_categories(post, categories)
    p = self.find_content(:pagetitle => post[:pagetitle], :pub_date => post[:pub_date])

    modx_cats = categories.join('||')
    STDERR.puts("[ModX:add_post_categories] adding categories for post #{p}: #{modx_cats}")
    i = %Q{insert into modx_site_tmplvar_contentvalues
           (tmplvarid, contentid, value)
           values(#{@post_category_id}, #{p}, '#{modx_cats}') }
    @db.query(i)

    return @db.insert_id
  end

  def add_post_comments(post, comments)
    p = self.find_content(:pagetitle => post[:pagetitle], :pub_date => post[:pub_date])

    comments.each do |c|
      # connect comment to post
      c[:uparent] = p

      # remove fields destined for jot_fields
      jot_fields = { :name => c[:name],
                     :email => c[:email],
                     :url => c[:url]}
      c.delete(:name)
      c.delete(:email)
      c.delete(:url)

      # insert remained into jot_content
      i = %Q{insert into modx_jot_content
             (#{c.keys.join(',')})
             values(#{c.keys.map {|k| c[k].is_a?(String) ? "'" + Mysql.quote(c[k]) + "'" : c[k] } .join(',') }) }
      @db.query(i)
      jot_id = @db.insert_id

      @db.query(%Q{insert into modx_jot_fields
                   (id,label,content)
                   values(#{jot_id}, 'name', '#{Mysql.quote(jot_fields[:name])}')})
      @db.query(%Q{insert into modx_jot_fields
                   (id,label,content)
                   values(#{jot_id}, 'email', '#{Mysql.quote(jot_fields[:email])}')})
      @db.query(%Q{insert into modx_jot_fields
                   (id,label,content)
                   values(#{jot_id}, 'url', '#{Mysql.quote(jot_fields[:url])}')})
    end
  end

  def find_user(user)
    q = @db.query(%Q{select id from modx_manager_users where username = '#{user[:username]}' limit 1})
    if q.num_rows == 1
      id = q.fetch_row[0]
      STDERR.puts("[ModX:find_user] found user #{user[:username]} #{id}")
      return id
    else
      return nil
    end
  end

  def delete_user(user)
    q = @db.query(%Q{select id from modx_manager_users where username = '#{user[:username]}'})
    if q.num_rows > 0
      STDERR.puts("[ModX:delete_user] removing user #{user[:username]}")
    end
    q.each_hash do |u|
      @db.query(%Q{delete from modx_user_attributes where internalKey = #{u['id']}})
    end
    @db.query(%Q{delete from modx_manager_users where username = '#{user[:username]}'})
  end

  def add_user(user)
    STDERR.puts("[ModX:add_user] new user #{user[:username]}")
    @db.query(%Q{insert into modx_manager_users (username) values('#{user[:username]}')})
    id = @db.insert_id

    user.delete(:username)
    user[:internalKey] = id
    @db.query(%Q{insert into modx_user_attributes
                 (#{user.keys.join(',')})
                 values(#{user.keys.map {|k| user[k].is_a?(String) ? "'" + Mysql.quote(user[k]) + "'" : user[k] } .join(',') })})
    return id
  end

end

