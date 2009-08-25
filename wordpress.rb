require 'rubygems'
require 'mysql'
require 'ostruct'
require 'config'

# unsure if this is easier than bending AR / DM to WP schema?
class Wordpress

  attr_reader :posts, :pages, :users

  def initialize(config)
    @db = Mysql.init
    @db.options(Mysql::SET_CHARSET_NAME, config[:charset])
    @db.real_connect(
      config[:host],
      config[:user],
      config[:pass],
      config[:db]
    )
    @db.query("SET NAMES #{config[:charset]}")

    @posts      = []
    @pages      = []
    @categories = []
    @users      = {}

    self.load_categories
    self.load_posts
    self.load_pages
    self.load_users
    @db.close
  end

  # wander through taxonomy tables to get the category ids
  def post_categories(p)
    result = []

    q = @db.query("select x.term_id
                   from wp_term_taxonomy as x join wp_term_relationships as r
                   on x.term_taxonomy_id = r.term_taxonomy_id
                   where r.object_id = #{p}")

    q.each_hash do |c|
      id = c['term_id'].to_i
      if @categories[id].nil?
        STDERR.puts "[Wordpress:post_categories] ignoring absent category term_id #{id} for post #{p}"
      else
        result.push id
      end
    end

    return result
  end

  def post_comments(p)
    result = []

    q = @db.query(%Q{select *
                     from wp_comments
                     where comment_approved = '1' and comment_post_ID = #{p}})
    q.each_hash do |c|
      comment = OpenStruct.new(c)
      result.push comment
    end

    return result
  end

  # XXX we load all the data in at once, ouch
  # this is fine on this dataset of ~1k posts but would better to defer the post/comment content until needed
  def load_content(post_type)
    content = []
    q = @db.query("select distinct *
                   from wp_posts as p
                   where p.post_type = '#{post_type}' and p.post_status = 'publish'
                   order by id desc")

    q.each_hash do |p|
      post = OpenStruct.new(p)
      post.categories = self.post_categories(post.ID).map { |c| @categories[c] }
      post.comments   = self.post_comments(post.ID)
      content.push post
    end

    return content
  end

  def load_posts
    @posts = self.load_content("post")
  end

  def load_pages
    @pages = self.load_content("page")
  end

  # work out what categories exist via the taxonomy tables
  def load_categories
    q = @db.query("select t.term_id, t.name, t.slug
                   from wp_terms as t join wp_term_taxonomy as x
                   on t.term_id = x.term_id
                   where x.taxonomy = 'category'")

    q.each_hash { |c| os = OpenStruct.new(c) ; @categories[os.term_id.to_i] = OpenStruct.new(c) }
  end

  def load_users
    q = @db.query("select distinct u.*
                   from wp_users as u
                   join wp_posts as p
                   on p.post_author = u.ID and p.post_type = 'post' and p.post_status = 'publish'")

    q.each_hash do |u|
      user = OpenStruct.new(u)
      @users[u['ID']] = user
    end
  end

  def list_content(content)
    content.each do |p|
      puts %Q{#{p.ID} #{p.post_date} "#{p.post_title}" #{p.categories.map { |c| c.name }.join(',')} }
        if p.comments.length == 0
          puts "(no comments)"
        else
          p.comments.each do |c| 
            puts %Q{ -> #{c.commentID} [#{c.comment_post_ID}] #{c.comment_author} : #{c.comment_content[0 .. 20]} }
          end
        end

    end
  end

  def list_posts
    self.list_content(@posts)
  end

  def list_pages
    self.list_content(@pages)
  end

  def list_users
    @users.keys.each do |u|
      user = @users[u]
      puts "#{user.ID} #{user.user_login} #{user.user_email} #{user.user_nicename}"
    end
  end

end
