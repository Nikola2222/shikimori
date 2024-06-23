import delay from 'delay';

import { bind, memoize } from 'shiki-decorators';
import { isPhone } from 'shiki-utils';

import uniq from 'lodash/uniq';

import ShikiEditable from '@/views/application/shiki_editable';

import axios from '@/utils/axios';
import I18n from '@/utils/i18n';
import p from '@/utils/p';
import { animatedCollapse, animatedExpand } from '@/utils/animated';
import { loadImagesFinally } from '@/utils/load_image';

const I18N_KEY = 'frontend.dynamic_elements.topic';
const SHOW_IGNORED_TOPICS_IN = [
  'topics_show',
  'collections_show',
  'critiques_show',
  'reviews_show'
];

// TODO: move code related to comments to separate class
export default class Topic extends ShikiEditable {
  initialize() {
    // data attribute is set in Topics.Tracker
    this.model = this.$node.data('model') || this.defaultModel;

    if (window.SHIKI_USER.isUserIgnored(this.model.user_id) ||
        window.SHIKI_USER.isTopicIgnored(this.model.id)) {
      if (SHOW_IGNORED_TOPICS_IN.includes(document.body.id)) {
        this._toggleIgnored(true);
      } else {
        // node can be not inserted into DOM yet
        if (this.$node.parent().length) {
          this.$node.remove();
        } else {
          delay().then(() => this.$node.remove());
        }
        return;
      }
    }

    this.$editorContainer = this.$('.editor-container');
    this.$editor = this.$('.shiki_editor-selector');
    this.$editorForm = this.$editor.closest('form');
    this.$footerVote = this.$inner.find('.b-footer_vote');

    // do not move to getter. it is redefined in FullDialog
    this.$commentsLoader = this.$('.comments-loader');

    if (window.SHIKI_USER.isSignedIn &&
      window.SHIKI_USER.isDayRegistered && this.$editor.length
    ) {
      // NOTE: remove .process() after shiki_editor_v1 is completely removed from the project
      this.editor = this.$editor.process().view();
    } else {
      if (this.$editorForm.length) {
        this.$editorForm.replaceWith(
          `<div class='b-nothing_here'>${I18n.t('frontend.shiki_editor.not_available')}</div>`
        );
      }
      this.$editor = null;
      this.$editorForm = null;
    }

    if (this.model && !this.model.is_viewed) { this._activateAppearMarker(); }
    if (this.model && this.$footerVote.length) { this._actualizeVoting(); }

    if (this.$checkHeightNode.length && (this.isPreview || this.isClubPage)) {
      this._scheduleCheckHeight(true);
    }

    if (this.isCosplay && !this.isPreview) {
      import(/* webpackChunkName: "galleries" */ '@/views/application/shiki_gallery')
        .then(({ ShikiGallery }) => (
          new ShikiGallery(this.$('.b-cosplay_gallery .b-gallery'))
        ));
    }

    // no editor form for topic tooltip for example
    if (this.$editorForm) {
      this.$editorForm
        .on('ajax:success', (e, response) => {
          const $newComment = $(response.content).process(response.JS_EXPORTS);

          this.$('.b-comments').find('.b-nothing_here').remove();
          if (this.$editor.is(':last-child')) {
            this.$('.b-comments').append($newComment);
          } else {
            this.$('.b-comments').prepend($newComment);
          }

          $newComment.yellowFade();

          this.editor.cleanup();
          this._hideEditor();
        });
    }

    $('.item-ignore', this.$inner)
      .on('ajax:before', function() {
        $(this).toggleClass('selected');
      })
      .on('ajax:success', (e, result) => {
        if (result.is_ignored) {
          window.SHIKI_USER.ignoreTopic(result.topic_id);
        } else {
          window.SHIKI_USER.unignoreTopic(result.topic_id);
        }

        this._toggleIgnored(result.is_ignored);
      });

    if (this.$footerVote.length) {
      this._bindVotes();
    }
    // прочтение комментриев
    this.on('appear', this._appear);

    // ответ на комментарий
    this.on('comment:reply', (e, reply, isOfftopic) => {
      // @editor is empty for unauthorized user
      if (this.editor) {
        this._showEditor();

        if (reply) { // it is empty for generated topics
          this.editor.replyComment(reply, isOfftopic);
        } else {
          this.editor.focus();
        }
      }
    });

    // клик скрытию редактора
    this.$('.shiki_editor-selector').on('click', '.hide', this._hideEditor);

    // delegated handlers becase it is replaced on postload in
    // inherited classes (FullDialog)
    this.on('clickloaded:before', '.comments-loader', this._beforeCommentsClickload);
    this.on('clickloaded:success', '.comments-loader', this._commentsClickloaded);
    this.on('click', '.comments-loader', () => {
      if (this.$commentsLoader.data('dynamic') !== 'clickloaded') {
        this.$commentsLoader.addClass('hidden');
        this.$('.comments-loaded').each((_index, node) => animatedExpand(node));
        this.$commentsHider.show();
      }
    });

    // hide loaded comments
    this.$commentsCollapser.on('click', () => {
      this.$commentsCollapser.addClass('hidden');
      this.$commentsLoader.addClass('hidden');
      this.$commentsExpander.show();
      this.$('.comments-loaded').each((_index, node) => animatedCollapse(node));
    });

    // скрытие комментариев
    this.$commentsHider.on('click', () => {
      this.$commentsHider.hide();
      this.$('.comments-loaded').each((_index, node) => animatedCollapse(node));
      this.$commentsExpander.show();
    });

    // разворачивание комментариев
    this.$commentsExpander.on('click', () => {
      this.$commentsExpander.hide();
      this.$('.comments-loaded').each((_index, node) => animatedExpand(node));

      if (this.$commentsLoader) {
        this.$commentsLoader.removeClass('hidden');
        this.$commentsCollapser.removeClass('hidden');
      } else {
        this.$commentsHider.show();
      }
    });

    this._bindReturnClick();
  }

