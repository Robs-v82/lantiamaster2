function navigateToYearMonth(year, month) {
  window.location.href = window.monthlyClapturesPath + '?year=' + year + '&month=' + month;
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', function() {
  loadAllStates();
  loadAllOrganizations();
});

function loadAllStates() {
  fetch('/agent/get_states')
    .then(r => r.json())
    .then(data => {
      if (!data.states) return;
      document.querySelectorAll('.estado-select').forEach(select => {
        const currentValue = select.value;
        select.innerHTML = '<option value="">Seleccionar estado</option>';
        data.states.forEach(state => {
          const opt = document.createElement('option');
          opt.value = state;
          opt.textContent = state;
          if (currentValue === state) opt.selected = true;
          select.appendChild(opt);
        });
        // Reinitialize Materialize FormSelect after loading
        const instance = M.FormSelect.getInstance(select);
        if (instance) instance.destroy();
        M.FormSelect.init(select);
      });
    })
    .catch(err => console.error('Error loading states:', err));
}

function loadAllOrganizations() {
  fetch('/agent/get_organizations')
    .then(r => r.json())
    .then(data => {
      if (!data.organizations) return;
      document.querySelectorAll('.organizacion-select').forEach(select => {
        const currentValue = select.value;
        select.innerHTML = '<option value="">Seleccionar organización</option>';
        data.organizations.forEach(org => {
          const opt = document.createElement('option');
          opt.value = org;
          opt.textContent = org;
          if (currentValue === org) opt.selected = true;
          select.appendChild(opt);
        });
        // Reinitialize Materialize FormSelect after loading
        const instance = M.FormSelect.getInstance(select);
        if (instance) instance.destroy();
        M.FormSelect.init(select);
      });
    })
    .catch(err => console.error('Error loading organizations:', err));
}

// Edit button handler - use Materialize API
document.addEventListener('click', function(e) {
  if (e.target.closest('.edit-btn')) {
    e.preventDefault();
    e.stopPropagation();
    const btn = e.target.closest('.edit-btn');
    const captureId = btn.dataset.id;
    const li = document.querySelector(`li[data-capture-id="${captureId}"]`);
    if (li) {
      const instance = M.Collapsible.getInstance(li);
      if (instance) instance.open();

      // Load counties for current estado
      const estadoSelect = li.querySelector('.estado-select');
      if (estadoSelect && estadoSelect.value) {
        loadCounties(estadoSelect.value, captureId);
      }
    }
  }
});

// Cancel button handler - use Materialize API
document.addEventListener('click', function(e) {
  if (e.target.closest('.cancel-btn')) {
    e.preventDefault();
    const btn = e.target.closest('.cancel-btn');
    const captureId = btn.dataset.id;
    const li = document.querySelector(`li[data-capture-id="${captureId}"]`);
    if (li) {
      const instance = M.Collapsible.getInstance(li);
      if (instance) instance.close();
    }
  }
});

// Cancel delete handler
document.addEventListener('click', function(e) {
  if (e.target.closest('.cancel-delete-btn')) {
    e.preventDefault();
    const btn = e.target.closest('.cancel-delete-btn');
    const captureId = btn.dataset.id;
    const deleteConfirm = document.getElementById(`deleteConfirm_${captureId}`);
    if (deleteConfirm) {
      deleteConfirm.style.display = 'none';
    }
  }
});

// Link button handler
document.addEventListener('click', function(e) {
  if (e.target.closest('.link-btn')) {
    e.preventDefault();
    const btn = e.target.closest('.link-btn');
    const url = btn.dataset.url;
    if (url) window.open(url, '_blank');
  }
});

// Delete button handler
document.addEventListener('click', function(e) {
  if (e.target.closest('.delete-btn')) {
    e.preventDefault();
    const btn = e.target.closest('.delete-btn');
    const captureId = btn.dataset.id;
    const deleteConfirm = document.getElementById(`deleteConfirm_${captureId}`);
    if (deleteConfirm) {
      deleteConfirm.style.display = 'block';
    }
  }
});

