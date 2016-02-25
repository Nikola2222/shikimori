class Api::V1::UserRatesController < Api::V1::ApiController
  respond_to :json
  load_and_authorize_resource

  CREATE_PARAMS = [:target_id, :target_type, :user_id, :status, :episodes, :chapters, :volumes, :score, :text, :rewatches]
  UPDATE_PARAMS = [:status, :episodes, :chapters, :volumes, :score, :text, :rewatches]

  # DOC GENERATED AUTOMATICALLY: REMOVE THIS LINE TO PREVENT REGENARATING NEXT TIME
  api :POST, '/user_rates', 'Create an user rate'
  param :user_rate, Hash do
    param :chapters, :undef
    param :episodes, :undef
    param :rewatches, :undef
    param :score, :undef
    param :status, :undef
    param :target_id, :number
    param :target_type, :undef
    param :text, :undef
    param :user_id, :number
    param :volumes, :undef
  end
  def create
    @user_rate.save rescue PG::Error
    respond_with @user_rate, location: nil
  end

  # DOC GENERATED AUTOMATICALLY: REMOVE THIS LINE TO PREVENT REGENARATING NEXT TIME
  api :PATCH, '/user_rates/:id', 'Update an user rate'
  api :PUT, '/user_rates/:id', 'Update an user rate'
  param :user_rate, Hash do
    param :chapters, :undef
    param :episodes, :undef
    param :rewatches, :undef
    param :score, :undef
    param :status, :undef
    param :text, :undef
    param :volumes, :undef
  end
  def update
    @user_rate.update update_params
    respond_with @user_rate, location: nil
  end

  # DOC GENERATED AUTOMATICALLY: REMOVE THIS LINE TO PREVENT REGENARATING NEXT TIME
  api :POST, '/user_rates/:id/increment'
  def increment
    if @user_rate.anime?
      @user_rate.update episodes: (params[:episodes] || @user_rate.episodes) + 1
    else
      @user_rate.update chapters: (params[:chapters] || @user_rate.chapters) + 1
    end

    respond_with @user_rate
  end

  # DOC GENERATED AUTOMATICALLY: REMOVE THIS LINE TO PREVENT REGENARATING NEXT TIME
  api :DELETE, '/user_rates/:id', 'Destroy an user rate'
  def destroy
    @user_rate.destroy!
    respond_with @user_rate, location: nil
  end

  # очистка списка и истории
  api :DELETE, "/user_rates/:type/cleanup", "Delete entire user rates and history"
  error :code => 302
  def cleanup
    user = current_user.object

    user.history.where(target_type: params[:type].capitalize).delete_all
    user.history.where(action: "mal_#{params[:type]}_import").delete_all
    user.history.where(action: "ap_#{params[:type]}_import").delete_all
    user.send("#{params[:type]}_rates").delete_all
    user.touch

    render json: { notice: i18n_t("list_and_history_cleared.#{params[:type]}") }
  end

  # сброс оценок в списке
  api :DELETE, "/user_rates/:type/reset", "Reset all user scores to 0"
  error :code => 302
  def reset
    current_user.send("#{params[:type]}_rates").update_all score: 0
    current_user.touch

    render json: { notice: i18n_t("scores_reset.#{params[:type]}") }
  end

private

  def create_params
    params.require(:user_rate).permit(*CREATE_PARAMS)
  end

  def update_params
    params.require(:user_rate).permit(*UPDATE_PARAMS)
  end
end
