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

    create_table :shares do |t|
      t.string :email
      t.integer :shareable_id
    end

  end
end

setup_db

class Comment < ActiveRecord::Base
  belongs_to :post

  scope :with_even_id, -> { where('id % 2 = 0') }
end

class Vote < ActiveRecord::Base
  belongs_to :votable
end

class Share < ActiveRecord::Base

end

class Post < ActiveRecord::Base
  has_many :comments
  has_many :active_comments, -> { where( "deleted_at IS NULL") }, :class_name => 'Comment'
  has_many :votes, as: :votable
  has_many :shares, foreign_key: :shareable_id
  
  preload_counts :comments
  preload_counts :active_comments
  preload_counts :votes
  preload_counts :shares
end

def create_data
  post = Post.create
  5.times { post.comments.create }
  5.times { post.comments.create :deleted_at => Time.now }
  5.times { post.votes.create }
  5.times { post.shares.create }
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
  end

  describe 'instance with preloaded count' do
    let(:post) { Post.preload_comment_counts.first }

    it "should be able to get the association count" do
      post.comments_count.should equal(10)
    end

    context "when association is polymorphic" do
      let(:post) { Post.preload_vote_counts.first }
      it "should be able to get the association count" do
        post.votes_count.should equal(5)
      end
    end

    context "when association has class_name" do
      let(:post) { Post.preload_active_comment_counts.first }
       it "should be able to get the association count" do
        post.active_comments_count.should equal(5)
      end
    end

    context "when association has foreign_key" do
      let(:post) { Post.preload_share_counts.first }
       it "should be able to get the association count" do
        post.shares_count.should equal(5)
      end
    end

  end
end
