module CollectionsConcern
  extend ActiveSupport::Concern

  included do |klass|
    has_many :collection_links, -> { where linked_type: klass.name },
      foreign_key: :linked_id,
      dependent: :destroy

    has_many :collections, through: :collection_links
  end
end
