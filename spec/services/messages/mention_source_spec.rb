describe Messages::MentionSource do
  subject do
    described_class.call linked,
      comment_id:,
      is_simple:
  end
  let(:comment_id) { nil }
  let(:is_simple) { nil }

  context 'nil' do
    let(:linked) { nil }
    it { is_expected.to eq 'в <em>удалено</em>.' }
    it { is_expected.to be_html_safe }

    context 'simple' do
      let(:is_simple) { true }
      it { is_expected.to eq '<em>удалено</em>' }
    end
  end

  context 'Topic' do
    let(:user) { build_stubbed :user, :user }
    let(:linked) { build_stubbed :topic, id: 1, title: 'xx&', user: }
    it do
      is_expected.to eq(
        <<~HTML.squish
          в топике <a href="#{Shikimori::PROTOCOL}://#{Shikimori::DOMAIN}/forum/offtopic/1-xx"
            class="bubbled b-link"
            data-href="#{Shikimori::PROTOCOL}://#{Shikimori::DOMAIN}/forum/offtopic/1-xx/tooltip">xx&amp;</a>.
        HTML
      )
    end

    context 'simple' do
      let(:is_simple) { true }
      it do
        is_expected.to eq(
          <<~HTML.squish
            <a href="#{Shikimori::PROTOCOL}://#{Shikimori::DOMAIN}/forum/offtopic/1-xx"
              class="bubbled b-link"
              data-href="#{Shikimori::PROTOCOL}://#{Shikimori::DOMAIN}/forum/offtopic/1-xx/tooltip">xx&amp;</a>
          HTML
        )
      end
    end
  end

  context 'User' do
    let(:linked) { build_stubbed :user, id: 1, nickname: 'zz' }
    it do
      is_expected.to eq(
        "в профиле пользователя <a href=\"#{Shikimori::PROTOCOL}://#{Shikimori::DOMAIN}/zz\">zz</a>."
      )
    end

    context 'simple' do
      let(:is_simple) { true }
      it do
        is_expected.to eq(
          "<a href=\"#{Shikimori::PROTOCOL}://#{Shikimori::DOMAIN}/zz\">zz</a>"
        )
      end
    end
  end

  context 'Review' do
    let(:linked) { build_stubbed :review, id: 1, anime: }
    let(:anime) { build_stubbed :anime, id: 1, name: 'anime_1' }
    let(:review_url) do
      "#{Shikimori::PROTOCOL}://#{Shikimori::DOMAIN}/animes/1-anime-1/reviews/1"
    end

    it do
      is_expected.to eq(
        <<~HTML.squish
          в отзыве к <a href="#{review_url}" class="bubbled b-link"
            data-href="#{review_url}/tooltip">anime_1</a>.
        HTML
      )
    end

    context 'simple' do
      let(:is_simple) { true }
      it do
        is_expected.to eq(
          <<~HTML.squish
            <a href="#{review_url}" class="bubbled b-link"
              data-href="#{review_url}/tooltip">anime_1</a>
          HTML
        )
      end
    end
  end

  context 'other linked' do
    let(:linked) { build_stubbed :anime, id: 1, name: 'cc' }
    it { expect { subject }.to raise_error ArgumentError, 'Anime 1-cc' }
  end
end
