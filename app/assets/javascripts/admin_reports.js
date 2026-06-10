$(function() {
  // Inicializar componentes Materialize con jQuery
  $('.modal').modal();
  $('select').formSelect();

  const reportTypeSelect = document.getElementById('report-type');
  const semanalFields = document.getElementById('semanal-fields');
  const monthlyFields = document.getElementById('monthly-fields');
  const generateBtn = document.getElementById('generate-btn');
  const backBtn = document.getElementById('back-btn');
  const approveBtn = document.getElementById('approve-btn');
  const finishBtn = document.getElementById('finish-btn');

  let currentBriefingId = null;

  // Mostrar/ocultar campos según tipo
  $(document).on('change', '#report-type', function() {
    const value = this.value;
    if (value === 'briefing_semanal') {
      semanalFields.style.display = 'block';
      monthlyFields.style.display = 'none';
    } else if (['reporte_riesgo', 'reporte_conflictividad', 'reporte_prospectiva'].includes(value)) {
      semanalFields.style.display = 'none';
      monthlyFields.style.display = 'block';
    } else {
      semanalFields.style.display = 'none';
      monthlyFields.style.display = 'none';
    }
    $('select').formSelect();
  });

  // Generar resumen
  $(document).on('click', '#generate-btn', function() {
    const reportType = $('#report-type').val();
    const pdfFile = document.getElementById('pdf-file').files[0];

    if (!reportType || !pdfFile) {
      showError('Selecciona tipo de reporte y PDF');
      return;
    }

    showLoading(true);

    const formData = new FormData();
    formData.append('report_type', reportType);
    formData.append('pdf', pdfFile);
    formData.append('number', $('#briefing-number').val());
    formData.append('month', $('#report-month').val());
    formData.append('year', $('#report-year').val());

    const uploadUrl = $('[data-upload-url]').data('upload-url');

    $.ajax({
      url: uploadUrl,
      type: 'POST',
      data: formData,
      processData: false,
      contentType: false,
      headers: {
        'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
      },
      success: function(data) {
        currentBriefingId = data.briefing_id;
        $('#summary-text').val(data.summary);
        $('#recipient-count-display').text(`Total de destinatarios: ${data.recipients_count || '(calculando...)'}`);

        $('#step-1').hide();
        $('#step-2').show();
        showError('', false);
      },
      error: function(err) {
        const error = err.responseJSON ? err.responseJSON.error : 'Error al generar resumen';
        showError(error);
      },
      complete: function() {
        showLoading(false);
      }
    });
  });

  // Botón cancelar
  $(document).on('click', '#back-btn', function() {
    $('#step-2').hide();
    $('#step-1').show();
    currentBriefingId = null;
    $('#pdf-file').val('');
  });

  // Aprobar y enviar
  $(document).on('click', '#approve-btn', function() {
    if (!currentBriefingId) return;

    showLoading(true);
    const summary = $('#summary-text').val();
    const approveUrl = $('[data-approve-url]').data('approve-url').replace('BRIEFING_ID', currentBriefingId);

    $.ajax({
      url: approveUrl,
      type: 'POST',
      data: JSON.stringify({ summary: summary }),
      contentType: 'application/json',
      headers: {
        'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
      },
      success: function(data) {
        $('#step-2').hide();
        $('#step-3').show();
        $('#confirmation-details').text(`Se envió a ${data.recipients_count} suscriptores. ID: ${data.briefing_id}`);
        showError('', false);
      },
      error: function(err) {
        const error = err.responseJSON ? err.responseJSON.error : 'Error al aprobar';
        showError(error);
      },
      complete: function() {
        showLoading(false);
      }
    });
  });

  // Finalizar
  $(document).on('click', '#finish-btn', function() {
    $('#step-3').hide();
    $('#step-1').show();
    currentBriefingId = null;
    $('#pdf-file').val('');
    $('#report-type').val('');
    $('select').formSelect();
    location.reload();
  });

  function showLoading(show) {
    $('#loading-indicator').toggle(show);
  }

  function showError(message, show = true) {
    const errorDiv = $('#error-message');
    errorDiv.text(message);
    errorDiv.toggle(show && message);
  }
});
