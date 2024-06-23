import delay from 'delay';
import Turbolinks from 'turbolinks';
import { flash } from 'shiki-utils';

import BanForm from '@/views/application/ban_form';
import I18n from '@/utils/i18n';

pageLoad('profiles_moderation', () => {
  $('.b-form.new_ban').on('ajax:success', async () => {
    flash.info(I18n.t('frontend.pages.p_profiles.page_is_reloading'));
    await delay(500);

    window.location.reload();
  });

  new BanForm($('.b-form.new_ban'));

  $('.ban-time').livetime();
});