  async _showReturnButton() {
    await delay(300); // нужно подождать, пока страница проскролится до редактора

    $('span.return-to-reply').css(
      'visibility',
      $(this.repliedNode).is(':appeared') ? 'hidden' : 'visible'
    );
  }

  _saveRepliablePosition(repliedNode) {
    this.repliedNode = repliedNode;
  }

  _returnToReplyComment() {
    if (this.repliedNode) {
      $.scrollTo($(this.repliedNode));
    }
    $('span.return-to-reply').css('visibility', 'hidden');
    this.repliedNode = null;
  }

  _bindReturnClick() {
    this.on('click', 'span.item-reply, span.item-quote, span.item-quote-mobile', e => {
      const repliable = $(e.target).closest('.inner');

      this._saveRepliablePosition(repliable);
      this._showReturnButton();
    });

    this.$('span.return-to-reply').on('click', () => {
      this._returnToReplyComment();
    });
  }

  // similar to hash from JsExports::TopicsExport#serialize
  get defaultModel() {
    return {
      can_destroy: false,
      can_edit: false,
      id: parseInt(this.node.id),
      is_viewed: true,
      user_id: this.$node.data('user_id'),
      voted_yes: false,
      voted_no: false
    };
  }
  get type() { return 'topic'; }
  get commentType() { return 'comment'; }
  get typeLabel() { return I18n.t(`${I18N_KEY}.type_label`); }

  get reloadUrl() {
    return `/${this.type}s/${this.$node.attr('id')}/reload?is_preview=${this.isPreview}&is_mini=${this.isMini}`;
  }

  @memoize
  get $body() {
    return this.$inner.children('.body');
  }

  @memoize
  get isPreview() { return this.$node.hasClass('b-topic-preview'); }

  @memoize
  get isMini() { return this.$node.hasClass('b-topic-minified'); }

  @memoize
  get isCosplay() { return this.$node.hasClass('b-cosplay-topic'); }

  @memoize
  get isClubPage() { return this.$node.hasClass('b-club_page-topic'); }

  @memoize
  get isCritique() { return this.$node.hasClass('b-critique-topic'); }

  @memoize
  get isReview() { return this.$node.hasClass('b-review-topic'); }

  @memoize
  get $commentsHider() { return this.$('.comments-hider'); }

  @memoize
  get $commentsCollapser() { return this.$('.comments-collapser'); }

  @memoize
  get $commentsExpander() { return this.$('.comments-expander'); }

  @memoize
  get $checkHeightNode() {
    return this.$body;
  }

  _assignCheckHeightLimits() {
    if (this.isReview || this.isCritique) {
      this.CHECK_HEIGHT_MAX_PREVIEW_HEIGHT = 220;
      this.CHECK_HEIGHT_COLLAPSED_HEIGHT = 120;
      this.CHECK_HEIGHT_PLACEHOLDER_HEIGHT = 120;
    } else {
      super._assignCheckHeightLimits();
    }
  }

