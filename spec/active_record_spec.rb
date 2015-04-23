require 'spec_helper'
require 'logger'

puts "Using ActiveRecord #{ActiveRecord::VERSION::STRING}"

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")
ActiveRecord::Base.logger = Logger.new(nil)

def setup_db
  ActiveRecord::Schema.define(:version => 1) do
    create_table :posts do |t|
    end

    create_table :comments do |t|
      t.integer :post_id, :null => false
      t.datetime :deleted_at
    end

    create_table :votes do |t|
      t.integer :votable_id, :null => false
      t.string :votable_type, :null => false
    end
  end
end

setup_db

class Post < ActiveRecord::Base
  has_many :comments
  has_many :active_comments, -> { where( "deleted_at IS NULL") }, :class_name => 'Comment'
  has_many :votes, as: :votable
  preload_counts :comments => [:with_even_id]
  preload_counts :active_comments
  preload_counts :votes
end

class PostWithActiveComments < ActiveRecord::Base
  self.table_name = :posts

  has_many :comments, -> { where "deleted_at IS NULL" }
  preload_counts :comments
end

class Comment < ActiveRecord::Base
  belongs_to :post

  scope :with_even_id, -> { where('id % 2 = 0') }
end

class Vote < ActiveRecord::Base
  belongs_to :votable
end

def create_data
  post = Post.create
  5.times { post.comments.create }
  5.times { post.comments.create :deleted_at => Time.now }
  5.times { post.votes.create }
end

create_data

describe Post do
  it "should have a preload_comment_counts scope" do
    Post.should respond_to(:preload_comment_counts)
  end

  describe 'instance' do
    let(:post) { Post.first }

    it "should have a comment_count accessor" do
      post.should respond_to(:comments_count)
    end

    it "should be able to get count without preloading them" do
      post.comments_count.should equal(10)
    end

    it "should have an active_comments_count accessor" do
      post.should respond_to(:comments_count)
    end
  end

  describe 'instance with preloaded count' do
    let(:post) { Post.preload_comment_counts.preload_vote_counts.first }

    it "should be able to get the association count" do
      post.comments_count.should equal(10)
    end

    it "should be able to get the association count with a scope" do
      post.with_even_id_comments_count.should equal(5)
    end

    context "when association is polymorphic" do
      let(:post) { Post.preload_vote_counts.first }
      it "should be able to get the association count" do
        post.votes_count.should equal(5)
      end
    end
  end
end

describe PostWithActiveComments do
  describe 'instance with preloaded count' do
    let(:post) { PostWithActiveComments.preload_comment_counts.first }

    it "should be able to get the association count" do
      post.comments_count.should equal(5)
    end
  end
end
