class ArtistCommentary < ActiveRecord::Base
  attr_accessible :post_id, :original_description, :original_title, :translated_description, :translated_title
  validates_uniqueness_of :post_id
  belongs_to :post
  has_many :versions, lambda {order("artist_commentary_versions.id ASC")}, :class_name => "ArtistCommentaryVersion", :dependent => :destroy, :foreign_key => :post_id, :primary_key => :post_id
  after_save :create_version

  module SearchMethods
    def text_matches(query)
      query = "*#{query}*" unless query =~ /\*/
      escaped_query = query.to_escaped_for_sql_like
      where("original_title ILIKE ? ESCAPE E'\\\\' OR original_description ILIKE ? ESCAPE E'\\\\' OR translated_title ILIKE ? ESCAPE E'\\\\' OR translated_description ILIKE ? ESCAPE E'\\\\'", escaped_query, escaped_query, escaped_query, escaped_query)
    end

    def post_tags_match(query)
      joins(:post).where("posts.tag_index @@ to_tsquery('danbooru', ?)", query.to_escaped_for_tsquery_split)
    end

    def search(params)
      q = where("true")
      params = {} if params.blank?

      if params[:text_matches].present?
        q = q.text_matches(params[:text_matches])
      end

      if params[:original_present] == "yes"
        q = q.where("(original_title is not null and original_title != '') or (original_description is not null and original_description != '')")
      elsif params[:original_present] == "no"
        q = q.where("(original_title is null or original_title = '') and (original_description is null or original_description = '')")
      end

      if params[:translated_present] == "yes"
        q = q.where("(translated_title is not null and translated_title != '') or (translated_description is not null and translated_description != '')")
      elsif params[:translated_present] == "no"
        q = q.where("(translated_title is null or translated_title = '') and (translated_description is null or translated_description = '')")
      end

      if params[:post_tags_match].present?
        q = q.post_tags_match(params[:post_tags_match])
      end

      q
    end
  end

  extend SearchMethods

  def original_present?
    original_title.present? || original_description.present?
  end

  def translated_present?
    translated_title.present? || translated_description.present?
  end

  def any_field_present?
    original_present? || translated_present?
  end

  def create_version
    versions.create(
      :post_id => post_id,
      :original_title => original_title,
      :original_description => original_description,
      :translated_title => translated_title,
      :translated_description => translated_description
    )
  end

  def revert_to(version)
    self.original_description = version.original_description
    self.original_title = version.original_title
    self.translated_description = version.translated_description
    self.translated_title = version.translated_title
  end

  def revert_to!(version)
    revert_to(version)
    save!
  end
end
