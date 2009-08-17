require 'rubygems'
require 'mysql'
require 'ostruct'
require 'config'

# unsure if this is easier than bending AR / DM to WP schema?
class Wordpress

  attr_reader :posts

  def initialize
    @db = Mysql.init
    @db.options(Mysql::SET_CHARSET_NAME, Config.wordpress[:charset])
    @db.real_connect(
      Config.wordpress[:host],
      Config.wordpress[:user],
      Config.wordpress[:pass],
      Config.wordpress[:db]
    )
    @db.query("SET NAMES #{Config.wordpress[:charset]}")

    @posts = []
    @categories = []
    self.load_categories
    self.load_posts
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
  def load_posts
    q = @db.query("select *
                   from wp_posts as p
                   where p.post_type = 'post' and p.post_status = 'publish'
                   order by id desc")

    q.each_hash do |p|
      post = OpenStruct.new(p)
      post.categories = self.post_categories(post.ID).map { |c| @categories[c] }
      post.comments   = self.post_comments(post.ID)
      @posts.push post
    end

  end

  # work out what categories exist via the taxonomy tables
  def load_categories
    q = @db.query("select t.term_id, t.name, t.slug
                   from wp_terms as t join wp_term_taxonomy as x
                   on t.term_id = x.term_id
                   where x.taxonomy = 'category'")

    q.each_hash { |c| os = OpenStruct.new(c) ; @categories[os.term_id.to_i] = OpenStruct.new(c) }
  end

  def list_posts
    @posts.each do |p|
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

end
