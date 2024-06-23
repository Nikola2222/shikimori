FactoryBot.define do
  factory :user_preferences do
    user { seed :user }
    list_privacy { :public }
    comment_policy { 'users' }
    dashboard_type { 'new' }
    forums do
      [
        Topic::FORUM_IDS['Critique'],
        Topic::FORUM_IDS['Anime'],
        Topic::FORUM_IDS['Contest'],
        Topic::FORUM_IDS['Group'],
        Topic::FORUM_IDS['CosplayGallery']
      ]
    end
    is_show_age { true }
    is_view_censored { false }
    is_enlarged_favourites_in_profile { false }
    is_shiki_editor { true }
  end
end
