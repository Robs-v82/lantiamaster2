document.addEventListener('DOMContentLoaded', function() {
  let searchResults = [];

  // ────────────────────────────────────────────────────────────────
  // BÚSQUEDA DE MIEMBROS CRIMINALES
  // ────────────────────────────────────────────────────────────────
  const searchBtn = document.getElementById('search-btn');
  if (searchBtn) {
    searchBtn.addEventListener('click', function() {
      const url = this.dataset.searchUrl;
      const btn = this;

      if (!url || url === '#') {
        const statusMsg = document.getElementById('status-msg');
        statusMsg.innerHTML = 'Error: Ruta de búsqueda no configurada.';
        statusMsg.style.color = '#d43e40';
        return;
      }

      btn.disabled = true;
      const statusMsg = document.getElementById('status-msg');
      statusMsg.innerHTML = '<i class="material-icons" style="vertical-align:middle; font-size:16px; animation:agent-spin 0.7s linear infinite;">cached</i> Buscando miembros criminales...';
      statusMsg.style.color = '#888';

      fetch(url, {
        method: 'GET',
        headers: { 'Accept': 'application/json' }
      })
      .then(r => {
        if (!r.ok) throw new Error(`HTTP ${r.status}: ${r.statusText}`);
        return r.json();
      })
      .then(data => {
        searchResults = data.articles || [];

        if (searchResults.length === 0) {
          statusMsg.innerHTML = 'No se encontraron resultados.';
          statusMsg.style.color = '#888';
          btn.disabled = false;
          return;
        }

        // Renderizar tarjetas
        const grid = document.getElementById('results-grid');
        grid.innerHTML = searchResults.map((result, idx) => {
          const source = result.source || result.link || '';
          const sourceDomain = source.replace(/^https?:\/\/(www\.)?/, '').split('/')[0];
          const title = result.title || '(Sin título)';
          const snippet = result.snippet || '(Sin descripción)';

          return `
            <div class="news-card" data-result-index="${idx}">
              <div class="card-source">${sourceDomain}</div>
              <div class="card-date">${new Date().toLocaleDateString('es-MX')}</div>
              <div class="card-title">${title}</div>
              <div class="card-snippet">${snippet}</div>
              <a href="${source}" target="_blank" rel="noopener" class="card-link">
                Ver artículo <i class="material-icons" style="font-size:14px;">open_in_new</i>
              </a>
            </div>
          `;
        }).join('');

        statusMsg.innerHTML = `Encontrados: <strong>${searchResults.length}</strong> resultados`;
        statusMsg.style.color = '#33333C';

        // Mostrar sección de extracción
        document.getElementById('extraction-section').style.display = 'block';

        btn.disabled = false;
      })
      .catch(err => {
        console.error('[criminal_members.js] Error:', err);
        statusMsg.innerHTML = `Error: ${err.message}`;
        statusMsg.style.color = '#d43e40';
        btn.disabled = false;
      });
    });
  }
});
