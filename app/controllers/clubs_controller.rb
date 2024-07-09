class ClubsController < ShikimoriController
  include CanCanGet404Concern

  load_and_authorize_resource :club, only: %i[new create]
  before_action :fetch_resource, if: :resource_id
  authorize_resource :club, except: %i[index autocomplete new create]

  before_action :resource_redirect, if: :resource_id

  before_action :set_breadcrumbs
  before_action :restrict_private, if: :resource_id
  before_action { og page_title: i18n_i('Club', :other) }

  UPDATE_PARAMS = [
    :name,
    :join_policy,
    :description,
    :display_images,
    :comment_policy,
    :topic_policy,
    :page_policy,
    :image_upload_policy,
    :logo,
    :is_censored,
    :is_private,
    anime_ids: [],
    manga_ids: [],
    ranobe_ids: [],
    character_ids: [],
    club_ids: [],
    admin_ids: [],
    collection_ids: [],
    banned_user_ids: []
  ]
  RESTRICTED_PARAMS = %i[is_non_thematic is_shadowbanned]
  CREATE_PARAMS = %i[owner_id] + UPDATE_PARAMS

  RESTRICTED_FILTERS = %i[is_censored is_private is_non_thematic is_shadowbanned]
  MEMBERS_LIMIT = 48

  def index
    og noindex: true
    @limit = params[:limit].to_i.clamp(24, 48)

    is_skip_restrictions = can?(:manage_restrictions, Club) &&
      RESTRICTED_FILTERS.any? { |field| params[field].blank? }
    scope = Clubs::Query.fetch current_user, is_skip_restrictions

    if params[:search].blank?
      @favourites = scope.favourites if @page == 1
      scope = scope.without_favourites
    end

    if is_skip_restrictions
      RESTRICTED_FILTERS.each do |field|
        scope = scope.where(field => true) if params[field].present?
      end
    end

    @collection = scope
      .search(params[:search])
      .paginate(@page, @limit)
  end

  def show
    og noindex: true
  end

  def new
    og page_title: i18n_t('new_club')
    @resource = @resource.decorate
  end

  def create
    @resource = Club::Create.call create_params

    if @resource.errors.blank?
      redirect_to edit_club_url(@resource, section: 'main'),
        notice: i18n_t('club_created')
    else
      new
      render :new
    end
  end

  def edit
    @section = params[:section]
    if @section == 'pages'
      authorize! :edit_pages, @resource
    else
      authorize! :edit, @resource
    end

    og page_title: t(:settings)
    og page_title: t("clubs.page.pages.#{@section}")
  end

  def update
    Club::Update.call(
      @resource,
      params[:kick_ids],
      update_params,
      params[:section],
      current_user
    )

    if @resource.errors.blank?
      redirect_to edit_club_url(@resource, section: params[:section]),
        notice: t('changes_saved')
    else
      flash[:alert] = t('changes_not_saved')
      edit
      render :edit
    end
  end

  def members
    og noindex: true
    og page_title: i18n_t('club_members')

    scope = @resource.all_member_roles

    @collection = QueryObjectBase.new(scope)
      .paginate(@page, MEMBERS_LIMIT)
      .lazy_map(&:user)
  end

  def animes
    @collection = @resource.paginated_animes
    redirect_to club_url(@resource) if @collection.none?

    @is_list = cookies['club_animes'] == 'list'

    og noindex: true
    og page_title: i18n_t('club_anime')
  end

  def mangas
    @collection = @resource.paginated_mangas
    redirect_to club_url(@resource) if @collection.none?

    @is_list = cookies['club_mangas'] == 'list'

    og noindex: true
    og page_title: i18n_t('club_manga')
  end

  def ranobe
    @collection = @resource.paginated_ranobe
    redirect_to club_url(@resource) if @collection.none?

    @is_list = cookies['club_ranobe'] == 'list'

    og noindex: true
    og page_title: i18n_t('club_ranobe')
  end

  def characters
    @collection = @resource.paginated_characters
    redirect_to club_url(@resource) if @collection.none?

    og noindex: true
    og page_title: i18n_t('club_characters')
  end

  def clubs
    @collection = @resource.paginated_clubs
    redirect_to club_url(@resource) if @collection.none?

    og noindex: true
    og page_title: i18n_t('club_clubs')
  end

  def collections
    @collection = @resource.paginated_collections
    redirect_to club_url(@resource) if @collection.none?

    @collection = @collection.lazy_map do |collection|
      Topics::TopicViewFactory.new(true, true).build collection.maybe_topic
    end

    og noindex: true
    og page_title: i18n_t('club_collections')
  end

  def images
    og noindex: true
    og page_title: i18n_t('club_images')
  end

  def autocomplete
    @collection = Clubs::Query.fetch(current_user, false)
      .search(params[:search])
      .paginate(1, CompleteQuery::AUTOCOMPLETE_LIMIT)
      .reverse
  end

private

  def restrict_private
    return unless @club.private?

    is_access_allowed = user_signed_in? && (
      @resource.member?(current_user) ||
      current_user.forum_moderator? ||
      can?(:manage, @resource)
    )

    render :private_access unless is_access_allowed
  end

  def not_found_error error
    club = @club || @resource

    if club && error.is_a?(CanCan::AccessDenied) && club.is_private && !club.shadowbanned?
      render :private
    else
      super
    end
  end

  def resource_klass
    Club
  end

  def set_breadcrumbs
    breadcrumb i18n_i('Club', :other), clubs_url

    if resource_id.present? && params[:action] != 'show'
      breadcrumb @resource.name, club_url(@resource)
    end
  end

  def create_params
    params.require(:club).permit(*CREATE_PARAMS)
  rescue ActionController::ParameterMissing
    {}
  end
  alias new_params create_params

  def update_params
    params
      .require(:club)
      .permit(*(UPDATE_PARAMS + (can?(:manage_restrictions, Club) ? RESTRICTED_PARAMS : [])))
  rescue ActionController::ParameterMissing
    {}
  end
end
