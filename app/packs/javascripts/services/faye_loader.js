/* eslint no-console: 0 */
/* global IS_FAYE_LOGGING */

import Faye from 'faye';
import Cookies from 'js-cookie';

import difference from 'lodash/difference';
import intersection from 'lodash/intersection';
import isEmpty from 'lodash/isEmpty';

import idle from '@morr/user-idle';
import { bind } from 'shiki-decorators';

const WORLD_CHANGED_EVENTS = [
  'turbolinks:load',
  'ajax:success',
  'postloader:success',
  'clickloaded:success'
];
const INACTIVITY_INTERVAL = 10 * 60 * 1000;

export default class FayeLoader {
  client = null;
  subscriptions = {};

  constructor() {
    this.apply();

    // refresh subscruptions when something is changed in outside world
    $(document).on(WORLD_CHANGED_EVENTS.join(' '), this.apply);
    // disconnect faye after 10 minutes of user inactivity
    idle({
      onIdle: this._idleShutdown,
      onActive: this._idleRestore,
      idle: INACTIVITY_INTERVAL
    }).start();
  }

  get id() {
    return this.client?._dispatcher?.clientId;
  }

  @bind
  apply() {
    let $targets = $('.b-forum');
    if (!$targets.length) { $targets = $('[data-faye]'); }
    if (!this.client && ($targets.length || window.FAYE_CHANNEL)) {
      this.connect();
    }

    const channels = {};
    if (window.FAYE_CHANNEL) {
      channels[window.FAYE_CHANNEL] = $(document.body);
    }

    $targets.each((index, node) => {
      const fayeChannels = $(node).data('faye');
      if ((fayeChannels !== false) && isEmpty(fayeChannels)) {
        console.warn('no faye channels found for', node);
      }

      if (fayeChannels) {
        fayeChannels.forEach(channel => channels[channel] = $(node));
      }
    });

    this.unsubscribe(channels);
    this.update(channels);
    this.subscribe(channels);
  }

  connect() {
    const port = window.ENV === 'development' ? ':9292' : '';
    const hostname = window.ENV === 'development' ?
      location.hostname :
      `faye.${location.hostname}`;

    this.client = new Faye.Client(window.FAYE_URL, {
      timeout: 300,
      retry: 5
      // endpoints: {
      //   websocket: "#{location.protocol}//#{location.hostname}#{port}/server-v1"
      // }
    });

    // @client.disable 'eventsource'
    if (Cookies.get('faye-disable-websocket')) {
      this.client.disable('websocket');
    }
    // console.log 'faye connected' if IS_FAYE_LOGGING
  }

  _disconnect() {
    this.client.disconnect();
    this.client = null;
    this.subscriptions = {};
  }

  unsubscribe(channels) {
    const toStay = Object.keys(channels);
    const toRemove = Object.keys(this.subscriptions)
      |> difference(?, toStay);

    toRemove.forEach(channel => {
      this.client.unsubscribe(channel);
      delete this.subscriptions[channel];

      if (IS_FAYE_LOGGING) { console.log(`faye unsubscribed ${channel}`); }
    });
  }

  update(channels) {
    (
      Object.keys(channels) |> intersection(?, Object.keys(this.subscriptions))
    ).forEach(channel => this.subscriptions[channel].node = channels[channel]);
  }

  subscribe(channels) {
    (
      Object.keys(channels) |> difference(?, Object.keys(this.subscriptions))
    ).forEach(channel => {
      const subscription = this.client.subscribe(channel, data => {
        // это колбек, в котором мы получили уведомление от faye
        if (IS_FAYE_LOGGING) { console.log(['faye:received', channel, data]); }
        // сообщения от самого себя не принимаем
        if (data.publisher_faye_id === this.id) { return; }

        this.subscriptions[channel].node.trigger(`faye:${data.event}`, data);
      });

      this.subscriptions[channel] = {
        node: channels[channel],
        channel: subscription
      };

      if (IS_FAYE_LOGGING) { console.log(`faye subscribed ${channel}`); }
    });
  }

  @bind
  _idleShutdown() {
    if (!this.client) { return; }

    if (IS_FAYE_LOGGING) { console.log('faye disconnect on idle'); }
    this._disconnect();
  }

  @bind
  _idleRestore() {
    if (this.client) { return; }

    if (IS_FAYE_LOGGING) { console.log('faye connect on active'); }
    this.connect();
    this.apply();
  }
}
