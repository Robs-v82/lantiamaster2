document.addEventListener('DOMContentLoaded', function() {
  let searchResults = [];
  let extractionLog = [];
  let isExtracting = false;

  // ────────────────────────────────────────────────────────────────
  // 1. BÚSQUEDA DE MEDIOS
  // ────────────────────────────────────────────────────────────────
  document.getElementById('search-btn').addEventListener('click', function() {
    const url = this.dataset.searchUrl;
    const btn = this;

    btn.disabled = true;
    const statusMsg = document.getElementById('status-msg');
    statusMsg.innerHTML = '<i class="material-icons" style="vertical-align:middle; font-size:16px; animation:agent-spin 0.7s linear infinite;">cached</i> Buscando medios...';
    statusMsg.style.color = '#888';

    fetch(url, {
      method: 'GET',
      headers: { 'Accept': 'application/json' }
    })
    .then(r => r.json())
    .then(data => {
      searchResults = data.results || [];

      if (searchResults.length === 0) {
        statusMsg.innerHTML = 'No se encontraron resultados.';
        statusMsg.style.color = '#888';
        btn.disabled = false;
        return;
      }

      // Mostrar tarjetas
      const grid = document.getElementById('results-grid');
      grid.innerHTML = searchResults.map((result, idx) => `
        <div class="news-card" data-result-index="${idx}">
          <div class="card-source">${result.source_domain || 'News'}</div>
          <div class="card-date">${result.published_date || new Date().toLocaleDateString('es-MX')}</div>
          <div class="card-title">${result.title || '(Sin título)'}</div>
          <div class="card-snippet">${result.snippet || '(Sin descripción)'}</div>
          <a href="${result.link}" target="_blank" rel="noopener" class="card-link">
            Ver artículo <i class="material-icons" style="font-size:14px;">open_in_new</i>
          </a>
        </div>
      `).join('');

      statusMsg.innerHTML = `Encontrados: <strong>${searchResults.length}</strong> resultados`;
      statusMsg.style.color = '#33333C';

      // Mostrar sección de extracción
      document.getElementById('extraction-section').style.display = 'block';
      extractionLog = [];

      btn.disabled = false;
    })
    .catch(err => {
      statusMsg.innerHTML = `Error: ${err.message}`;
      statusMsg.style.color = '#d43e40';
      btn.disabled = false;
    });
  });

  // ────────────────────────────────────────────────────────────────
  // 2. EXTRACCIÓN BATCH
  // ────────────────────────────────────────────────────────────────
  document.getElementById('extract-btn').addEventListener('click', function() {
    if (isExtracting || searchResults.length === 0) return;

    const url = this.dataset.extractUrl;
    const btn = this;
    const progressArea = document.getElementById('progress-area');
    const progressMsg = document.getElementById('progress-msg');
    const progressBar = document.getElementById('progress-bar');
    const summaryArea = document.getElementById('summary-area');

    isExtracting = true;
    btn.disabled = true;
    extractionLog = [];
    progressArea.style.display = 'block';
    summaryArea.style.display = 'none';

    const urlsToExtract = searchResults.map(r => r.link);

    fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ urls: urlsToExtract })
    })
    .then(r => r.json())
    .then(data => {
      extractionLog = data.log || [];
      const summary = data.summary || {};

      // Mostrar progreso
      progressMsg.innerHTML = `Completado: ${summary.extracted || 0}/${searchResults.length} URLs`;
      progressBar.style.width = '100%';

      // Mostrar resumen
      summaryArea.innerHTML = `
        <h6>Resumen de extracción</h6>
        <div class="summary-row">
          <span class="summary-label">URLs procesadas:</span>
          <span class="summary-value">${summary.total || 0}</span>
        </div>
        <div class="summary-row">
          <span class="summary-label">Hits extraídos:</span>
          <span class="summary-value highlight">${summary.extracted || 0}</span>
        </div>
        <div class="summary-row">
          <span class="summary-label">Errores:</span>
          <span class="summary-value">${summary.errors || 0}</span>
        </div>
      `;
      summaryArea.style.display = 'block';
      document.getElementById('download-area').style.display = 'flex';

      isExtracting = false;
      btn.disabled = false;
    })
    .catch(err => {
      progressMsg.innerHTML = `Error: ${err.message}`;
      progressMsg.style.color = '#d43e40';
      isExtracting = false;
      btn.disabled = false;
    });
  });

  // ────────────────────────────────────────────────────────────────
  // 3. EXTRACCIÓN DE URL INDIVIDUAL
  // ────────────────────────────────────────────────────────────────
  document.getElementById('manual-url-btn').addEventListener('click', function() {
    const input = document.getElementById('manual-url-input');
    const status = document.getElementById('manual-url-status');
    const url = input.value.trim();

    if (!url) {
      status.innerHTML = 'Ingresa una URL válida.';
      status.style.color = '#d43e40';
      return;
    }

    const extractUrl = input.dataset.extractUrl;
    const btn = this;
    btn.disabled = true;
    status.innerHTML = 'Procesando...';
    status.style.color = '#888';

    fetch(extractUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ url: url })
    })
    .then(r => r.json())
    .then(data => {
      if (data.success) {
        status.innerHTML = '✓ Hit creado exitosamente.';
        status.style.color = '#2e7d32';
        input.value = '';
      } else {
        status.innerHTML = `Error: ${data.error || 'Algo salió mal.'}`;
        status.style.color = '#d43e40';
      }
      btn.disabled = false;
    })
    .catch(err => {
      status.innerHTML = `Error: ${err.message}`;
      status.style.color = '#d43e40';
      btn.disabled = false;
    });
  });

  // ────────────────────────────────────────────────────────────────
  // 4. DESCARGA DE LOG
  // ────────────────────────────────────────────────────────────────
  document.getElementById('download-btn').addEventListener('click', function() {
    if (extractionLog.length === 0) return;

    const csv = extractionLog.map(entry => {
      return `"${entry.url || ''}";"${entry.status || ''}";"${entry.message || ''}"`;
    }).join('\n');

    const header = '"URL";"Status";"Message"\n';
    const blob = new Blob([header + csv], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);

    link.setAttribute('href', url);
    link.setAttribute('download', `media_monitoring_log_${new Date().toISOString().split('T')[0]}.csv`);
    link.style.visibility = 'hidden';

    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  });
});
