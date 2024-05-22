# TODO: move forum topics actions to Forum::TopicsController other actions should stay here
class TopicsController < ShikimoriController # rubocop:disable Metris/ClassLength
  before_action :check_post_permission, only: %i[create update destroy]

  load_and_authorize_resource class: Topic,
    only: %i[new create edit update destroy]

  before_action :fetch_resource, only: %i[show tooltip moderation reload]
  before_action :set_view
  before_action :set_breadcrumbs

  UPDATE_PARAMS = %i[body title linked_id linked_type tags]
  CREATE_PARAMS = UPDATE_PARAMS + %i[user_id forum_id type]

  def index # rubocop:disable AbcSize
    og noindex: true if params[:search].present?

    if params[:linked_id]
      # редирект на топик, если топик в подфоруме единственный
      if @forums_view.topic_views.one?
        ensure_redirect! UrlGenerator.instance.topic_url(@forums_view.topic_views.first.topic)
      end

      # редирект, исправляющий linked
      ensure_redirect! UrlGenerator.instance.forum_url(@forums_view.forum, @forums_view.linked)

      raise ForceRedirect, @forums_view.current_page_url if @forums_view.linked.is_a?(Club)
    end
  end

  def show
    return redirect_to @forums_view.redirect_url if @forums_view.hidden?
    raise ActiveRecord::RecordNotFound if linked_resource_banned?

    ensure_redirect! UrlGenerator.instance.topic_url(@resource)
    og noindex: true if noindex?
    og canonical_url: @topic_view&.canonical_url
  end

  def tooltip
    @topic_view = Topics::TopicViewFactory.new(true, true).build @resource

    if request.xhr?
      render(
        partial: 'topics/topic',
        object: @topic_view,
        as: :topic_view,
        layout: false,
        formats: :html
      )
    else
      og noindex: true
      render :show
    end
  end

  def moderation
    authorize! :manage, Ban

    render partial: 'moderation', locals: { moderatable: @resource }
  end

  def chosen
    @collection = Topic
      .where(id: params[:ids].split(',').map(&:to_i))
      .filter { |topic| can? :read, topic }
      .map { |topic| Topics::TopicViewFactory.new(true, false).build topic }

    render :collection, formats: :json
  end

  def reload
    @topic_view = Topics::TopicViewFactory
      .new(params[:is_preview] == 'true', params[:is_mini] == 'true')
      .build(@resource)

    render :show, formats: :json
  end

  def new
    topic_type_policy = Topic::TypePolicy.new(@resource)
    topic_type =
      if @resource.forum == Forum.critiques
        :critique
      elsif @resource.forum == Forum.articles
        :article
      elsif topic_type_policy.news_topic?
        :news
      else
        :topic
      end

    og page_title: i18n_t("new_#{topic_type}")
  end

  def edit
    ensure_redirect! @topic_view.urls.edit_url if params[:action] == 'edit'
  end

  def create
    @resource = Topic::Create.call(
      faye:,
      params: topic_params
    )

    if @resource.persisted?
      redirect_to(
        UrlGenerator.instance.topic_url(@resource),
        notice: i18n_t('topic.created')
      )
    else
      new
      flash[:alert] = t('changes_not_saved')
      render :new
    end
  end

  def update
    is_updated = Topic::Update.call @resource, topic_params, faye

    if is_updated
      redirect_to(
        UrlGenerator.instance.topic_url(@resource),
        notice: i18n_t('topic.updated')
      )
    else
      edit
      flash[:alert] = t('changes_not_saved')
      render :edit
    end
  end

  def destroy
    Topic::Destroy.call @resource, faye

    render json: { notice: i18n_t('topic.deleted') }
  end

private

  def topic_params # rubocop:disable all
    allowed_params =
      if can?(:moderate, @resource || Topic) ||
          can?(:full_update, @resource || Topic) ||
          %w[new create].include?(params[:action])
        CREATE_PARAMS
      else
        UPDATE_PARAMS
      end

    allowed_params += [:broadcast] if can?(:broadcast, @resource || Topic)
    allowed_params += [:is_closed] if can?(:close, @resource || Topic)
    allowed_params += [:is_pinned] if can?(:pin, @resource || Topic)

    params.require(:topic).permit(*allowed_params).tap do |fixed_params|
      fixed_params[:body] = Topics::ComposeBody.call(params[:topic])

      unless fixed_params[:tags].nil?
        fixed_params[:tags] = fixed_params[:tags].split(',').map(&:strip).select(&:present?)
      end
    end
  end

  def set_view
    @forums_view = Forums::View.new params[:forum]

    if %w[show edit].include?(params[:action]) && @resource
      @topic_view = Topics::TopicViewFactory.new(false, false).build @resource
    end
  end

  def set_breadcrumbs
    og page_title: t('page', page: @page) if @page > 1
    og page_title: i18n_t('title')
    breadcrumb t('forum'), forum_url

    if @resource&.forum
      og page_title: @resource.forum.name
      breadcrumb @resource.forum.name, forum_topics_url(@resource.forum)

      if @forums_view.linked
        breadcrumb(
          UsersHelper.localized_name(@forums_view.linked, current_user),
          UrlGenerator.instance.forum_url(
            @forums_view.forum, @forums_view.linked
          )
        )
      end

      og page_title: @topic_view ? @topic_view.topic_title : @resource.title
      if %w[edit update].include? params[:action]
        breadcrumb(
          @topic_view ? @topic_view.topic_title : @resource.title,
          UrlGenerator.instance.topic_url(@resource)
        )
      end

    elsif @forums_view.forum
      og page_title: @forums_view.forum.name
      if params[:action] != 'index' || @forums_view.linked
        breadcrumb @forums_view.forum.name, forum_topics_url(@forums_view.forum)
      end

      if @forums_view.linked
        og(
          page_title: UsersHelper.localized_name(
            @forums_view.linked,
            current_user
          )
        )
      end
    end
  end

  def fetch_resource
    @resource = Topic.find_by(id: params[:id]) || nil_object
    raise ActiveRecord::RecordNotFound if request.format.rss?

    authorize_access! unless nil_object?
    check_censored! unless nil_object?

    render :missing, status: (xhr_or_json? ? :ok : :not_found) if nil_object?
  end

  def authorize_access!
    authorize! :read, @resource
  rescue CanCan::AccessDenied
    @resource = nil_object
  end

  def check_censored!
    if (@resource&.try(:censored?) || @resource&.linked.try(:censored?)) &&
        censored_forbidden?
      raise AgeRestricted
    end
  end

  def nil_object
    NoTopic.new id: params[:id].to_i
  end

  def nil_object?
    @resource.is_a? NoTopic
  end

  def faye
    FayeService.new current_user, faye_token
  end

  def noindex?
    nil_object? || (@resource.generated? && @resource.comments_count.zero?)
  end

  def copyrighted_resource_id_key
    :linked_id
  end

  def linked_resource_banned?
    linked = @forums_view.linked || @resource&.linked
    linked.respond_to?(:genres_v2) && linked.banned? && !current_user&.staff?
  end
end
