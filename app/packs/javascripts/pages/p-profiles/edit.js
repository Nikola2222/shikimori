import Cookies from 'js-cookie';

pageLoad('profiles_edit', () => {
  if ($('.edit-page.account').exists()) {
    pageAccount();
  }

  if ($('.edit-page.styles').exists()) {
    pageStyles();
  }

  if ($('.edit-page.list, .edit-page.misc').exists()) {
    pageListAndMisc();
  }
});

function pageAccount() {
  $('.censored-rejected').on('click', ({ currentTarget }) => {
    $('.censored-rejected-container').remove();
    Cookies.remove(
      currentTarget.getAttribute('data-cookie')
    );
  });
}

async function pageStyles() {
  $('#user_preferences_body_width').on('change', ({ currentTarget }) => {
    $(document.body)
      .removeClass('x1000 x1200')
      .addClass(currentTarget.value);
  });

  const { EditStyles } =
    await import(/* webpackChunkName: "edit_styles" */ '@/views/styles/edit');

  new EditStyles('.b-edit_styles');
}

function pageListAndMisc() {
  // восстановление залокированных рекомендаций
  // выбор варианта
  $('.profile-action .controls .b-js-link').on('click', ({ currentTarget }) => {
    const type = $(currentTarget).data('type');

    $(currentTarget)
      .closest('.controls')
      .hide();

    $(currentTarget)
      .closest('.profile-action')
      .find(`.form.${type}`)
      .show();
  });

  // отмена
  $('.profile-action .cancel').on('click', ({ currentTarget }) => {
    $(currentTarget).closest('.profile-action')
      .find('.controls')
      .show();

    $(currentTarget).closest('.profile-action')
      .find('.form')
      .hide();
  });

  // успешное завершение
  $('.profile-action a').on('ajax:success', ({ currentTarget }) => {
    $(currentTarget).closest('.profile-action')
      .find('.cancel')
      .click();
  });

  // nickname changes cleanup
  // выбор варианта
  $('.nickname-changes .controls .b-js-link').on('click', () => {
    $('.nickname-changes .controls').hide();
    $('.nickname-changes .form').show();
  });

  // отмена
  $('.nickname-changes .cancel').on('click', () => {
    $('.nickname-changes .controls').show();
    $('.nickname-changes .form').hide();
  });

  // успешное завершение
  $('.nickname-changes a').on('ajax:success', () => {
    $('.nickname-changes .cancel').click();
  });
}
