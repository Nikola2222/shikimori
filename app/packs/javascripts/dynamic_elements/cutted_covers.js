import delay from 'delay';
import round from 'lodash/round';

import View from '@/views/application/view';

let PRIOR_ID = 0;
let GLOBAL_HANDLER = false;

export const GLOBAL_SELECTOR = 'd-cutted_covers';
export const DATA_KEY = 'cutted-covers';

// copied from app/services/uploaders/poster_uploader.rb
const PREVIEW_WIDTH = 160.0;
const PREVIEW_ANIME_HEIGHT = PREVIEW_WIDTH / (425.0 / 600.0);
const PREVIEW_CHARACTER_HEIGHT = PREVIEW_WIDTH / (225.0 / 350.0);

export const RATIO = {
  entry: PREVIEW_ANIME_HEIGHT / PREVIEW_WIDTH,
  person: PREVIEW_CHARACTER_HEIGHT / PREVIEW_WIDTH,
  character: PREVIEW_CHARACTER_HEIGHT / PREVIEW_WIDTH
};

function update() {
  $('#injectCSSContainer').empty();

  $(`.${GLOBAL_SELECTOR}`).each((_index, node) => (
    $(node).data(DATA_KEY)?.process()
  ));
}

function setHanler() {
  GLOBAL_HANDLER = true;
  $(document).on('resize:debounced orientationchange', update);
}

export class CuttedCovers extends View {
  async initialize() {
    if (!GLOBAL_HANDLER) { setHanler(); }

    // $.process sometimes executed BEFORE a node is inserted into the DOM,
    // but this code must executed AFTER a node is inserted into the DOM.
    // that is why `delay` is used here
    await delay();

    this._fetchPoster();
    this.collectionId = `cutted_covers_${this.incrementId()}`;
    this.ratioValue = RATIO[this.nodeRatio(this.node)] || RATIO.entry;

    this.process();

    this.node.id = this.collectionId;
    this.node.classList.add(GLOBAL_SELECTOR);
    this.$node.data(DATA_KEY, this);
  }

  process() {
    if (!this.$poster || !$.contains(document.documentElement, this.$poster[0])) {
      this._fetchPoster();
    }
    const height = round(this.$poster.width() * this.ratioValue, 2);
    const width = this.$poster.width();

    if ((width > 0) && (height > 0)) {
      $.injectCSS({
        [`#${this.collectionId}`]: {
          '.image-cutter': {
            'max-width': width,
            'max-height': height
          }
        }
      });
    }
  }

  incrementId() {
    return PRIOR_ID += 1;
  }

  nodeRatio(node) {
    return node.attributes['data-ratio_type']?.value;
  }

  _fetchPoster() {
    this.$poster = this.$('.b-catalog_entry:first-child .image-decor');
  }
}