  _bindFaye() {
    super._bindFaye();

    this.on(
      [
        `faye:${this.commentType}:updated`,
        `faye:${this.commentType}:deleted`,
        `faye:${this.commentType}:converted`,
        `faye:${this.commentType}:set_replies`
      ].join(' '), (e, data) => {
        e.stopImmediatePropagation();
        const trackableType = e.type.match(/comment|message/)[0];
        const trackableId = data[`${trackableType}_id`];

        if (e.target === this.$node[0]) {
          this.$(`.b-${trackableType}#${trackableId}`).trigger(e.type, data);
        }
      });

    this.on(`faye:${this.commentType}:created`, (e, data) => {
      e.stopImmediatePropagation();
      const trackableType = e.type.match(/comment|message/)[0];
      const trackableId = data[`${trackableType}_id`];

      if (this.$(`.b-${trackableType}#${trackableId}`).exists()) { return; }
      const $placeholder = this._fayePlaceholder(trackableId, trackableType);

      // уведомление о добавленном элементе через faye
      $(document.body).trigger('faye:added');

      if (window.SHIKI_USER.isCommentsAutoLoaded) {
        if ($placeholder.is(':appeared') && !$('textarea:focus').val()) {
          $placeholder.click();
        }
      }
    });

    this.on('faye:comment:marked', (e, data) => {
      e.stopImmediatePropagation();

      $(`.b-comment#${data.comment_id}`)
        .view()
        .mark(data.mark_kind, data.mark_value);
    });
  }

  // переключение топика в режим игнора/не_игнора
  _toggleIgnored(isIgnored) {
    $('.item-ignore', this.$inner)
      .toggleClass('selected', isIgnored)
      .data({ method: isIgnored ? 'DELETE' : 'POST' });

    this.$('.b-anime_status_tag.ignored').toggleClass('hidden', !isIgnored);
  }

  // удаляем уже имеющиеся подгруженные элементы
  _filterPresentEntries($comments) {
    const filter = 'b-comment';
    const presentIds = $(`.${filter}`, this.$node)
      .toArray()
      .map(v => v.id)
      .filter(v => v);

    const excludeSelector = presentIds.map(id => `.${filter}#${id}`).join(',');

    $comments.children().filter(excludeSelector).remove();
  }

  // отображение редактора, если это превью топика
  _showEditor() {
    if (this.isPreview && !this.$editorContainer.is(':visible')) {
      this.$editorContainer.show();// animatedExpand()
    }
  }

  // скрытие редактора, если это превью топика
  @bind
  _hideEditor() {
    if (this.isPreview) {
      this.$editorContainer.hide();// animatedCollapse()
    }
  }

  // получение плейсхолдера для подгрузки новых комментариев
  _fayePlaceholder(trackableId, trackableType) {
    this.$('.b-comments .b-nothing_here').remove();
    let $placeholder = this.$('.b-comments .faye-loader');

    if (!$placeholder.exists()) {
      $placeholder = $('<div class="faye-loader to-process" data-dynamic="clickloaded"></div>')
        .appendTo(this.$('.b-comments'))
        .data({ ids: [] })
        .process()
        .on('clickloaded:success', (e, data) => {
          const $html = $(data.content).process(data.JS_EXPORTS);
          $placeholder.replaceWith($html);
          $html.process();
        });
    }

    if ($placeholder.data('ids')?.indexOf(trackableId) === -1) {
      const ids = uniq([...$placeholder.data('ids'), trackableId]);
      $placeholder.data({
        ids,
        'clickloaded-url': `/${trackableType}s/chosen/${ids.join(',')}`
      });

      const num = $placeholder.data('ids').length;

      $placeholder.html(trackableType === 'message' ?
        p(num,
          I18n.t(`${I18N_KEY}.new_message_added.one`, { count: num }),
          I18n.t(`${I18N_KEY}.new_message_added.few`, { count: num }),
          I18n.t(`${I18N_KEY}.new_message_added.many`, { count: num })) :
        p(num,
          I18n.t(`${I18N_KEY}.new_comment_added.one`, { count: num }),
          I18n.t(`${I18N_KEY}.new_comment_added.few`, { count: num }),
          I18n.t(`${I18N_KEY}.new_comment_added.many`, { count: num }))
      );
    }

    return $placeholder;
  }

