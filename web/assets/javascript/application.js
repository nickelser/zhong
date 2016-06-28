$(function() {
  $.timeago.settings.allowFuture = true;
  $.timeago.settings.refreshMillis = 0;
  $("time").timeago();

  $(document).on("click", "[data-confirm]", function() {
    return confirm($(this).attr('data-confirm'));
  });

  $(document).on("click", "[data-toggle]", function() {
    $($(this).attr('data-target')).toggle();
  });
});
