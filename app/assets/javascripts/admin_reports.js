document.addEventListener('DOMContentLoaded', function() {
  M.AutoInit(); // Inicializar componentes Materialize

  const reportTypeSelect = document.getElementById('report-type');
  const semanalFields = document.getElementById('semanal-fields');
  const monthlyFields = document.getElementById('monthly-fields');
  const generateBtn = document.getElementById('generate-btn');
  const backBtn = document.getElementById('back-btn');
  const approveBtn = document.getElementById('approve-btn');
  const finishBtn = document.getElementById('finish-btn');

  let currentBriefingId = null;

  // Mostrar/ocultar campos según tipo
  reportTypeSelect.addEventListener('change', function() {
    if (this.value === 'briefing_semanal') {
      semanalFields.style.display = 'block';
      monthlyFields.style.display = 'none';
    } else if (['reporte_riesgo', 'reporte_conflictividad', 'reporte_prospectiva'].includes(this.value)) {
      semanalFields.style.display = 'none';
      monthlyFields.style.display = 'block';
    } else {
      semanalFields.style.display = 'none';
      monthlyFields.style.display = 'none';
    }
    M.FormSelect.init(reportTypeSelect);
  });

  // Generar resumen
  generateBtn.addEventListener('click', async function() {
    const reportType = reportTypeSelect.value;
    const pdfFile = document.getElementById('pdf-file').files[0];

    if (!reportType || !pdfFile) {
      showError('Selecciona tipo de reporte y PDF');
      return;
    }

    showLoading(true);

    const formData = new FormData();
    formData.append('report_type', reportType);
    formData.append('pdf', pdfFile);
    formData.append('number', document.getElementById('briefing-number').value);
    formData.append('month', document.getElementById('report-month').value);
    formData.append('year', document.getElementById('report-year').value);

    try {
      const uploadUrl = document.querySelector('[data-upload-url]').getAttribute('data-upload-url');
      const response = await fetch(uploadUrl, {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      });

      const data = await response.json();

      if (response.ok) {
        currentBriefingId = data.briefing_id;
        document.getElementById('summary-text').value = data.summary;

        const recipientCount = data.recipients_count || calculateRecipientCountUI();
        document.getElementById('recipient-count-display').textContent =
          `Total de destinatarios: ${recipientCount}`;

        document.getElementById('step-1').style.display = 'none';
        document.getElementById('step-2').style.display = 'block';
        showError('', false);
      } else {
        showError(data.error || 'Error al generar resumen');
      }
    } catch (error) {
      showError('Error: ' + error.message);
    } finally {
      showLoading(false);
    }
  });

  // Botón cancelar
  backBtn.addEventListener('click', function() {
    document.getElementById('step-2').style.display = 'none';
    document.getElementById('step-1').style.display = 'block';
    currentBriefingId = null;
    document.getElementById('pdf-file').value = '';
  });

  // Aprobar y enviar
  approveBtn.addEventListener('click', async function() {
    if (!currentBriefingId) return;

    showLoading(true);
    const summary = document.getElementById('summary-text').value;

    try {
      const approveUrl = document.querySelector('[data-approve-url]').getAttribute('data-approve-url')
        .replace(':id', currentBriefingId);

      const response = await fetch(approveUrl, {
        method: 'POST',
        body: JSON.stringify({ summary }),
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      });

      const data = await response.json();

      if (response.ok) {
        document.getElementById('step-2').style.display = 'none';
        document.getElementById('step-3').style.display = 'block';
        document.getElementById('confirmation-details').textContent =
          `Se envió a ${data.recipients_count} suscriptores. ID: ${data.briefing_id}`;
        showError('', false);
      } else {
        showError(data.error || 'Error al aprobar');
      }
    } catch (error) {
      showError('Error: ' + error.message);
    } finally {
      showLoading(false);
    }
  });

  // Finalizar
  finishBtn.addEventListener('click', function() {
    document.getElementById('step-3').style.display = 'none';
    document.getElementById('step-1').style.display = 'block';
    currentBriefingId = null;
    document.getElementById('pdf-file').value = '';
    document.getElementById('report-type').value = '';
    M.FormSelect.init(reportTypeSelect);
    location.reload();
  });

  function showLoading(show) {
    document.getElementById('loading-indicator').style.display = show ? 'block' : 'none';
  }

  function showError(message, show = true) {
    const errorDiv = document.getElementById('error-message');
    errorDiv.textContent = message;
    errorDiv.style.display = show && message ? 'block' : 'none';
  }

  function calculateRecipientCountUI() {
    // Esto es un placeholder; idealmente obtendríamos del servidor
    return '(calculando...)';
  }
});
