describe BbCodes::Tags::DivTag do
  subject { described_class.instance.format text }

  let(:text) { '[div]test[/div]' }
  it { is_expected.to eq '<div data-div>test</div>' }

  context 'new lines' do
    let(:text) do
      [
        "[div]\ntest[/div]",
        "[div]test\n[/div]",
        "[div]test[/div]\n",
        "[div]\ntest\n[/div]\n"
      ].sample
    end
    it { is_expected.to eq '<div data-div>test</div>' }

    context 'wrapped in other tags' do
      let(:text) do
        [
          "[span][div]\ntest\n[/div][/span]\n"
        ].sample
      end

      it { is_expected.to eq '[span]<div data-div>test</div>[/span]' }
    end

    context 'wrapped in other bbcodes' do
      let(:text) do
        [
          "<span>[div]\ntest\n[/div]</span>\n"
        ].sample
      end

      it { is_expected.to eq '<span><div data-div>test</div></span>' }
    end
  end

  context 'class' do
    context 'single' do
      let(:text) { '[div=aaa]test[/div]' }
      it { is_expected.to eq '<div class="aaa" data-div>test</div>' }
    end

    context 'multiple' do
      let(:text) { '[div=aaa bb-cd_e]test[/div]' }
      it { is_expected.to eq '<div class="aaa bb-cd_e" data-div>test</div>' }
    end
  end

  context 'data-attribute' do
    context 'single' do
      context 'wo value' do
        let(:text) { '[div data-test]test[/div]' }
        it { is_expected.to eq '<div data-test data-div>test</div>' }
      end

      context 'with value' do
        let(:text) { '[div data-test=zxc]test[/div]' }
        it { is_expected.to eq '<div data-test=zxc data-div>test</div>' }
      end
    end

    context 'multiple' do
      let(:text) { '[div data-test data-fofo]test[/div]' }
      it { is_expected.to eq '<div data-test data-fofo data-div>test</div>' }
    end
  end

  context 'class + data-attribute' do
    let(:text) { '[div=aaa bb-cd_e data-test data-fofo]test[/div]' }
    it do
      is_expected.to eq(
        '<div class="aaa bb-cd_e" data-test data-fofo data-div>test</div>'
      )
    end
  end

  context 'nested' do
    let(:text) { '[div=cc-2a][div=c-column]test[/div][/div]' }
    it do
      is_expected.to eq(
        '<div class="cc-2a" data-div><div class="c-column" data-div>test</div></div>'
      )
    end
  end

  context 'cleanup classes' do
    BbCodes::CleanupCssClass::FORBIDDEN_CSS_CLASSES.each do |sample|
      context sample do
        let(:picked_sample) { sample }
        let(:text) { "[div=aaa l-footer #{picked_sample}]test[/div]" }
        it { is_expected.to eq '<div class="aaa" data-div>test</div>' }
      end
    end
  end

  context 'unbalanced tags' do
    let(:text) { '[div=cc-2a][div=c-column]test[/div]' }
    it { is_expected.to eq text }
  end
end