// Estado change handler - load municipalities
document.addEventListener('change', function(e) {
  if (e.target.classList.contains('estado-select')) {
    const estado = e.target.value;
    const selectId = e.target.id;
    const captureId = selectId.replace('estado_', '');
    loadCounties(estado, captureId);
  }
});

function loadCounties(estado, captureId) {
  const municipioSelect = document.querySelector(`#municipio_${captureId}`);
  if (!municipioSelect) return;

  if (!estado) {
    municipioSelect.innerHTML = '<option value="">Seleccionar municipio</option>';
    // Reinitialize Materialize FormSelect
    const instance = M.FormSelect.getInstance(municipioSelect);
    if (instance) instance.destroy();
    M.FormSelect.init(municipioSelect);
    return;
  }

  fetch(`/agent/get_counties?state=${encodeURIComponent(estado)}`)
    .then(r => r.json())
    .then(data => {
      if (!data.counties) {
        municipioSelect.innerHTML = '<option value="">Seleccionar municipio</option>';
        // Reinitialize Materialize FormSelect
        const instance = M.FormSelect.getInstance(municipioSelect);
        if (instance) instance.destroy();
        M.FormSelect.init(municipioSelect);
        return;
      }
      const currentValue = municipioSelect.value;
      municipioSelect.innerHTML = '<option value="">Seleccionar municipio</option>';
      data.counties.forEach(county => {
        const opt = document.createElement('option');
        const countyName = county[0];
        const countyFullCode = county[1];
        opt.value = countyName;
        opt.textContent = `${countyName} - ${countyFullCode}`;
        if (currentValue === countyName) opt.selected = true;
        municipioSelect.appendChild(opt);
      });
      // Reinitialize Materialize FormSelect after loading
      const instance = M.FormSelect.getInstance(municipioSelect);
      if (instance) instance.destroy();
      M.FormSelect.init(municipioSelect);
    })
    .catch(err => {
      console.error('Error loading counties:', err);
      municipioSelect.innerHTML = '<option value="">Error al cargar municipios</option>';
      // Reinitialize Materialize FormSelect
      const instance = M.FormSelect.getInstance(municipioSelect);
      if (instance) instance.destroy();
      M.FormSelect.init(municipioSelect);
    });
}

// Save button handler
document.addEventListener('click', function(e) {
  if (e.target.closest('.save-btn')) {
    e.preventDefault();
    const btn = e.target.closest('.save-btn');
    const captureId = btn.dataset.captureId;
    const form = document.getElementById(`editForm_${captureId}`);

    if (!form) return;

    const formData = new FormData(form);

    fetch(`/agent/detention_captures/${captureId}`, {
      method: 'PATCH',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      }
    })
    .then(r => r.json())
    .then(data => {
      if (data.success) {
        alert('Captura actualizada exitosamente');
        location.reload();
      } else {
        alert('Error: ' + (data.errors ? data.errors.join(', ') : 'Error desconocido'));
      }
    })
    .catch(err => {
      alert('Error al actualizar la captura');
      console.error(err);
    });
  }
});

// Confirm delete handler
document.addEventListener('click', function(e) {
  if (e.target.closest('.confirm-delete-btn')) {
    e.preventDefault();
    const btn = e.target.closest('.confirm-delete-btn');
    const captureId = btn.dataset.id;

    fetch(`/agent/detention_captures/${captureId}`, {
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Accept': 'application/json'
      }
    })
    .then(r => r.json())
    .then(data => {
      if (data.success) {
        alert('Captura eliminada exitosamente');
        location.reload();
      } else {
        alert('Error: ' + (data.errors ? data.errors.join(', ') : 'Error desconocido'));
      }
    })
    .catch(err => {
      alert('Error al eliminar la captura');
      console.error(err);
    });
  }
});
