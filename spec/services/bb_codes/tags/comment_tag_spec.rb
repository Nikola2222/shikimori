describe BbCodes::Tags::CommentTag do
  subject { described_class.instance.format text }

  let(:url) { UrlGenerator.instance.comment_url comment }
  let(:attrs) do
    {
      id: comment.id,
      type: :comment,
      userId: comment.user_id,
      text: user.nickname
    }
  end
  let(:data_404_attrs) { { id: comment.id, type: :comment } }

  context 'selfclosed' do
    let(:text) { "[comment=#{comment.id}], test" }
    let(:comment) { create :comment, user: }

    it do
      is_expected.to eq(
        <<~HTML.squish
          <a href='#{url}' class='b-mention bubbled'
            data-attrs='#{ERB::Util.h attrs.to_json}'><s>@</s><span>#{ERB::Util.h user.nickname}</span></a>, test
        HTML
      )
    end

    context 'non existing comment' do
      let(:comment) { build_stubbed :comment }

      it do
        is_expected.to eq(
          <<~HTML.squish
            <a href='#{url}' class='b-mention b-entry-404 bubbled'
              data-attrs='#{ERB::Util.h data_404_attrs.to_json}'><s>@</s><del>[comment=#{comment.id}]</del></a>, test
          HTML
        )
      end
    end

    context 'with user_id' do
      let(:text) { "[comment=#{comment.id};#{user.id}], test" }
      let(:comment) { create :comment, user: }

      it do
        is_expected.to eq(
          <<~HTML.squish
            <a href='#{url}' class='b-mention bubbled'
              data-attrs='#{ERB::Util.h attrs.to_json}'><s>@</s><span>#{ERB::Util.h user.nickname}</span></a>, test
          HTML
        )
      end

      context 'non existing comment' do
        let(:comment) { build_stubbed :comment }

        it do
          is_expected.to eq(
            <<~HTML.squish
              <a href='#{url}' class='b-mention b-entry-404 bubbled'
                data-attrs='#{ERB::Util.h attrs.to_json}'><s>@</s><span>#{ERB::Util.h user.nickname}</span><del>[comment=#{comment.id}]</del></a>, test
            HTML
          )
        end
      end
    end
  end

  context 'with author' do
    let(:text) { "[comment=#{comment.id}]#{xss}[/comment], test" }
    let(:comment) { create :comment }
    let(:xss) { "XSS'" }

    it do
      is_expected.to eq(
        <<~HTML.squish
          <a href='#{url}' class='b-mention bubbled'
          data-attrs='#{ERB::Util.h attrs.to_json}'><s>@</s><span>#{ERB::Util.h xss}</span></a>, test
        HTML
      )
    end

    context 'non existing comment' do
      let(:comment) { build_stubbed :comment }

      it do
        is_expected.to eq(
          <<~HTML.squish
            <a href='#{url}' class='b-mention b-entry-404 bubbled'
              data-attrs='#{ERB::Util.h data_404_attrs.to_json}'><s>@</s><span>#{ERB::Util.h xss}</span><del>[comment=#{comment.id}]</del></a>, test
          HTML
        )
      end
    end
  end

  context 'double match' do
    let(:comment) { create :comment, user: }
    let(:comment_2) { create :comment, user: user_2 }
    let(:text) do
      "[comment=#{comment.id}], test [comment=#{comment_2.id}]qwe[/comment]"
    end
    let(:url_2) { UrlGenerator.instance.comment_url comment_2 }

    it do
      is_expected.to eq(
        <<~HTML.squish
          <a href='#{url}' class='b-mention bubbled'
            data-attrs='#{ERB::Util.h attrs.to_json}'><s>@</s><span>#{ERB::Util.h user.nickname}</span></a>, test
          <a href='#{Shikimori::PROTOCOL}://#{Shikimori::DOMAIN}/comments/#{comment_2.id}' class='b-mention bubbled'
            data-attrs='#{ERB::Util.h({ id: comment_2.id, type: :comment, userId: comment_2.user_id, text: user_2.nickname }.to_json)}'><s>@</s><span>qwe</span></a>
        HTML
      )
    end
  end

  context 'without author' do
    let(:text) { "[comment=#{comment.id}][/comment], test" }
    let(:comment) { create :comment, user: }

    it do
      is_expected.to eq(
        <<~HTML.squish
          <a href='#{url}' class='b-mention bubbled'
            data-attrs='#{ERB::Util.h attrs.to_json}'><s>@</s><span>#{ERB::Util.h user.nickname}</span></a>, test
        HTML
      )
    end

    context 'non existing comment' do
      let(:comment) { build_stubbed :comment }

      it do
        is_expected.to eq(
          <<~HTML.squish
            <a href='#{url}' class='b-mention b-entry-404 bubbled'
              data-attrs='#{ERB::Util.h data_404_attrs.to_json}'><s>@</s><del>[comment=#{comment.id}]</del></a>, test
          HTML
        )
      end
    end
  end

  context 'quote' do
    let(:text) { "[comment=#{comment.id} #{quote_part}]#{user.nickname}[/comment], test" }
    let(:comment) { create :comment, user: }
    let(:quote_part) { 'quote' }

    context 'with avatar' do
      let(:user) { create :user, :with_avatar }
      it do
        is_expected.to eq(
          <<~HTML.squish
            <a href='#{url}'
              class='b-mention bubbled b-user16'
              data-attrs='#{ERB::Util.h attrs.to_json}'><img
              src="#{ImageUrlGenerator.instance.cdn_image_url user, :x16}"
              srcset="#{ImageUrlGenerator.instance.cdn_image_url user, :x32} 2x"
              alt="#{ERB::Util.h user.nickname}" /><span>#{ERB::Util.h user.nickname}</span></a>, test
          HTML
        )
      end
    end

    context 'without avatar' do
      it do
        is_expected.to eq(
          <<~HTML.squish
            <a href='#{url}' class='b-mention bubbled'
              data-attrs='#{ERB::Util.h attrs.to_json}'><span>#{ERB::Util.h user.nickname}</span></a>, test
          HTML
        )
      end
    end

    context 'non existing comment' do
      let(:comment) { build_stubbed :comment }
      it do
        is_expected.to eq(
          <<~HTML.squish
            <a href='#{url}' class='b-mention b-entry-404 bubbled'
              data-attrs='#{ERB::Util.h data_404_attrs.to_json}'><s>@</s><span>#{ERB::Util.h user.nickname}</span><del>[comment=#{comment.id}]</del></a>, test
          HTML
        )
      end

      context 'quote with user_id' do
        let(:quote_part) { "quote=#{user.id}" }
        it do
          is_expected.to eq(
            "[user=#{user.id}]#{user.nickname}[/user]" \
              "<span class='b-mention b-entry-404'><del>[comment=#{comment.id}]</del></span>, test"
          )
        end
      end
    end
  end
end
