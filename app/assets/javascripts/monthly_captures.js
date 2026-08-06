function navigateToYearMonth(year, month) {
  window.location.href = window.monthlyClapturesPath + '?year=' + year + '&month=' + month;
}

// Global organizations list for autocomplete (now array of {id, name})
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
      if (!data.states) {
        console.error('[States] Error: no states data');
        return;
      }
      console.log('[States] ✓ Cargados', data.states.length, 'estados');
      document.querySelectorAll('.estado-select').forEach(select => {
        const currentValue = select.dataset.currentValue || '';
        const stateCodes = {};
        select.innerHTML = '<option value="">Seleccionar estado</option>';
        data.states.forEach(state => {
          const opt = document.createElement('option');
          opt.value = state.name;
          opt.textContent = state.name;
          opt.dataset.stateCode = state.code;
          stateCodes[state.name] = state.code;
          if (currentValue === state.name) opt.selected = true;
          select.appendChild(opt);
        });
        select.dataset.stateCodes = JSON.stringify(stateCodes);
        const instance = M.FormSelect.getInstance(select);
        if (instance) instance.destroy();
        M.FormSelect.init(select);
        if (currentValue) {
          const captureId = select.id.replace('estado_', '');
          loadCounties(currentValue, captureId);
        }
      });
    })
    .catch(err => console.error('[States] Error:', err));
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
      if (data.error) {
        console.error('[Organizations] ❌ ERROR del servidor:', data.error);
        return;
      }

      if (!data.organizations || !Array.isArray(data.organizations)) {
        console.error('[Organizations] ❌ Respuesta inválida:', data);
        return;
      }

      const orgCount = data.organizations.length;
      console.log(`[Organizations] ✓ Cargadas ${orgCount} organizaciones`);

      allOrganizations = data.organizations;

      document.querySelectorAll('.organizacion-autocomplete').forEach(input => {
        const currentOrgName = input.dataset.currentOrgName || '';
        if (currentOrgName) {
          input.value = currentOrgName;
        }
      });
    })
    .catch(err => {
      console.error('[Organizations] ❌ Error al cargar:', err.message);
    });
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

      // Reinitialize ALL select elements in this modal with Materialize
      const selects = modal.querySelectorAll('select');
      console.log('[EditBtn] Reinicializando', selects.length, 'selects para captura', captureId);
      selects.forEach(select => {
        const instance = M.FormSelect.getInstance(select);
        if (instance) instance.destroy();
        M.FormSelect.init(select);
      });

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

    if (!listElement) {
      console.error('[Autocomplete] ❌ No encontrado #autocomplete_' + captureId);
      return;
    }

    if (searchTerm.length === 0) {
      listElement.style.display = 'none';
      return;
    }

    if (allOrganizations.length === 0) {
      console.error('[Autocomplete] ❌ allOrganizations está VACÍO - verifica el error en la carga');
      listElement.style.display = 'none';
      return;
    }

    const normalizedSearch = normalizeString(searchTerm);
    const matches = allOrganizations.filter(org => {
      if (!org.name) return false;
      const normalized = normalizeString(org.name);
      return normalized.includes(normalizedSearch);
    });

    if (matches.length === 0) {
      listElement.innerHTML = '<li style="padding: 10px; color: #999; text-align: center;">No hay resultados</li>';
      listElement.style.display = 'block';
      return;
    }

    listElement.innerHTML = '';
    matches.forEach(match => {
      const li = document.createElement('li');
      li.textContent = match.name;
      li.dataset.orgId = match.id;
      li.style.padding = '10px 12px';
      li.style.cursor = 'pointer';
      li.style.borderBottom = '1px solid #e0e0e0';
      li.style.fontSize = '13px';
      li.style.transition = 'background-color 0.2s';
      li.style.backgroundColor = 'white';

      li.addEventListener('mouseover', () => {
        li.style.backgroundColor = '#f5f5f5';
      });
      li.addEventListener('mouseout', () => {
        li.style.backgroundColor = 'white';
      });
      li.addEventListener('click', () => {
        input.value = match.name;
        const orgIdInput = document.querySelector(`input[name="detention_capture[organization_id]"][data-capture-id="${captureId}"]`);
        if (orgIdInput) {
          orgIdInput.value = match.id;
        }
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
    const listsToClose = document.querySelectorAll('.organizacion-autocomplete-list');
    if (listsToClose.length > 0) {
      console.log('[Autocomplete] Click outside detected, closing', listsToClose.length, 'lists');
      listsToClose.forEach(list => {
        if (list.style.display !== 'none') {
          console.log('[Autocomplete] Closing list:', list.id);
          list.style.display = 'none';
        }
      });
    }
  }
});

// Delete button handler
document.addEventListener('click', function(e) {
  if (e.target.closest('.delete-btn')) {
    e.preventDefault();
    const btn = e.target.closest('.delete-btn');
    const captureId = btn.dataset.id;

    if (confirm(`¿Está seguro de que desea eliminar el registro ${captureId}?`)) {
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
  }
});

// Municipio change handler - update full_code hidden field when municipio selected
document.addEventListener('change', function(e) {
  if (e.target.classList.contains('municipio-select')) {
    const municipioSelect = e.target;
    const captureId = municipioSelect.dataset.captureId;
    const selectedOption = municipioSelect.options[municipioSelect.selectedIndex];
    const fullCodeField = document.querySelector(`#full_code_${captureId}`);

    if (fullCodeField && selectedOption && selectedOption.dataset.fullCode) {
      fullCodeField.value = selectedOption.dataset.fullCode;
    }
  }
});

// Boolean select change handler - sync with hidden inputs
document.addEventListener('change', function(e) {
  if (e.target.classList.contains('boolean-select')) {
    const select = e.target;
    const field = select.dataset.booleanField;
    const captureId = select.dataset.captureId;
    const value = select.value;

    const hiddenInput = document.querySelector(`#${field}_value_${captureId}`);
    if (hiddenInput) {
      hiddenInput.value = value;
      console.log(`[BooleanSync] ${field} (capture ${captureId}): valor actualizado a "${value}"`);
    }
  }
});

// Select with hidden input change handler - sync genero, rol, etc.
document.addEventListener('change', function(e) {
  if (e.target.classList.contains('select-with-hidden')) {
    const select = e.target;
    const field = select.dataset.hiddenField;
    const captureId = select.dataset.captureId;
    const value = select.value;

    const hiddenInput = document.querySelector(`#${field}_value_${captureId}`);
    if (hiddenInput) {
      hiddenInput.value = value;
      console.log(`[SelectSync] ${field} (capture ${captureId}): valor actualizado a "${value}"`);
    }
  }
});

// Estado change handler - load municipalities and set full_code if only state selected
document.addEventListener('change', function(e) {
  if (e.target.classList.contains('estado-select')) {
    const estadoSelect = e.target;
    const estado = estadoSelect.value;
    const selectId = estadoSelect.id;
    const captureId = selectId.replace('estado_', '');

    // Get state code and construct full_code for state-only selection
    if (estado) {
      const stateCodes = JSON.parse(estadoSelect.dataset.stateCodes || '{}');
      const stateCode = stateCodes[estado];
      if (stateCode) {
        // Set full_code hidden field to state_code + "000" when only state is changed
        const fullCodeField = document.querySelector(`#full_code_${captureId}`);
        const municipioSelect = document.querySelector(`#municipio_${captureId}`);
        if (fullCodeField && municipioSelect && !municipioSelect.value) {
          // Only set if municipio is empty (user only changed state)
          fullCodeField.value = stateCode + '000';
        }
      }
    }

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
        opt.value = countyName;  // Display name as value
        opt.textContent = `${countyName} - ${countyFullCode}`;  // Display name and full_code
        opt.dataset.fullCode = countyFullCode;  // Store full_code in data attribute

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
    const captureId = btn.dataset.captureId || btn.getAttribute('data-capture-id');
    const form = document.getElementById(`editForm_${captureId}`);

    console.log('[SaveBtn] ✓ Click detectado en save-btn, captureId:', captureId);

    if (!form) {
      console.error('[SaveBtn] ❌ Formulario no encontrado: editForm_' + captureId);
      return;
    }

    const formData = new FormData(form);

    console.log('[SaveBtn] FormData fields:', Array.from(formData.keys()));
    console.log('[SaveBtn] FormData values:');
    for (let [key, value] of formData.entries()) {
      console.log(`  ${key}: ${value}`);
    }

    console.log('[SaveBtn] Enviando PATCH a /agent/detention_captures/' + captureId);

    fetch(`/agent/detention_captures/${captureId}`, {
      method: 'PATCH',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      }
    })
    .then(r => {
      console.log('[SaveBtn] Response status:', r.status);
      return r.json();
    })
    .then(data => {
      console.log('[SaveBtn] Response data:', data);
      if (data.success) {
        alert('Captura actualizada exitosamente');
        location.reload();
      } else {
        alert('Error: ' + (data.errors ? data.errors.join(', ') : 'Error desconocido'));
      }
    })
    .catch(err => {
      console.error('[SaveBtn] ❌ Fetch error:', err);
      alert('Error al actualizar la captura');
    });
  }
});


