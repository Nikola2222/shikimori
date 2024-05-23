class BbCodes::Markdown::ListQuoteParserState # rubocop:disable ClassLength
  LIST_ITEM_VARIANTS = ['- ', '+ ', '* ']

  BLOCKQUOTE_VARIANT_1 = '> '
  BLOCKQUOTE_VARIANT_2 = '&gt; '

  BLOCKQUOTE_VARIANTS = [
    BLOCKQUOTE_VARIANT_1,
    BLOCKQUOTE_VARIANT_2
  ]

  BLOCKQUOTE_QUOTABLE_VARIANT_1 = '>?'
  BLOCKQUOTE_QUOTABLE_VARIANT_2 = '&gt;?'

  LIST_OPEN_TAG = BbCodes::Tags::ListTag::LIST_OPEN_TAG
  LIST_CLOSE_TAG = BbCodes::Tags::ListTag::LIST_CLOSE_TAG

  BLOCKQUOTE_OPEN_TAG = "<blockquote class='b-quote-v2'%<attrs>s>"
  BLOCKQUOTE_OPEN_CONTENT = "<div class='quote-content'>"
  BLOCKQUOTE_QUOTEABLE_TAG = "<div class='quoteable'>%<quoteable>s</div>"
  BLOCKQUOTE_CLOSE = '</div></blockquote>'

  MULTILINE_BBCODES_MAX_SIZE = BbCodes::MULTILINE_BBCODES.map(&:size).max

  BR_ENDING_REGEXP = /(\[br\])+\Z/
  EMPTY_LINE_PLACEHOLDER_HTML = "<div data='empty-line-placeholder'><br></div>"

  CODE_PLACEHOLDER = BbCodes::Tags::CodeTag::CODE_PLACEHOLDER_1
  TAG_CLOSE_REGEXP = %r{</\w+>|#{Regexp.escape CODE_PLACEHOLDER}}

  MAX_NESTING = 4

  MULTILINE_BBCODES_NESTED_SEQUENCE_MATCHER = %r{
    (?<tag_start>\[(?<tag>#{BbCodes::MULTILINE_BBCODES.join('|')}) [^\]]*? \])
    (?<content>[\s\S]*?)
    (?<tag_end>\[/\k<tag>\])
  }x
  MULTILINE_BBCODES_NESTED_SEQUENCE_REPLACERS = {}

  def initialize text, index = 0, nested_sequence = '', exit_sequence = nil
    @text = text
    @nested_sequence = nested_sequence
    @exit_sequence = exit_sequence
    @index = index
    @is_traversed_tags = false
    @is_exit_sequence = false

    @state = []
    @nesting = 0
  end

  def to_html
    parse_line while @index < @text.size && !@is_exit_sequence

    rest_content = @text[@index..] if @index <= @text.size - 1

    [
      @state.join,
      rest_content
    ]
  rescue ArgumentError => e
    if e.message == 'not_blockquote'
      ['', @text]
    else
      raise
    end
  end

private

  def parse_line skippable_sequence = '' # rubocop:disable all
    if matched_sequence?(skippable_sequence.presence || @nested_sequence)
      move((skippable_sequence.presence || @nested_sequence).size)
    end

    start_index = @index

    while @index <= @text.size
      @is_exit_sequence = matched_sequence?(@exit_sequence) if @exit_sequence

      if end_of_code_block?
        finalize_content start_index, @index
        move 2
        return
      end

      if end_of_line?
        finalize_content start_index, @index - 1
        move 1
        return
      end

      if @is_exit_sequence
        finalize_content start_index, @index - 1
        return
      end

      if start_of_line?(start_index) && @nesting < MAX_NESTING
        seq_2 = @text[@index..(@index + 1)]
        return parse_list seq_2 if seq_2.in? LIST_ITEM_VARIANTS
        return parse_blockquote seq_2 if seq_2 == BLOCKQUOTE_VARIANT_1

        if seq_2 == BLOCKQUOTE_QUOTABLE_VARIANT_1
          if parse_blockquote_quotable(seq_2) # rubocop:disable BlockNesting
            return
          else
            raise ArgumentError, 'not_blockquote'
          end
        end

        seq_5 = @text[@index..(@index + 4)]
        return parse_blockquote seq_5 if seq_5 == BLOCKQUOTE_VARIANT_2

        if seq_5 == BLOCKQUOTE_QUOTABLE_VARIANT_2
          if parse_blockquote_quotable(seq_5) # rubocop:disable BlockNesting
            return
          else
            raise ArgumentError, 'not_blockquote'
          end
        end
      end

      if @text[@index] == '['
        sequence = @text.slice(@index + 1, MULTILINE_BBCODES_MAX_SIZE)
        tag = BbCodes::MULTILINE_BBCODES.find { |bbcode| sequence.starts_with? bbcode }

        # traverse through nested possibly multiline bbcode
        next if tag && traverse(tag)
      end

      move 1
    end

    finalize_content start_index, @index
  end

  def start_of_line? start_index
    start_index == @index
  end

  def end_of_line?
    @text[@index] == "\n" || @text[@index].nil?
  end

  def end_of_code_block? index = @index
    size = CODE_PLACEHOLDER.size

    @text[index] == CODE_PLACEHOLDER.last &&
      index > size - 1 &&
      @text.slice(index - size + 1, size) == CODE_PLACEHOLDER
  end

  def traverse tag
    rest_text = @text[@index..]
    tag_end = "[/#{tag}]"
    tag_end_index = rest_text.index tag_end

    if tag_end_index
      @is_traversed_tags = true
      move tag_end_index + tag_end.length
      true
    else
      false
    end
  end

  def parse_list tag_sequence # rubocop:disable MethodLength
    is_first_line = true
    prior_sequence = @nested_sequence
    @nesting += 1

    @state.push LIST_OPEN_TAG
    @nested_sequence += tag_sequence
    # puts "processBulletList '#{@nested_sequence}'"

    loop do
      move is_first_line ? tag_sequence.length : @nested_sequence.length
      @state.push '<li>'
      parse_list_lines prior_sequence, '  '
      ensure_empty_line_placeholder!
      @state.push '</li>'

      is_first_line = false
      break unless sequence_continued?
    end

    @state.push LIST_CLOSE_TAG
    @nested_sequence = @nested_sequence.slice(0, @nested_sequence.size - tag_sequence.size)
    @nesting -= 1

    # puts "processBulletList '#{@nested_sequence}'"
  end

  def parse_list_lines prior_sequence, tag_sequence
    nested_sequence_backup = @nested_sequence

    @nested_sequence = prior_sequence + tag_sequence
    # puts "processBulletListLines '#{@nested_sequence}'"
    line = 0

    loop do
      if line.positive?
        @state.push "\n" unless end_of_code_block?(@index - 2)
        move @nested_sequence.length
      end

      parse_line
      line += 1
      break unless sequence_continued?
    end

    @nested_sequence = nested_sequence_backup
    # puts "processBulletListLines '#{@nested_sequence}'"
  end

  def parse_blockquote_quotable tag_sequence # rubocop:disable AbcSize
    meta_start_index = @index + tag_sequence.size
    meta_end_index = @text.index(/\n|\Z/, meta_start_index)

    meta_text = @text.slice(meta_start_index, meta_end_index - meta_start_index)
    meta_attrs = BbCodes::Quotes::ParseMeta.call meta_text

    from_index = @index + tag_sequence.size + meta_text.size + 1 + @nested_sequence.size
    to_index = from_index + tag_sequence.size
    next_tag_sequence = @text.slice from_index, to_index - from_index

    if BLOCKQUOTE_VARIANTS.include? next_tag_sequence
      move tag_sequence.size + meta_text.size + 1 + @nested_sequence.size
      parse_blockquote next_tag_sequence, meta_attrs, meta_text
    else
      false
    end
  end

  def parse_blockquote tag_sequence, meta_attrs = nil, meta_text = nil
    is_first_line = true
    push_blockquote_open meta_attrs, meta_text
    @nested_sequence += tag_sequence
    @nesting += 1
    # puts "processBlockQuote '#{@nested_sequence}'"

    loop do
      @state.push "\n" unless is_first_line || @state.last.match?(TAG_CLOSE_REGEXP)

      parse_line is_first_line ? tag_sequence : ''
      is_first_line = false
      break unless sequence_continued?
    end

    ensure_empty_line_placeholder!
    @state.push BLOCKQUOTE_CLOSE
    @nested_sequence = @nested_sequence.slice(0, @nested_sequence.size - tag_sequence.size)
    @nesting -= 1
    # puts "processBlockQuote '#{@nested_sequence}'"
  end

  def move steps
    @index += steps
  end

  def finalize_content start_index, end_index
    text = BbCodes::Markdown::HeadlineParser.instance.format(
      @text[start_index..end_index]
    )

    if @is_traversed_tags
      text = replace_nested_sequence_inside_multiline_bbcodes text
      @is_traversed_tags = false
    end

    @state.push text
  end

  def sequence_continued?
    @text.slice(@index, @nested_sequence.size) == @nested_sequence
  end

  def matched_sequence? sequence
    sequence.present? && @text[@index] == sequence[0] &&
      @text.slice(@index, sequence.size) == sequence
  end

  def push_blockquote_open meta_attrs, meta_text # rubocop:disable Metrics/MethodLength
    if meta_attrs
      quoteable = BbCodes::Quotes::QuoteableToBbcode.instance.call(meta_attrs)
      # can't allow bbcodes here since this content is placed inside of html tag
      # and thus it cannot be procssed as bbcod
      safe_meta_text = ERB::Util.h(meta_text)
        .gsub('[', '&#91;')
        .gsub(']', '&#93')
        .gsub(':', '&#58;')

      @state.push(
        format(BLOCKQUOTE_OPEN_TAG, attrs: " data-attrs='#{safe_meta_text}'") +
          format(BLOCKQUOTE_QUOTEABLE_TAG, quoteable:) +
          BLOCKQUOTE_OPEN_CONTENT
      )
    else
      @state.push(
        format(BLOCKQUOTE_OPEN_TAG, attrs: '') + BLOCKQUOTE_OPEN_CONTENT
      )
    end
  end

  def replace_nested_sequence_inside_multiline_bbcodes text
    MULTILINE_BBCODES_NESTED_SEQUENCE_REPLACERS[@nested_sequence] ||=
      /(\A|\n)#{Regexp.escape @nested_sequence}(.*)/

    text.gsub(MULTILINE_BBCODES_NESTED_SEQUENCE_MATCHER) do
      tag_start = $LAST_MATCH_INFO[:tag_start]
      content = $LAST_MATCH_INFO[:content]
      tag_end = $LAST_MATCH_INFO[:tag_end]

      content_wo_nested_sequence = content.gsub(
        MULTILINE_BBCODES_NESTED_SEQUENCE_REPLACERS[@nested_sequence],
        '\1\2'
      )

      tag_start + content_wo_nested_sequence + tag_end
    end
  end

  def ensure_empty_line_placeholder!
    if @state.last.ends_with? '[br]'
      @state[@state.size - 1] = @state.last.gsub(BR_ENDING_REGEXP) do |match|
        match.gsub '[br]', EMPTY_LINE_PLACEHOLDER_HTML
      end
    end
  end
end
