class CosplayGallery < ActiveRecord::Base
  include Translation

  acts_as_voteable

  belongs_to :user

  has_many :image, -> { where(deleted: false).limit(1) },
    class_name: CosplayImage.name

  has_many :images, -> { where(deleted: false).order(:position) },
    class_name: CosplayImage.name,
    dependent: :destroy

  has_many :deleted_images, -> { where(deleted: true).order(:position) },
    class_name: CosplayImage.name

  has_many :links, class_name: CosplayGalleryLink.name, dependent: :destroy
  has_many :cosplayers,
    through: :links,
    source: :linked,
    source_type: Cosplayer.name

  has_many :animes,
    through: :links,
    source: :linked,
    source_type: Anime.name

  has_many :mangas,
    through: :links,
    source: :linked,
    source_type: Manga.name

  has_many :characters,
    through: :links,
    source: :linked,
    source_type: Character.name

  has_one :topic, -> { where linked_type: CosplayGallery.name },
    class_name: Topics::EntryTopics::CosplayGalleryTopic.name,
    foreign_key: :linked_id,
    dependent: :destroy

  scope :visible, -> { where confirmed: true, deleted: false }

  #after_create :generate_topic
  #after_save :sync_topic

  accepts_nested_attributes_for :images, :deleted_images

  acts_as_taggable_on :tags

  def to_param
    "%d-%s" % [id, target.gsub(/&#\d{4};/, '-').gsub(/[^A-z0-9]+/, '-').gsub(/^-|-$/, '')]
  end

  # копирует все картинки в target, а текущую галерею помечает удалённой
  def move_to(target)
    self.images.each do |image|
      new_image = CosplayImage.create
      image.attributes.each do |k,v|
        next if k == 'id'
        if k == 'image_file_name'
          new_image[k] = v.sub(image.id.to_s, new_image.id.to_s)
        else
          new_image[k] = v
        end
      end
      new_image[:cosplay_gallery_id] = target.id
      FileUtils.cp(image.image.path, new_image.image.path)
      new_image.image.reprocess!
      new_image.save
    end
    self.update_attribute(:deleted, true)
  end

  # полное название галереи
  def name linked = self.send(:any_linked)
    titles = title_components(linked).map { |c| c.map(&:name).to_sentence }

    i18n_t('.title', cosplay: titles.first, cosplayer: titles.second).html_safe
  end

  def title_components linked
    [characters.any? ? characters : [linked], cosplayers]
  end

  # подтверждена ли модератором галерея
  def confirmed?
    confirmed
  end

  # удалена ли модератором галерея
  def deleted?
    deleted
  end

  def self.without_topic
    visible
      .includes(:animes, :mangas, :characters, :topic)
      .select { |v| !v.topic.present? }
      .select { |v| v.animes.any? || v.mangas.any? || v.characters.any? }
  end

private

  def sync_topic
    topic.update_attribute :title, name if topic.title != name
  end

  def generate_topic
    publisher = User.find User::COSPLAYER_ID

    FayeService
      .new(publisher, '')
      .create!(Topics::EntryTopics::CosplayGalleryTopic.new(
        forum_id: Forum::COSPLAY_ID,
        generated: true,
        linked: self,
        user: publisher
      ))
  end

  def any_linked
    animes.first || mangas.first || characters.first
  end
end
