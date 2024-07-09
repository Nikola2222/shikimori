class Api::V1::DialogsController < Api::V1Controller
  MESSAGES_PER_PAGE = 10

  before_action :authorize_messages_access
  before_action :fetch_target_user, only: %i[show destroy]

  before_action do
    doorkeeper_authorize! :messages if doorkeeper_token.present?
  end

  api :GET, '/dialogs', 'List dialogs'
  description 'Requires `messages` oauth scope'
  def index
    @limit = params[:limit].to_i.clamp(MESSAGES_PER_PAGE, MESSAGES_PER_PAGE * 2)

    @collection = DialogsQuery.new(current_user).fetch(@page, @limit)

    respond_with @collection, each_serializer: DialogSerializer
  end

  api :GET, '/dialogs/:id', 'Show a dialog'
  description 'Requires `messages` oauth scope'
  def show
    @limit = params[:limit].to_i.clamp(MESSAGES_PER_PAGE, MESSAGES_PER_PAGE * 2)

    @collection = DialogQuery
      .new(current_user, @target_user)
      .fetch(@page, @limit, false)
      .reverse

    respond_with @collection
  end

  api :DELETE, '/dialogs/:id', 'Destroy a dialog'
  description 'Requires `messages` oauth scope'
  error code: 422
  def destroy
    message = Message.find_by(from: current_user, to: @target_user, kind: MessageType::PRIVATE) ||
      Message.find_by(to: current_user, from: @target_user, kind: MessageType::PRIVATE)

    if message
      Dialog.new(current_user, message).destroy
      render json: { notice: i18n_t('conversation_removed') }
    else
      render json: [i18n_t('no_messages')], status: :unprocessable_entity
    end
  end

private

  def authorize_messages_access
    authorize! :access_messages, current_user
  end

  def fetch_target_user
    @target_user =
      User.find_by(id: params[:id]) ||
      User.find_by!(nickname: User.param_to(params[:id]))
  end
end
