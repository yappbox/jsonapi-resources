require File.expand_path('../../../test_helper', __FILE__)

class LinkageByForeignKeyPostResource < JSONAPI::Resource
  model_name 'Post'
  exclude_links :default
  has_one :creator, class_name: 'Person', relation_name: :author, foreign_key: :author_id,
          always_include_linkage_data: true, exclude_links: :default
end

class LinkageOverriddenReaderPostResource < LinkageByForeignKeyPostResource
  def creator(_options = {})
    PersonResource.new(Person.find(2), context)
  end
end

class LinkageFallbackAuthorPost < ActiveRecord::Base
  self.table_name = 'posts'
  belongs_to :author, class_name: 'Person', foreign_key: 'author_id'

  def author
    super || Person.find(2)
  end
end

class LinkageFallbackAuthorPostResource < LinkageByForeignKeyPostResource
  model_name 'LinkageFallbackAuthorPost'
end

class ToOneLinkageTest < ActiveSupport::TestCase
  def test_linkage_reads_the_foreign_key
    posts = Post.where.not(author_id: nil).order(:id).to_a

    assert_equal posts.map { |post| post.author_id.to_s }, creator_ids(LinkageByForeignKeyPostResource, posts)
  end

  def test_loads_each_related_record_once_per_foreign_key_value
    posts = Post.where.not(author_id: nil).order(:id).to_a
    distinct_authors = posts.map(&:author_id).uniq.size
    assert_operator posts.size, :>, distinct_authors

    queries = people_queries { creator_ids(LinkageByForeignKeyPostResource, posts) }

    assert_equal distinct_authors, queries
  end

  def test_linkage_is_null_when_the_related_record_cannot_be_loaded
    post = Post.new(id: 999_999, author_id: 999_999, title: 'Dangling')

    assert_equal [nil], creator_ids(LinkageByForeignKeyPostResource, [post])
  end

  def test_null_foreign_key_skips_the_load
    post = Post.new(id: 999_999, author_id: nil, title: 'Anonymous')

    queries = people_queries { assert_equal [nil], creator_ids(LinkageByForeignKeyPostResource, [post]) }

    assert_equal 0, queries
  end

  def test_overridden_reader_is_honored
    posts = Post.where.not(author_id: 2).order(:id).limit(2).to_a

    assert_equal %w(2 2), creator_ids(LinkageOverriddenReaderPostResource, posts)
  end

  def test_overridden_model_reader_is_honored
    post = LinkageFallbackAuthorPost.new(id: 999_999, author_id: nil, title: 'Anonymous')

    assert_equal %w(2), creator_ids(LinkageFallbackAuthorPostResource, [post])
  end

  private

  def creator_ids(resource_klass, posts)
    serializer = JSONAPI::ResourceSerializer.new(resource_klass, url_helpers: TestApp.routes.url_helpers)
    serialized = serializer.serialize_to_hash(posts.map { |post| resource_klass.new(post, nil) })

    Array.wrap(serialized[:data]).map do |resource|
      linkage = resource['relationships']['creator'][:data]
      linkage && linkage[:id]
    end
  end

  def people_queries
    count = 0
    callback = ->(_, _, _, _, payload) { count += 1 if payload[:sql] =~ /FROM "people"/ }
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { yield }
    count
  end
end
