function escHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function initAgentDetentions() {
  var btn = document.getElementById('search-btn');
  if (!btn) return;

  btn.addEventListener('click', function () {
    var status = document.getElementById('status-msg');
    var grid   = document.getElementById('results-grid');
    var url    = btn.getAttribute('data-search-url');

    btn.disabled    = true;
    btn.innerHTML   = '<span class="agent-spinner"></span> Buscando…';
    status.textContent = 'Lanzando 6 búsquedas en paralelo…';
    grid.innerHTML  = '';

    var csrfMeta  = document.querySelector('meta[name="csrf-token"]');
    var csrfToken = csrfMeta ? csrfMeta.content : '';

    fetch(url, {
      headers: { 'X-CSRF-Token': csrfToken, 'Accept': 'application/json' }
    })
    .then(function (r) { return r.json(); })
    .then(function (data) {
      if (data.error) { status.textContent = 'Error: ' + data.error; return; }

      var articles = data.articles || [];
      status.textContent = articles.length
        ? articles.length + ' noticias encontradas (duplicados eliminados)'
        : 'No se encontraron noticias.';

      articles.forEach(function (a) {
        var domain;
        try { domain = new URL(a.link).hostname.replace('www.', ''); }
        catch (e) { domain = a.source || ''; }

        var card = document.createElement('div');
        card.className = 'news-card';
        card.innerHTML =
          '<div style="display:flex;justify-content:space-between;align-items:center;">' +
            '<span class="card-source">' + escHtml(domain)       + '</span>' +
            '<span class="card-date">'   + escHtml(a.date || '') + '</span>' +
          '</div>' +
          '<div class="card-title">'   + escHtml(a.title   || '') + '</div>' +
          '<div class="card-snippet">' + escHtml(a.snippet || '') + '</div>' +
          '<a class="card-link" href="' + escHtml(a.link) + '" target="_blank" rel="noopener">' +
            'Ver nota <i class="material-icons" style="font-size:14px;">open_in_new</i>' +
          '</a>';
        grid.appendChild(card);
      });
    })
    .catch(function (err) {
      status.textContent = 'Error de red: ' + err.message;
    })
    .finally(function () {
      btn.disabled  = false;
      btn.innerHTML = '<i class="material-icons" style="font-size:18px;">search</i> Buscar noticias del día';
    });
  });
}

document.addEventListener('DOMContentLoaded', initAgentDetentions);
