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
        const searchResults_map = data.search_results || {};

        // Renderizar tabla de criterios
        const criteriaSection = document.getElementById('criteria-section');
        const criteriaTbody = document.getElementById('criteria-tbody');

        const queries = [
          'empresario narco México vínculos',
          'empresario lavador dinero México',
          'prestanombres crimen organizado México',
          'traficante dinero cartel México',
          'alcalde vínculos crimen organizado México',
          'funcionario corrupción narcotráfico México',
          'gobernador vínculos cártel México',
          'policía corrupción crimen organizado',
          'dinero narcotráfico decomiso México',
          'bienes incautados crimen organizado',
          'operación financiera narcos México',
          'cartel México',
          'Cártel Jalisco Nueva Generación',
          'Cártel de Sinaloa',
          'Mayiza México',
          'Chapitos México',
          'CJNG México',
          'Cárteles Unidos México',
          'Cártel del Noreste',
          'Familia Michoacana México',
          'huachicol México',
          'cobro de cuota México'
        ];

        criteriaTbody.innerHTML = queries.map(query => {
          const count = searchResults_map[query] || 0;
          const hasResults = count > 0;
          const indicator = hasResults ? '✓' : '✗';
          const indicatorColor = hasResults ? '#2e7d32' : '#aaa';
          const rowBg = hasResults ? '#f9f9f9' : '#fafafa';

          return `
            <tr style="background:${rowBg};">
              <td style="font-size:13px; color:#555;">${query}</td>
              <td style="text-align:center; font-size:13px; font-weight:600; color:#333;">${count}</td>
              <td style="text-align:center; font-size:18px; font-weight:bold; color:${indicatorColor};">${indicator}</td>
            </tr>
          `;
        }).join('');

        criteriaSection.style.display = 'block';

        if (searchResults.length === 0) {
          statusMsg.innerHTML = 'No se encontraron resultados.';
          statusMsg.style.color = '#888';
          btn.disabled = false;
          return;
        }

        // Renderizar tarjetas
        const grid = document.getElementById('results-grid');
        grid.innerHTML = searchResults.map((result, idx) => {
          const link = result.link || '';
          const sourceDomain = result.source_domain || 'News';
          const publishedDate = result.published_date || new Date().toLocaleDateString('es-MX');
          const title = result.title || '(Sin título)';
          const snippet = result.snippet || '(Sin descripción)';

          return `
            <div class="news-card" data-result-index="${idx}">
              <div class="card-source">${sourceDomain}</div>
              <div class="card-date">${publishedDate}</div>
              <div class="card-title">${title}</div>
              <div class="card-snippet">${snippet}</div>
              <a href="${link}" target="_blank" rel="noopener" class="card-link">
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
