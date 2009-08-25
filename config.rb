module Config
  def self.wordpress_www
    {
      :host    => '127.0.0.1',
      :db      => 'org_wp',
      :user    => 'org',
      :pass    => '',
      :charset => 'latin1',
    }
  end

  def self.wordpress_newsblog
    {
      :host    => '127.0.0.1',
      :db      => 'org_nb',
      :user    => 'org',
      :pass    => '',
      :charset => 'UTF8',
    }
  end

  def self.modx
    {
      :host          => '127.0.0.1',
      :db            => 'org_modx',
      :user          => 'org',
      :pass          => '',
      :charset       => 'UTF8',
      :root_blog_template     => 'Blog',
      :root_blog_content      => 'Blog',
      :root_pages_template    => 'About',
      :root_pages_content     => 'About',
      :root_newsblog_template => 'Simple page',
      :root_newsblog_content  => 'Newsblog',
      :default_author => 1,
    }
  end
end

