describe User do
  describe 'relations' do
    it { is_expected.to have_one(:preferences).dependent(:destroy) }

    it { is_expected.to have_many :oauth_applications }
    it { is_expected.to have_many :access_grants }
    it { is_expected.to have_many :access_tokens }
    it { is_expected.to have_many :user_tokens }

    it { is_expected.to have_many(:achievements).dependent(:destroy) }
    it { is_expected.to have_many(:anime_rates).dependent(:destroy) }
    it { is_expected.to have_many(:manga_rates).dependent(:destroy) }
    it { is_expected.to have_many(:user_rate_logs).dependent(:destroy) }

    it { is_expected.to have_many(:topic_viewings).dependent(:delete_all) }
    it { is_expected.to have_many(:comment_viewings).dependent(:delete_all) }

    it { is_expected.to have_many(:history).dependent(:destroy) }

    it { is_expected.to have_many(:friend_links).dependent(:destroy) }
    it { is_expected.to have_many :friends }

    it { is_expected.to have_many(:favourites).dependent(:destroy) }

    it { is_expected.to have_many(:abuse_requests).dependent(:destroy) }
    it { is_expected.to have_many(:messages).dependent(:destroy) }
    it { is_expected.to have_many(:messages_from).dependent(:destroy) }
    it { is_expected.to have_many :comments }

    it { is_expected.to have_many(:critiques).dependent(:destroy) }
    it { is_expected.to have_many(:reviews).dependent(:destroy) }

    it { is_expected.to have_many(:ignores).dependent(:destroy) }
    it { is_expected.to have_many :ignored_users }

    it { is_expected.to have_many(:club_roles).dependent(:destroy) }
    it { is_expected.to have_many :club_admin_roles }
    it { is_expected.to have_many :clubs }
    it { is_expected.to have_many(:clubs_owned).dependent(:destroy) }
    it { is_expected.to have_many(:club_images).dependent(:destroy) }

    it { is_expected.to have_many(:collections).dependent(:destroy) }
    it { is_expected.to have_many(:collection_roles).dependent(:destroy) }
    it { is_expected.to have_many(:articles).dependent(:destroy) }

    it { is_expected.to have_many(:versions).dependent(:destroy) }

    it { is_expected.to have_many :topics }
    it { is_expected.to have_many(:topic_ignores).dependent(:destroy) }
    it { is_expected.to have_many :ignored_topics }

    it { is_expected.to have_many(:nickname_changes).dependent(:destroy) }
    it { is_expected.to have_many(:recommendation_ignores).dependent(:destroy) }

    it { is_expected.to have_many :bans }
    it { is_expected.to have_many :club_bans }

    it { is_expected.to have_many :user_images }

    it { is_expected.to have_many :anime_video_reports }
    it { is_expected.to have_many(:list_imports).dependent(:destroy) }
    it { is_expected.to have_many(:polls).dependent(:destroy) }

    it { is_expected.to belong_to(:style).optional }
    it { is_expected.to have_many(:styles).dependent(:destroy) }
  end

  describe 'enumerize' do
    it { is_expected.to enumerize(:roles).in(*Types::User::Roles.values) }
    it { is_expected.to enumerize(:locale).in(*Types::Locale.values).with_default(:ru) }
    it { is_expected.to enumerize(:notification_settings).in(*Types::User::NotificationSettings.values) }
  end

  let(:user_2) { create :user }
  let(:topic) { create :topic }

  describe 'callbacks' do
    describe '#fill_notification_settings' do
      let(:user) { User.new }
      it { expect(user.notification_settings).to eq Types::User::NotificationSettings.values }
    end

    describe '#create_preferences!' do
      it { expect(user.preferences).to be_persisted }
    end

    describe '#assign_style' do
      let(:user) { create :user, :with_assign_style }
      it do
        expect(user.reload.style).to be_persisted
        expect(user.style).to have_attributes css: '', name: ''
        expect(user.styles.first).to eq user.style
        expect(user.styles).to have(1).item
      end
    end

    # it 'creates registration history entry' do
      # user.history.is_expected.to have(1).item
      # user.history.first.action.is_expected.to eq UserHistoryAction::REGISTRATION
    # end

    describe '#log_nickname_change' do
      let(:user) { create :user, nickname: 'old_nickname' }
      after { user.update nickname: 'test' }
      it do
        expect(Users::LogNicknameChange).to receive(:call).with(
          user, 'old_nickname'
        )
      end
    end
  end

  describe 'instance methods' do
    describe '#nickname=' do
      let(:user) { build :user, nickname: }
      let(:nickname) { '#[test]%&?+@' }

      it { expect(user.nickname).to eq FixName.call(nickname, true) }
    end

    describe '#can_post' do
      before { user.read_only_at = read_only_at }
      subject { user.can_post? }

      context 'no ban' do
        let(:read_only_at) { nil }
        it { is_expected.to eq true }
      end

      context 'expired ban' do
        let(:read_only_at) { 1.second.ago }
        it { is_expected.to eq true }
      end

      context 'valid ban' do
        let(:read_only_at) { 1.second.from_now }
        it { is_expected.to eq false }
      end
    end

    describe '#ignores?' do
      it do
        user.ignored_users << user_2
        expect(user.ignores?(user_2)).to eq true
      end

      it do
        expect(user.ignores?(user_2)).to eq false
      end
    end

    describe '#banned?' do
      let(:read_only_at) { nil }
      subject { create :user, read_only_at: }

      it { is_expected.to_not be_banned }

      describe 'true' do
        let(:read_only_at) { 1.hour.from_now }
        it { is_expected.to be_banned }
      end

      describe 'false' do
        let(:read_only_at) { 1.second.ago }
        it { is_expected.to_not be_banned }
      end
    end

    describe '#active?' do
      subject(:user) do
        build :user,
          last_online_at:,
          last_sign_in_at:
      end

      let(:last_sign_in_at) { nil }
      let(:last_online_at) { nil }

      it { is_expected.to_not be_active }

      describe 'last_sign_in_at > ACTIVE_SITE_USER_INTERVAL' do
        let(:last_sign_in_at) { User::ACTIVE_SITE_USER_INTERVAL.ago + 1.minute }
        it { is_expected.to be_active }
      end

      describe 'last_sign_in_at < ACTIVE_SITE_USER_INTERVAL' do
        let(:last_sign_in_at) { User::ACTIVE_SITE_USER_INTERVAL.ago - 1.minute }
        it { is_expected.to_not be_active }
      end

      describe 'last_online_at > ACTIVE_SITE_USER_INTERVAL' do
        let(:last_online_at) { User::ACTIVE_SITE_USER_INTERVAL.ago + 1.minute }
        it { is_expected.to be_active }
      end

      describe 'last_online_at < ACTIVE_SITE_USER_INTERVAL' do
        let(:last_online_at) { User::ACTIVE_SITE_USER_INTERVAL.ago - 1.minute }
        it { is_expected.to_not be_active }
      end
    end

    describe '#friended?' do
      subject { user.friended? user_2 }
      let(:user_2) { build_stubbed :user }

      context 'friended' do
        let(:user) { build_stubbed :user, friend_links: [build_stubbed(:friend_link, dst: user_2)] }
        it { is_expected.to be true }
      end

      context 'not friended' do
        it { is_expected.to be false }
      end
    end

    describe '#forever_banned?' do
      let(:user) { build :user, read_only_at: }

      context 'banned not long ago' do
        let(:read_only_at) { 11.months.from_now }
        it { expect(user.forever_banned?).to be false }
      end

      context 'not banned' do
        let(:read_only_at) { nil }
        it { expect(user.forever_banned?).to be false }
      end

      context 'banned long ago' do
        let(:read_only_at) { 13.months.from_now }
        it { expect(user.forever_banned?).to be true }
      end
    end

    describe '#day_registered?' do
      let(:user) { build :user, created_at: }

      context 'created_at not day ago' do
        let(:created_at) { 23.hours.ago }
        it { expect(user.day_registered?).to be false }
      end

      context 'created_at day ago' do
        let(:created_at) { 25.hours.ago }
        it { expect(user.day_registered?).to be true }
      end
    end

    describe '#week_registered?' do
      let(:user) { build :user, created_at: }

      context 'created_at not week ago' do
        let(:created_at) { 6.days.ago }
        it { expect(user.week_registered?).to be false }
      end

      context 'created_at week ago' do
        let(:created_at) { 8.days.ago }
        it { expect(user.week_registered?).to be true }
      end
    end

    describe '#staff?' do
      let(:user) { build :user, roles: [role] }

      context 'staff' do
        let(:role) { User::STAFF_ROLES.sample }
        it { expect(user).to be_staff }
      end

      context 'not staff' do
        let(:role) { (Types::User::ROLES.map(&:to_s) - User::STAFF_ROLES).sample }
        it { expect(user).to_not be_staff }
      end
    end

    describe '#moderation_versions?' do
      let(:user) { build :user, roles: [role] }

      context 'moderation_versions' do
        let(:role) { User::MODERATION_VERSIONS_ROLES.sample }
        it { expect(user).to be_moderation_versions }
      end

      context 'not moderation_versions' do
        let(:role) { (Types::User::ROLES.map(&:to_s) - User::MODERATION_VERSIONS_ROLES).sample }
        it { expect(user).to_not be_moderation_versions }
      end
    end

    describe '#moderation_staff?' do
      let(:user) { build :user, roles: [role] }

      context 'moderation staff' do
        let(:role) { User::MODERATION_STAFF_ROLES.sample }
        it { expect(user).to be_moderation_staff }
      end

      context 'not staff' do
        let(:role) { (Types::User::ROLES.map(&:to_s) - User::MODERATION_STAFF_ROLES).sample }
        it { expect(user).to_not be_moderation_staff }
      end
    end

    describe '#faye_channels' do
      it { expect(user.faye_channels).to eq %W[/private-#{user.id}] }
    end

    describe '#generated_email?' do
      let(:user) { build :user, email: }

      context 'generated' do
        let(:email) { "generated_12312@#{Shikimori::DOMAIN}" }
        it { expect(user).to be_generated_email }
      end

      context 'not generated' do
        let(:email) { "qwe123@#{Shikimori::DOMAIN}" }
        it { expect(user).to_not be_generated_email }
      end
    end

    describe '#excluded_from_statistics?' do
      before { subject.roles = roles }

      context 'has no excluded role' do
        let(:roles) { [] }
        its(:excluded_from_statistics?) { is_expected.to eq false }
      end

      context 'has excluded role' do
        let(:roles) do
          [
            %i[cheat_bot completed_announced_animes ignored_in_achievement_statistics].sample
          ]
        end
        its(:excluded_from_statistics?) { is_expected.to eq true }
      end
    end

    describe '#age' do
      subject { build :user, birth_on: }

      context 'no age' do
        let(:birth_on) { nil }
        its(:age) { is_expected.to be_nil }
      end

      context '= age - 1' do
        let(:birth_on) { Time.zone.tomorrow - 18.years }
        its(:age) { is_expected.to eq 17 }
      end

      context '= age' do
        let(:birth_on) { Time.zone.today - 18.years }
        its(:age) { is_expected.to eq 18 }
      end
    end

    describe '#censored_forbidden?' do
      let(:user) { build :user, birth_on:, preferences: }

      let(:birth_on) { 18.years.ago - 1.day }
      let(:preferences) { build :user_preferences, is_view_censored: }
      let(:is_view_censored) { true }

      subject { user.censored_forbidden? }

      it { is_expected.to eq false }

      context 'no preferences' do
        let(:preferences) { nil }
        it { is_expected.to eq true }
      end

      context 'disabled censored in preferences' do
        let(:is_view_censored) { false }
        it { is_expected.to eq true }
      end
    end
  end

  describe 'permissions' do
    let(:preferences) { build_stubbed :user_preferences, list_privacy: }
    let(:profile) { build_stubbed :user, :user, preferences: }
    let(:user) { build_stubbed :user, :user }
    let(:friend_link) { build_stubbed :friend_link, dst: user }

    subject { Ability.new user }

    describe 'access_list' do
      context 'public list_privacy' do
        let(:list_privacy) { :public }

        context 'owner' do
          let(:user) { profile }
          it { is_expected.to be_able_to :access_list, profile }
        end

        context 'friend' do
          let(:profile) { build_stubbed :user, :user, friend_links: [friend_link], preferences: }
          it { is_expected.to be_able_to :access_list, profile }
        end

        context 'user' do
          it { is_expected.to be_able_to :access_list, profile }
        end

        context 'guest' do
          let(:user) { nil }
          it { is_expected.to be_able_to :access_list, profile }
        end
      end

      context 'users list_privacy' do
        let(:list_privacy) { :users }

        context 'owner' do
          let(:user) { profile }
          it { is_expected.to be_able_to :access_list, profile }
        end

        context 'friend' do
          let(:profile) { build_stubbed :user, :user, friend_links: [friend_link], preferences: }
          it { is_expected.to be_able_to :access_list, profile }
        end

        context 'user' do
          it { is_expected.to be_able_to :access_list, profile }
        end

        context 'guest' do
          let(:user) { nil }
          it { is_expected.to_not be_able_to :access_list, profile }
        end
      end

      context 'friends list_privacy' do
        let(:list_privacy) { :friends }

        context 'owner' do
          let(:user) { profile }
          it { is_expected.to be_able_to :access_list, profile }
        end

        context 'friend' do
          let(:profile) { build_stubbed :user, :user, friend_links: [friend_link], preferences: }
          it { is_expected.to be_able_to :access_list, profile }
        end

        context 'user' do
          it { is_expected.to_not be_able_to :access_list, profile }
        end

        context 'guest' do
          let(:user) { nil }
          it { is_expected.to_not be_able_to :access_list, profile }
        end
      end

      context 'owner list_privacy' do
        let(:list_privacy) { :owner }

        context 'owner' do
          let(:user) { profile }
          it { is_expected.to be_able_to :access_list, profile }
        end

        context 'friend' do
          let(:profile) { build_stubbed :user, :user, friend_links: [friend_link], preferences: }
          it { is_expected.to_not be_able_to :access_list, profile }
        end

        context 'user' do
          it { is_expected.to_not be_able_to :access_list, profile }
        end

        context 'guest' do
          let(:user) { nil }
          it { is_expected.to_not be_able_to :access_list, profile }
        end
      end
    end

    describe 'access_messages' do
      let(:profile) { build_stubbed :user, :user }

      context 'owner' do
        let(:user) { profile }
        it { is_expected.to be_able_to :access_messages, profile }
      end

      context 'user' do
        it { is_expected.to_not be_able_to :access_messages, profile }
      end

      context 'guest' do
        let(:user) { nil }
        it { is_expected.to_not be_able_to :access_messages, profile }
      end
    end

    describe 'edit & update' do
      let(:profile) { build_stubbed :user, :user }

      context 'own profile' do
        let(:user) { profile }

        it { is_expected.to be_able_to :edit, profile }
        it { is_expected.to be_able_to :update, profile }
      end

      context 'admin' do
        let(:user) { build_stubbed :user, :admin }

        it { is_expected.to be_able_to :edit, profile }
        it { is_expected.to be_able_to :update, profile }
      end

      context 'user' do
        let(:user) { build_stubbed :user, :user }

        it { is_expected.to_not be_able_to :edit, profile }
        it { is_expected.to_not be_able_to :update, profile }
      end

      context 'guest' do
        let(:user) { build_stubbed :user, :guest }

        it { is_expected.to_not be_able_to :edit, profile }
        it { is_expected.to_not be_able_to :update, profile }
      end
    end
  end
end
