function navigateToYearMonth(year, month) {
  window.location.href = window.monthlyClapturesPath + '?year=' + year + '&month=' + month;
}

// Global organizations list for autocomplete
let allOrganizations = [];

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
        const currentValue = select.dataset.currentValue || '';
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

        // If this select has a preconfigured estado, load its municipalities
        if (currentValue) {
          const captureId = select.id.replace('estado_', '');
          loadCounties(currentValue, captureId);
        }
      });
    })
    .catch(err => console.error('Error loading states:', err));
}

function normalizeString(str) {
  if (!str) return '';
  return str
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .trim();
}

function loadAllOrganizations() {
  fetch('/agent/get_organizations')
    .then(r => r.json())
    .then(data => {
      if (!data.organizations) return;
      allOrganizations = data.organizations;
      // Pre-populate existing organizacion-autocomplete fields with current values
      document.querySelectorAll('.organizacion-autocomplete').forEach(input => {
        const currentOrgName = input.dataset.currentOrgName || '';
        if (currentOrgName) {
          input.value = currentOrgName;
        }
      });
    })
    .catch(err => console.error('Error loading organizations:', err));
}

// Edit button handler - open modal
document.addEventListener('click', function(e) {
  if (e.target.closest('.edit-btn')) {
    e.preventDefault();
    e.stopPropagation();
    const btn = e.target.closest('.edit-btn');
    const captureId = btn.dataset.id;
    const modal = document.getElementById(`editModal_${captureId}`);
    if (modal) {
      modal.classList.add('active');

      // Load counties for current estado
      const estadoSelect = modal.querySelector('.estado-select');
      if (estadoSelect) {
        // Use data-current-value if value is empty
        const estado = estadoSelect.value || estadoSelect.dataset.currentValue;
        if (estado) {
          loadCounties(estado, captureId);
        }
      }
    }
  }
});

// Cancel button handler - close modal
document.addEventListener('click', function(e) {
  if (e.target.closest('.cancel-btn')) {
    e.preventDefault();
    const btn = e.target.closest('.cancel-btn');
    const captureId = btn.dataset.captureId;
    const modal = document.getElementById(`editModal_${captureId}`);
    if (modal) {
      modal.classList.remove('active');
    }
  }
});

// Modal close button handler
document.addEventListener('click', function(e) {
  if (e.target.classList.contains('modal-close')) {
    e.preventDefault();
    const modal = e.target.closest('.modal-overlay');
    if (modal) {
      modal.classList.remove('active');
    }
  }
});

// Close modal when clicking outside of modal-content
document.addEventListener('click', function(e) {
  if (e.target.classList.contains('modal-overlay') && e.target.classList.contains('active')) {
    e.target.classList.remove('active');
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

// Organizacion autocomplete handler - show/hide dropdown
document.addEventListener('input', function(e) {
  if (e.target.classList.contains('organizacion-autocomplete')) {
    const input = e.target;
    const captureId = input.id.replace('organizacion_', '');
    const listElement = document.querySelector(`#autocomplete_${captureId}`);
    const searchTerm = input.value;

    if (searchTerm.length === 0) {
      listElement.style.display = 'none';
      return;
    }

    const normalizedSearch = normalizeString(searchTerm);
    const matches = allOrganizations.filter(org =>
      normalizeString(org).includes(normalizedSearch)
    );

    if (matches.length === 0) {
      listElement.style.display = 'none';
      return;
    }

    listElement.innerHTML = '';
    matches.forEach(match => {
      const li = document.createElement('li');
      li.textContent = match;
      li.style.padding = '10px 12px';
      li.style.cursor = 'pointer';
      li.style.borderBottom = '1px solid #e0e0e0';
      li.style.fontSize = '13px';
      li.style.transition = 'background-color 0.2s';

      li.addEventListener('mouseover', () => {
        li.style.backgroundColor = '#f5f5f5';
      });
      li.addEventListener('mouseout', () => {
        li.style.backgroundColor = 'white';
      });
      li.addEventListener('click', () => {
        input.value = match;
        listElement.style.display = 'none';
      });
      listElement.appendChild(li);
    });

    listElement.style.display = 'block';
  }
});

// Close autocomplete dropdown when clicking outside
document.addEventListener('click', function(e) {
  if (!e.target.classList.contains('organizacion-autocomplete')) {
    document.querySelectorAll('.organizacion-autocomplete-list').forEach(list => {
      list.style.display = 'none';
    });
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

      // Obtener valores originales del atributo data
      const currentFullCode = municipioSelect.dataset.currentFullcode || '';
      const currentMunicipio = municipioSelect.dataset.currentValue || '';
      const currentEstado = municipioSelect.dataset.currentEstado || '';

      municipioSelect.innerHTML = '<option value="">Seleccionar municipio</option>';
      data.counties.forEach(county => {
        const opt = document.createElement('option');
        const countyName = county[0];
        const countyFullCode = county[1];
        opt.value = countyName;
        opt.textContent = `${countyName} - ${countyFullCode}`;

        // Lógica de selección:
        // 1. Si hay full_code válido, seleccionar municipio que coincida con ese full_code
        // 2. Si no hay full_code pero hay estado identificable, seleccionar el estado
        // 3. Sino, dejar vacío
        if (currentFullCode && countyFullCode === currentFullCode) {
          opt.selected = true;
        } else if (!currentFullCode && currentEstado && countyName === currentEstado) {
          opt.selected = true;
        }

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
