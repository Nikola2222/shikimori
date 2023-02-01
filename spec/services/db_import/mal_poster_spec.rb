describe DbImport::MalPoster do
  include_context :timecop

  subject do
    described_class.call(
      entry: entry,
      image_url: image_url
    )
  end
  let(:entry) { create :anime }
  let(:image_url) { 'https://cdn.myanimelist.net/images/anime/3/72078l.jpg' }
  let!(:prev_poster) { create :poster, anime: entry }

  before do
    allow(DbImport::PosterPolicy)
      .to receive(:new)
      .with(entry: entry, image_url: image_url)
      .and_return(poster_policy)

    allow(ImageChecker)
      .to receive(:valid?)
      .and_return !is_first_check_failed, !is_second_check_failed
  end
  let(:poster_policy) { double need_import?: need_import }
  let(:is_first_check_failed) { false }
  let(:is_second_check_failed) { false }

  context 'need import', :vcr do
    let(:need_import) { true }

    it do
      expect { subject }.to change(Poster, :count).by 1
      expect(entry.reload.poster).to_not eq prev_poster
      expect(entry.poster).to be_persisted
      expect(entry.poster).to_not be_changed
      expect(entry.poster.image).to be_exists
      expect(entry.poster.mal_url).to eq image_url
      expect(prev_poster.reload.deleted_at).to be_within(0.1).of Time.zone.now
    end

    describe 'broken import does not delete prev poster' do
      before do
        allow_any_instance_of(DbImport::MalPoster)
          .to receive(:download_image)
          .and_return nil
      end
      it do
        expect { subject }.to_not change Poster, :count
        expect(entry.reload.poster).to eq prev_poster
        expect(prev_poster.reload.deleted_at).to be_nil
      end
    end

    describe 'failed first check attempt' do
      let(:is_first_check_failed) { true }

      it do
        expect { subject }.to change(Poster, :count).by 1
        expect(entry.reload.poster).to_not eq prev_poster
        expect(entry.poster).to be_persisted
      end

      describe 'failed second attempt does not delete prev poster' do
        let(:is_second_check_failed) { true }

        it do
          expect { subject }.to_not change Poster, :count
          expect(entry.reload.poster).to eq prev_poster
          expect(prev_poster.reload.deleted_at).to be_nil
        end
      end
    end
  end

  context 'dont need import' do
    let(:need_import) { false }
    it { expect(entry.image).to_not be_present }
  end
end
