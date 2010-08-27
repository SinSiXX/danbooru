class TagAlias < ActiveRecord::Base
  attr_accessor :creator_ip_addr
  after_save :update_posts
  after_destroy :clear_cache
  validates_presence_of :creator_id, :creator_ip_addr
  validates_uniqueness_of :antecedent_name
  validate :absence_of_transitive_relation
  belongs_to :creator, :class_name => "User"
  
  def self.to_aliased(names)
    alias_hash = Cache.get_multi(names.flatten, "ta") do |name|
      ta = TagAlias.find_by_antecedent_name(name)
      if ta
        ta.consequent_name
      else
        name
      end
    end
    
    alias_hash.values.flatten.uniq
  end
  
  def absence_of_transitive_relation
    # We don't want a -> b && b -> c chains
    if self.class.exists?(["antecedent_name = ?", consequent_name]) || self.class.exists?(["consequent_name = ?", antecedent_name])
      self.errors[:base] << "Tag alias can not create a transitive relation with another tag alias"
      false
    end
  end

  def clear_cache
    Cache.delete("ta:#{Cache.sanitize(antecedent_name)}")
  end
  
  def update_cache
    Cache.put("ta:#{Cache.sanitize(antecedent_name)}", consequent_name)
  end
  
  def update_posts
    Post.find_by_tags(antecedent_name).find_each do |post|
      escaped_antecedent_name = Regexp.escape(antecedent_name)
      fixed_tags = post.tag_string.sub(/(?:\A| )#{escaped_antecedent_name}(?:\Z| )/, " #{consequent_name} ").strip
      
      CurrentUser.scoped(creator, creator_ip_addr) do
        post.update_attributes(
          :tag_string => fixed_tags
        )
      end
    end
  end
end