  // handlers
  async _appear(e, $appeared, byClick) {
    const $filteredAppeared = $appeared.not(function() {
      return $(this).data('disabled') || !(
        this.classList.contains('b-appear_marker') &&
          this.classList.contains('active')
      );
    });
    if (!$filteredAppeared.exists()) { return; }

    const interval = byClick ? 1 : 1500;
    const $objects = $filteredAppeared.closest('[data-appear_type]');
    const $markers = $objects.find('.b-new_marker.active');
    const ids = $objects
      .map(function() {
        const $object = $(this);
        const itemType = $object.data('appear_type');
        return `${itemType}-${this.id}`;
      }).toArray();

    axios.post($markers.data('appear_url'), { ids: ids.join(',') });

    $filteredAppeared.remove();

    if ($markers.data('reappear')) {
      $markers.addClass('off');
    } else {
      await delay(interval);
      $markers.css({ opacity: 0 });

      await delay(500);
      $markers.hide();
      $markers.removeClass('active');
    }
  }

  @bind
  _beforeCommentsClickload() {
    const newUrl = this.$commentsLoader
      .data('clickloaded-url-template')
      .replace('SKIP', this.$commentsLoader.data('skip'));

    this.$commentsLoader.data('clickloaded-url', newUrl);
  }

  @bind
  _commentsClickloaded(e, data) {
    const $newComments = $('<div class=\'comments-loaded\'></div>').html(data.content);

    this._filterPresentEntries($newComments);

    $newComments
      .process(data.JS_EXPORTS)
      .insertAfter(this.$commentsLoader);

    animatedExpand($newComments[0]);

    this._updateCommentsLoader(data);
  }

  _actualizeVoting() {
    this.$inner
      .find('.b-footer_vote .vote.yes, .user-vote .voted-for')
      .toggleClass('selected', this.model.voted_yes);

    this.$inner
      .find('.b-footer_vote .vote.no, .user-vote .voted-against')
      .toggleClass('selected', this.model.voted_no);

    if (this.model.votes_for != null) {
      this.$inner.find('.votes-for').html(`${this.model.votes_for}`);
    }

    if (this.model.votes_against != null) {
      this.$inner.find('.votes-against').html(`${this.model.votes_against}`);
    }
  }

  // data is used in inherited classes (FullDialog)
  _updateCommentsLoader(_data) {
    const limit = this.$commentsLoader.data('limit');
    const count = this.$commentsLoader.data('count') - limit;

    if (count > 0) {
      this.$commentsLoader.data({
        skip: this.$commentsLoader.data('skip') + limit,
        count
      });

      const commentCount = Math.min(limit, count);
      const commentWord = p(commentCount,
        I18n.t(`${I18N_KEY}.comment.one`),
        I18n.t(`${I18N_KEY}.comment.few`),
        I18n.t(`${I18N_KEY}.comment.many`)
      );

      const ofTotalComments =
        count > limit ?
          `${I18n.t(`${I18N_KEY}.of`)} ${count}` :
          '';

      const loadComments = I18n.t(
        `${I18N_KEY}.load_comments`, {
          comment_count: commentCount,
          of_total_comments: ofTotalComments,
          comment_word: commentWord
        }
      );

      this.$commentsLoader.html(loadComments);
      this.$commentsCollapser.removeClass('hidden');
    } else {
      this.$commentsLoader.remove();
      this.$commentsLoader = null;

      this.$commentsHider.show();
      this.$commentsCollapser.remove();
    }
  }

  _bindVotes() {
    if (window.SHIKI_USER?.id === this.model.user_id) {
      this.$footerVote.remove();
    }

    const $vote = this.$footerVote.find('.vote');
    $vote
      .on('ajax:before', e => {
        this.$footerVote.addClass('b-ajax');
        const $target = $(e.target);
        const isYes = $target.hasClass('yes');
        let vote = null;

        if (isYes) {
          if (this.model.voted_yes) {
            vote = 'unvote';
            this.model.votes_for -= 1;
          } else {
            vote = 'yes';
            this.model.votes_for += 1;
            if (this.model.voted_no) this.model.votes_against -= 1;
          }
        } else {
          if (this.model.voted_no) {
            vote = 'unvote';
            this.model.votes_against -= 1;
          } else {
            vote = 'no';
            this.model.votes_against += 1;
            if (this.model.voted_yes) this.model.votes_for -= 1;
          }
        }
        $target.data(
          'action',
          $target.data('action').replace(/vote=\w+/, `vote=${vote}`)
        );

        this.model.voted_yes = this.model.voted_yes ? false : isYes;
        this.model.voted_no = this.model.voted_no ? false : !isYes;

        this._actualizeVoting();
      })
      .on('ajax:complete', () => {
        this.$footerVote.removeClass('b-ajax');
      });
  }
}
