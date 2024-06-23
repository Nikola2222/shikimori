describe Animes::Filters::Policy do
  let(:params) do
    {
      achievement:,
      censored:,
      franchise:,
      genre:,
      genre_v2:,
      ids:,
      kind:,
      mylist:,
      publisher:,
      rating:,
      studio:,
      search:,
      q:,
      phrase:
    }
  end
  let(:achievement) { nil }
  let(:censored) { nil }
  let(:franchise) { nil }
  let(:genre) { nil }
  let(:genre_v2) { nil }
  let(:ids) { nil }
  let(:kind) { nil }
  let(:mylist) { nil }
  let(:publisher) { nil }
  let(:rating) { nil }
  let(:studio) { nil }
  let(:search) { nil }
  let(:q) { nil }
  let(:phrase) { nil }

  let(:no_hentai) { Animes::Filters::Policy.exclude_hentai? params }
  let(:no_music) { Animes::Filters::Policy.exclude_music? params }

  describe 'no params' do
    it { expect(no_hentai).to eq true }
    it { expect(no_music).to eq true }
  end

  describe 'achievement' do
    let(:achievement) { 'zzzz' }

    it { expect(no_hentai).to eq false }
    it { expect(no_music).to eq false }
  end

  describe 'censored' do
    context 'truthy except of TRUE_CONDITIONAL' do
      let(:censored) do
        (
          Animes::Filters::Policy::TRUTHY -
            [Animes::Filters::Policy::TRUE_CONDITIONAL]
        ).sample
      end

      it { expect(no_hentai).to eq true }
      it { expect(no_music).to eq true }
    end

    context 'falsy' do
      let(:censored) { described_class::FALSY.sample }

      it { expect(no_hentai).to eq false }
      it { expect(no_music).to eq false }
    end

    context 'TRUE_CONDITIONAL' do
      let(:censored) { Animes::Filters::Policy::TRUE_CONDITIONAL }

      it { expect(no_hentai).to eq true }
      it { expect(no_music).to eq true }

      describe 'achievement' do
        let(:achievement) { 'zzzz' }

        it { expect(no_hentai).to eq false }
        it { expect(no_music).to eq false }
      end

      describe 'studio' do
        let(:studio) { 'zzzz' }

        it { expect(no_hentai).to eq false }
        it { expect(no_music).to eq false }
      end

      describe 'search' do
        let(:search) { 'zzzz' }

        it { expect(no_hentai).to eq false }
        it { expect(no_music).to eq false }
      end

      describe 'q' do
        let(:q) { 'zzzz' }

        it { expect(no_hentai).to eq false }
        it { expect(no_music).to eq false }
      end

      describe 'phrase' do
        let(:search) { 'zzzz' }

        it { expect(no_hentai).to eq false }
        it { expect(no_music).to eq false }
      end

      describe 'ids' do
        let(:ids) { 'zzzz' }

        it { expect(no_hentai).to eq false }
        it { expect(no_music).to eq false }
      end

      describe 'mylist' do
        let(:mylist) { 'zzzz' }

        it { expect(no_hentai).to eq false }
        it { expect(no_music).to eq false }
      end

      describe 'publisher' do
        let(:publisher) { 'zzzz' }

        it { expect(no_hentai).to eq false }
        it { expect(no_music).to eq false }
      end
    end
  end

  describe 'franchise' do
    let(:franchise) { 'zzzz' }

    it { expect(no_hentai).to eq false }
    it { expect(no_music).to eq false }

    context '!zzz' do
      let(:franchise) { '!zzz' }

      it { expect(no_hentai).to eq true }
      it { expect(no_music).to eq true }
    end

    context '!zzz,xxx' do
      let(:franchise) { '!zzz,xxx' }

      it { expect(no_hentai).to eq false }
      it { expect(no_music).to eq false }
    end

    context '!zzz,!xxx' do
      let(:franchise) { '!zzz,!xxx' }

      it { expect(no_hentai).to eq true }
      it { expect(no_music).to eq true }
    end
  end

  describe 'kind' do
    describe 'music' do
      context 'music' do
        let(:kind) do
          [
            Types::Anime::Kind[:music],
            'music',
            'tv,music'
          ].sample
        end

        it { expect(no_hentai).to eq true }
        it { expect(no_music).to eq false }
      end

      context 'not music' do
        let(:kind) do
          [
            nil,
            'tv',
            '!music',
            'tv,!music'
          ].sample
        end

        it { expect(no_hentai).to eq true }
        it { expect(no_music).to eq true }
      end
    end

    describe 'doujin' do
      context 'doujin' do
        let(:kind) do
          [
            Types::Manga::Kind[:doujin],
            'doujin',
            'manga,doujin'
          ].sample
        end

        it { expect(no_hentai).to eq false }
        it { expect(no_music).to eq true }
      end

      context 'not doujin' do
        let(:kind) do
          [
            nil,
            'tv',
            '!doujin',
            'manga,!doujin'
          ].sample
        end

        it { expect(no_hentai).to eq true }
        it { expect(no_music).to eq true }
      end
    end
  end

  describe 'genre' do
    let(:hentai_genres) do
      Genre::HENTAI_IDS + Genre::EROTICA_IDS + Genre::YAOI_IDS + Genre::YURI_IDS
    end
    context 'hentai, yaoi or yuri' do
      let(:genre) do
        [
          hentai_genres.sample.to_s,
          "#{hentai_genres.sample},!#{hentai_genres.sample}",
          "!#{hentai_genres.sample},#{hentai_genres.sample}"
        ].sample
      end

      it { expect(no_hentai).to eq false }
      it { expect(no_music).to eq true }
    end

    context 'other' do
      let(:genre) do
        [
          'z',
          "!#{hentai_genres.sample}",
          "#{hentai_genres.max}1",
          (hentai_genres.max + 1).to_s
        ].sample
      end

      it { expect(no_hentai).to eq true }
      it { expect(no_music).to eq true }
    end
  end

  describe 'genre_v2' do
    let(:hentai_genre_v2s) do
      GenreV2::HENTAI_IDS + GenreV2::EROTICA_IDS # + GenreV2::YAOI_IDS + GenreV2::YURI_IDS
    end
    context 'hentai, yaoi or yuri' do
      let(:genre_v2) do
        [
          hentai_genre_v2s.sample.to_s,
          "#{hentai_genre_v2s.sample},!#{hentai_genre_v2s.sample}",
          "!#{hentai_genre_v2s.sample},#{hentai_genre_v2s.sample}"
        ].sample
      end

      it { expect(no_hentai).to eq false }
      it { expect(no_music).to eq true }
    end

    context 'other' do
      let(:genre_v2) do
        [
          'z',
          "!#{hentai_genre_v2s.sample}",
          "#{hentai_genre_v2s.max}1",
          (hentai_genre_v2s.max + 1).to_s
        ].sample
      end

      it { expect(no_hentai).to eq true }
      it { expect(no_music).to eq true }
    end
  end

  describe 'ids' do
    let(:ids) { 'zzzz' }

    it { expect(no_hentai).to eq false }
    it { expect(no_music).to eq false }
  end

  describe 'mylist' do
    let(:mylist) { 'zzzz' }

    it { expect(no_hentai).to eq false }
    it { expect(no_music).to eq false }
  end

  describe 'publisher' do
    let(:publisher) { 'zzzz' }

    it { expect(no_hentai).to eq false }
    it { expect(no_music).to eq false }
  end

  describe 'rating' do
    context 'rx || r_plus' do
      let(:rating) do
        [
          DbEntry::CensoredPolicy::ADULT_RATING,
          DbEntry::CensoredPolicy::SUB_ADULT_RATING,
          DbEntry::CensoredPolicy::ADULT_RATING.to_s,
          "#{DbEntry::CensoredPolicy::ADULT_RATING},#{DbEntry::CensoredPolicy::SUB_ADULT_RATING}",
          "#{DbEntry::CensoredPolicy::ADULT_RATING},!#{DbEntry::CensoredPolicy::SUB_ADULT_RATING}",
          "!#{DbEntry::CensoredPolicy::ADULT_RATING},#{DbEntry::CensoredPolicy::SUB_ADULT_RATING}",
          "#{Types::Anime::Rating[:g]},#{DbEntry::CensoredPolicy::ADULT_RATING},",
          "#{DbEntry::CensoredPolicy::ADULT_RATING},#{Types::Anime::Rating[:g]}"
        ].sample
      end

      it { expect(no_hentai).to eq false }
      it { expect(no_music).to eq true }
    end

    context 'other' do
      let(:rating) do
        [
          "!#{DbEntry::CensoredPolicy::SUB_ADULT_RATING}",
          "#{Types::Anime::Rating[:g]},!#{DbEntry::CensoredPolicy::ADULT_RATING}",
          "!#{DbEntry::CensoredPolicy::ADULT_RATING},#{Types::Anime::Rating[:g]}",
          Types::Anime::Rating[:g],
          Types::Anime::Rating[:g].to_s
        ].sample
      end

      it { expect(no_hentai).to eq true }
      it { expect(no_music).to eq true }
    end
  end

  describe 'studio' do
    let(:studio) { 'zzzz' }

    it { expect(no_hentai).to eq false }
    it { expect(no_music).to eq false }
  end

  describe 'search' do
    let(:search) { 'zzzz' }

    it { expect(no_hentai).to eq false }
    it { expect(no_music).to eq false }
  end

  describe 'q' do
    let(:q) { 'zzzz' }

    it { expect(no_hentai).to eq false }
    it { expect(no_music).to eq false }
  end

  describe 'phrase' do
    let(:search) { 'zzzz' }

    it { expect(no_hentai).to eq false }
    it { expect(no_music).to eq false }
  end
end
