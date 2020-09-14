describe BbCodes::Markdown::ListQuoteParser do
  subject { described_class.instance.format text }
  let(:symbol) { ['-', '+', '*'].sample }

  context 'broken samples' do
    let(:text) { ["#{symbol}a", " #{symbol}a", " #{symbol} a"].sample }
    it { is_expected.to eq text }
  end

  context 'single line' do
    before do
      allow(BbCodes::Markdown::ListQuoteParserState)
        .to receive(:new)
        .and_call_original
    end
    let(:text) { "q\n#{symbol} a\nw" }
    let(:html) { "<ul class='b-list'><li>a</li></ul>" }

    context 'list' do
      it do
        is_expected.to eq "q\n#{html}w"
        expect(BbCodes::Markdown::ListQuoteParserState)
          .to have_received(:new)
          .with "#{symbol} a\n", 0, '', nil
      end
    end

    context 'blockquote' do
      let(:symbol) { ['>', '&gt;'].sample }
      let(:html) { "<blockquote class='b-quote-v2'>a</blockquote>" }
      it { is_expected.to eq "q\n#{html}w" }
    end

    context 'tags before' do
      let(:text) { "#{tag}#{symbol} a\nw" }

      context 'opened tag' do
        let(:tag) do
          %w[
            <div>
            <h2>
            <h3>
            <h4>
          ].sample
        end
        it do
          is_expected.to eq "#{tag}#{html}w"
          expect(BbCodes::Markdown::ListQuoteParserState)
            .to have_received(:new)
            .with "#{symbol} a\n", 0, '', tag.gsub('<', '</')
        end
      end

      context 'closed tag or placeholder' do
        let(:tag) do
          %w[
            </div>
            </h2>
            </h3>
            </h4>
            <<-CODE-1-PLACEHODLER->>
          ].sample
        end
        it do
          is_expected.to eq "#{tag}#{html}w"
          expect(BbCodes::Markdown::ListQuoteParserState)
            .to have_received(:new)
            .with "#{symbol} a\n", 0, '', nil
        end
      end
    end
  end

  context 'multiline line' do
    before do
      allow_any_instance_of(BbCodes::Markdown::ListQuoteParserState)
        .to receive(:to_html)
        .and_call_original
    end
    let(:text) { "#{symbol} #{line_1}\n#{symbol} #{line_2}" }
    let(:html) { "<ul class='b-list'><li>#{line_1}</li><li>#{line_2}</li></ul>" }
    let(:line_1) { 'a' }
    let(:line_2) { 'b' }

    it { is_expected.to eq html }

    context 'traverses through multiline bbcodes' do
      let(:line_1) { 'z [spoiler=x]x\nx[/spoiler]' }

      it { is_expected.to eq html }
    end

    context 'traverses through multiline bbcodes multiple times' do
      let(:line_1) { 'z [spoiler=x]x\nx[/spoiler][div]\n[/div]' }
      it { is_expected.to eq html }
    end

    context 'does not traverse through new line' do
      let(:text) { "#{symbol} z\n[spoiler]zxc[/spoiler]" }
      it do
        is_expected.to eq(
          "<ul class='b-list'><li>z</li></ul>[spoiler]zxc[/spoiler]"
        )
      end
    end

    context 'breaks on bbcode on the second line' do
      let(:text) { "#{symbol} a\n[div]#{symbol} b[/div]" }
      it do
        is_expected.to eq(
          "<ul class='b-list'><li>a</li></ul>" \
            '[div]' \
            "<ul class='b-list'><li>b</li></ul>" \
            '[/div]'
        )
      end
    end

    context 'breaks on tag on the second line' do
      let(:text) { "#{symbol} a\n<div>#{symbol} b</div>" }
      it do
        is_expected.to eq(
          "<ul class='b-list'><li>a</li></ul>" \
            '<div>' \
            "<ul class='b-list'><li>b</li></ul>" \
            '</div>'
        )
      end
    end
  end
end
