function changeCalendarMonth() {
    var month = jQuery('.changeCalendarMonth select[name="Month"]').val();
    var year = jQuery('.changeCalendarMonth select[name="Year"]').val();
    var querystring = jQuery('.changeCalendarMonth #querystring').val();
    window.location.href = "?Month=" + month + "&Year=" + year + "&" + querystring;
}
