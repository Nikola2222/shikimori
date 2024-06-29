import $with from '@/utils/with';
import Poll from '@/views/polls/view';

export default class TrackPoll {
  constructor(poll, $root) {
    $with(this._selector(poll), $root)
      .data('model', poll)
      .toArray()
      .slice(30) // the same limit is in JsExports::PollsExport
      .forEach(node => new Poll(node, poll));
  }

  _selector(poll) {
    return `.poll-placeholder#${poll.id}`;
  }
}
