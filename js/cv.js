/* eslint-env jquery */
$(document).ready(function () {
  const size = {
    width: window.innerWidth || document.body.clientWidth,
    height: window.innerHeight || document.body.clientHeight
  }

  const width = size.width > 1920 ? 1300 : 850
  const height = size.width > 1920 ? 800 : 580

  $('#dialogimage').attr('src', size.width > 1920 ? 'print.png' : 'print-small.png')

  $('#dialog').dialog(
    {
      minHeight: height,
      minWidth: width,
      modal: true,
      buttons: {
        Ok: function () {
          $(this).dialog('close')
        }
      }
    })
})
