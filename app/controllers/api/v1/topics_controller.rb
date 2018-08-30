class Api::V1::TopicsController < Api::V1Controller
  LIMIT = 30

  api :GET, '/topics', 'List topics'
  param :page, :pagination, required: false
  param :limit, :pagination, required: false, desc: "#{LIMIT} maximum"
  param :forum, %w[all] + Forum::VARIANTS, required: true
  def index
    @limit = [[params[:limit].to_i, 1].max, LIMIT].min
    @page = [params[:page].to_i, 1].max

    @forum = Forum.find_by_permalink params[:forum]
    @topics = Topics::Query.fetch(current_user, locale_from_host)
      .by_forum(@forum, current_user, censored_forbidden?)
      .includes(:forum, :user)
      .offset(@limit * (@page - 1))
      .limit(@limit + 1)
      .as_views(true, false)

    respond_with @topics, each_serializer: TopicSerializer
  end

  api :GET, '/topics/updates', 'NewsTopics about database updates'
  param :page, :pagination, required: false
  param :limit, :pagination, required: false, desc: "#{LIMIT} maximum"
  def updates
    @limit = [[params[:limit].to_i, 1].max, LIMIT].min
    @page = [params[:page].to_i, 1].max

    respond_with map_updates(updates_scope)
  end

  # AUTO GENERATED LINE: REMOVE THIS TO PREVENT REGENARATING
  api :GET, '/topics/:id', 'Show a topic'
  def show
    @topic = Topics::TopicViewFactory.new(false, false).find params[:id]
    respond_with @topic, serializer: TopicSerializer
  end

private

  def map_updates topics
    topics.map do |topic|
      {
        id: topic.id,
        linked: linked(topic),
        event: topic.action,
        episode: (topic.value.to_i if topic.present?),
        created_at: topic.created_at,
        url: UrlGenerator.instance.topic_url(topic)
      }
    end
  end

  def updates_scope
    Topic
      .where(
        locale: locale_from_host,
        generated: true,
        linked_type: [Anime.name, Manga.name, Ranobe.name]
      )
      .order(created_at: :desc)
      .offset(@limit * (@page - 1))
      .limit(@limit + 1)
      .order(created_at: :desc)
      .includes(:forum, :linked)
  end

  def linked topic
    if topic.linked.anime?
      AnimeSerializer.new topic.linked
    else
      MangaSerializer.new topic.linked
    end
  end
end
