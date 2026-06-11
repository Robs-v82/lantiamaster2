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
  let currentRecipientsCount = 0;
  let testUsersCount = 2; // Siempre 2 usuarios del dominio @lantiaintelligence.com

  // Inicializar etiqueta, instrucción y banner según estado inicial
  const isInitiallyTest = $('#test-mode-toggle').val() === 'true';
  const initialLabelText = isInitiallyTest
    ? 'Enviar solo a @lantiaintelligence.com (Modo Prueba)'
    : 'Enviar a todos los usuarios activos (Modo Producción)';
  const initialInstructionText = isInitiallyTest
    ? 'Activa para enviar a prueba. Desactiva para enviar a todos'
    : 'Estás en modo producción - se enviará a todos los usuarios activos';
  $('#test-mode-label').text(initialLabelText);
  $('#test-mode-instruction').text(initialInstructionText);

  // Inicializar banner
  if (isInitiallyTest) {
    $('#mode-banner').html('<strong style="color: #856404;">⚠️ VERSIÓN DE PRUEBA</strong><p style="margin: 10px 0 0 0; font-size: 13px; color: #856404;">Los correos se enviarán solo a usuarios del dominio @lantiaintelligence.com</p>');
    $('#mode-banner').css('background-color', '#fff3cd').css('border-left-color', '#ffc107');
  } else {
    $('#mode-banner').html('<strong style="color: #2e7d32;">✓ MODO PRODUCCIÓN ACTIVO</strong><p style="margin: 10px 0 0 0; font-size: 13px; color: #2e7d32;">Los correos se enviarán a todos los usuarios activos suscritos</p>');
    $('#mode-banner').css('background-color', '#e8f5e9').css('border-left-color', '#4caf50');
  }

  // Función para cargar y mostrar la lista de correos en Step 2
  function loadRecipientsListInStep2() {
    const testMode = $('#test-mode-toggle').val() === 'true';

    $.ajax({
      url: '/admin/reportes/calculate_recipients',
      type: 'GET',
      data: { test_mode: testMode },
      headers: {
        'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
      },
      success: function(data) {
        if (data.recipients_emails && data.recipients_emails.length > 0) {
          const emailList = data.recipients_emails.map(email => `<li>${email}</li>`).join('');
          $('#emails-ul').html(emailList);
          $('#test-emails-list').show();
        } else {
          $('#test-emails-list').hide();
        }
      },
      error: function() {
        console.error('Error loading recipients list');
      }
    });
  }

  // Función para actualizar la leyenda de destinatarios
  function updateRecipientCountDisplay() {
    const isTestMode = $('#test-mode-toggle').val() === 'true';
    let displayText = '';

    if (isTestMode) {
      displayText = `Se enviará a ${testUsersCount} usuario(s) de @lantiaintelligence.com`;
    } else {
      if (currentRecipientsCount > 0) {
        displayText = `Se enviará a ${currentRecipientsCount} usuario(s) en total`;
      } else {
        displayText = `Se enviará a todos los usuarios activos`;
      }
    }

    // Actualizar en Step 1 - SIEMPRE mostrar
    $('#recipient-count-display-step1').text(displayText).show();

    // Actualizar en Step 2 (siempre que exista)
    $('#recipient-count-display').text(displayText);
  }

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
        // No hay briefing_id persistente durante el upload (está en sesión)
        // currentBriefingId se asignará en el approve
        const reportType = $('#report-type').val();

        // Validar máximo 180 palabras
        const summaryText = data.summary || '';
        const wordCount = summaryText.trim().split(/\s+/).length;
        let processedSummary = summaryText;

        if (wordCount > 180) {
          const words = summaryText.trim().split(/\s+/);
          processedSummary = words.slice(0, 180).join(' ') + '...';
          showError('El resumen se truncó a máximo 180 palabras', true);
        }

        $('#summary-text').val(processedSummary);
        testUsersCount = 2; // Siempre 2 usuarios del dominio @lantiaintelligence.com

        // Llenar previsualización del correo
        const monthVal = $('#report-month').val();
        const yearVal = $('#report-year').val();

        let introText = '';
        let summaryLegend = '';

        if (reportType === 'briefing_semanal') {
          introText = `Le enviamos adjunta la briefing semanal.`;
          summaryLegend = 'Esta semana desarrollamos los siguientes temas:';
        } else {
          const monthNames = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
                             'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
          const monthName = monthNames[parseInt(monthVal) - 1];
          introText = `Le enviamos adjunta la ${data.report_type} de ${monthName} de ${yearVal}.`;
          summaryLegend = 'Este mes desarrollamos los siguientes temas:';
        }

        $('#email-body-intro').text(introText);
        $('#email-body-summary-legend').text(summaryLegend);
        $('#email-body-summary').text(processedSummary);

        $('#step-1').hide();
        $('#step-2').show();
        updateRecipientCountDisplay();

        // Cargar lista de correos en Step 2
        loadRecipientsListInStep2();

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

  // Toggle test mode - hacer AJAX para calcular dinámicamente
  $(document).on('click', '#test-mode-toggle-switch', function() {
    const hiddenInput = $('#test-mode-toggle');
    const isCurrentlyTest = hiddenInput.val() === 'true';
    const newState = isCurrentlyTest ? 'false' : 'true';

    hiddenInput.val(newState);

    // Animar el círculo del toggle
    const toggleSwitch = $(this);
    const circle = toggleSwitch.find('.toggle-circle');

    if (newState === 'true') {
      toggleSwitch.css('background-color', '#1976d2');
      circle.css('transform', 'translateX(0)');
    } else {
      toggleSwitch.css('background-color', '#4caf50');
      circle.css('transform', 'translateX(22px)');
    }

    // Hacer AJAX para obtener el número dinámico de usuarios
    $.ajax({
      url: '/admin/reportes/calculate_recipients',
      type: 'GET',
      data: { test_mode: newState },
      headers: {
        'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
      },
      success: function(data) {
        const count = data.recipients_count;

        // Actualizar la etiqueta, instrucción y banner del toggle
        let labelText = '';
        let instructionText = '';
        if (newState === 'true') {
          labelText = 'Enviar solo a @lantiaintelligence.com (Modo Prueba)';
          instructionText = 'Activa para enviar a prueba. Desactiva para enviar a todos';
          $('#mode-banner').html('<strong style="color: #856404;">⚠️ VERSIÓN DE PRUEBA</strong><p style="margin: 10px 0 0 0; font-size: 13px; color: #856404;">Los correos se enviarán solo a usuarios del dominio @lantiaintelligence.com</p>');
          $('#mode-banner').css('background-color', '#fff3cd').css('border-left-color', '#ffc107');
        } else {
          labelText = 'Enviar a todos los usuarios activos (Modo Producción)';
          instructionText = 'Estás en modo producción - se enviará a todos los usuarios activos';
          $('#mode-banner').html('<strong style="color: #2e7d32;">✓ MODO PRODUCCIÓN ACTIVO</strong><p style="margin: 10px 0 0 0; font-size: 13px; color: #2e7d32;">Los correos se enviarán a todos los usuarios activos suscritos</p>');
          $('#mode-banner').css('background-color', '#e8f5e9').css('border-left-color', '#4caf50');
        }
        $('#test-mode-label').text(labelText);
        $('#test-mode-instruction').text(instructionText);

        // Actualizar la leyenda debajo del toggle
        let displayText = '';
        if (newState === 'true') {
          displayText = `Se enviará a ${count} usuario(s) de @lantiaintelligence.com`;
        } else {
          displayText = `Se enviará a ${count} usuario(s) en total`;
        }

        $('#recipient-count-display-step1').text(displayText).show();
        $('#recipient-count-display').text(displayText);

        // Si estamos en Step 2, actualizar también la lista de correos
        if ($('#step-2').is(':visible')) {
          loadRecipientsListInStep2();
        }
      },
      error: function() {
        console.error('Error calculating recipients');
      }
    });
  });

  // Aprobar y enviar
  $(document).on('click', '#approve-btn', function() {
    showLoading(true);
    const summary = $('#summary-text').val();
    const testMode = $('#test-mode-toggle').val() === 'true';
    const approveUrl = '/admin/reportes/approve';

    $.ajax({
      url: approveUrl,
      type: 'POST',
      data: JSON.stringify({ summary: summary, test_mode: testMode }),
      contentType: 'application/json',
      headers: {
        'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
      },
      success: function(data) {
        $('#step-2').hide();
        $('#step-3').show();

        // Mostrar lista de correos en step 3
        if (data.recipients_emails && data.recipients_emails.length > 0) {
          const recipientsList = data.recipients_emails.map(email => `<li>${email}</li>`).join('');
          $('#recipients-emails-ul').html(recipientsList);
          $('#recipients-emails-list').show();
        }

        let confirmationText = `Se envió a ${data.recipients_count} `;
        if (data.test_mode) {
          confirmationText += `usuario(s) de prueba. ID: ${data.briefing_id}`;
        } else {
          confirmationText += `suscriptor(es). ID: ${data.briefing_id}`;
        }
        $('#confirmation-details').text(confirmationText);
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
