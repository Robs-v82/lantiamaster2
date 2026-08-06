/**
 * Member + Hit Creation - Button Validation Only
 * Validates DetentionCapture records and sets button state
 */

(function() {
  'use strict';

  /**
   * Validates if a DetentionCapture record meets all requirements for Member + Hit creation
   */
  function validateMemberHitRequirements(capture) {
    const errors = [];

    if (!capture.nombre || capture.nombre.trim() === '') {
      errors.push('Falta nombre');
    }
    if (!capture.apellido_paterno || capture.apellido_paterno.trim() === '') {
      errors.push('Falta apellido paterno');
    }
    if (!capture.apellido_materno || capture.apellido_materno.trim() === '') {
      errors.push('Falta apellido materno');
    }
    if (!capture.genero || capture.genero.trim() === '') {
      errors.push('Falta género');
    }
    if (!capture.organization_id) {
      errors.push('Falta organización válida');
    }

    if (!capture.source_url || capture.source_url.trim() === '') {
      errors.push('Falta URL de la nota');
    } else if (!/^https?:\/\//.test(capture.source_url)) {
      errors.push('URL inválida (debe comenzar con http o https)');
    }

    if (!capture.incident_date) {
      errors.push('Falta fecha del incidente');
    }

    if (!capture.full_code || capture.full_code.trim() === '') {
      errors.push('Falta código de ubicación');
    }

    if (!capture.organizacion || capture.organizacion.trim() === '') {
      errors.push('Falta organización para título');
    }
    if (!capture.municipio || capture.municipio.trim() === '') {
      errors.push('Falta municipio para título');
    }
    if (!capture.estado || capture.estado.trim() === '') {
      errors.push('Falta estado para título');
    }

    if (!capture.rol || capture.rol.trim() === '') {
      errors.push('Falta rol asignado');
    }

    if (capture.deleted_at) {
      errors.push('Registro eliminado');
    }

    return {
      valid: errors.length === 0,
      errors: errors
    };
  }

  /**
   * Extracts capture data from table row data attributes
   */
  function getCaptureDataFromRow(row, captureId) {
    return {
      id: captureId,
      nombre: (row.getAttribute('data-nombre') || '').trim(),
      apellido_paterno: (row.getAttribute('data-apellido-paterno') || '').trim(),
      apellido_materno: (row.getAttribute('data-apellido-materno') || '').trim(),
      genero: (row.getAttribute('data-genero') || '').trim(),
      organization_id: row.getAttribute('data-organization-id') || '',
      organizacion: (row.getAttribute('data-organizacion') || '').trim(),
      municipio: (row.getAttribute('data-municipio') || '').trim(),
      estado: (row.getAttribute('data-estado') || '').trim(),
      source_url: (row.getAttribute('data-source-url') || '').trim(),
      incident_date: (row.getAttribute('data-incident-date') || '').trim(),
      full_code: (row.getAttribute('data-full-code') || '').trim(),
      rol: (row.getAttribute('data-rol') || '').trim(),
      alias: (row.getAttribute('data-alias') || '').trim(),
      deleted_at: row.getAttribute('data-deleted-at') || null
    };
  }

  /**
   * Initializes button state based on validation
   */
  function initializeButton(button, captureId) {
    const row = button.closest('tr');
    if (!row) return;

    const captureData = getCaptureDataFromRow(row, captureId);
    const validation = validateMemberHitRequirements(captureData);

    if (validation.valid) {
      button.classList.remove('btn-icon-disabled');
      button.classList.add('btn-icon-enabled');
      button.title = 'Crear Member y Hit';
      button.removeAttribute('disabled');
    } else {
      button.classList.remove('btn-icon-enabled');
      button.classList.add('btn-icon-disabled');
      button.title = validation.errors.join('\n');
      button.setAttribute('disabled', 'disabled');
    }
  }

  /**
   * Opens the snapshot modal for a given capture
   */
  function openSnapshotModal(captureId) {
    console.log('[MemberHitBtn] Opening snapshot modal for capture', captureId);
    const modal = document.getElementById(`snapshotModal_${captureId}`);
    if (modal) {
      console.log('[MemberHitBtn] ✓ Modal encontrado, abriendo...');
      modal.classList.add('active');
    } else {
      console.error('[MemberHitBtn] ❌ Modal NO encontrado con ID: snapshotModal_' + captureId);
    }
  }

  /**
   * Closes the snapshot modal for a given capture
   */
  function closeSnapshotModal(captureId) {
    console.log('[MemberHitBtn] Closing snapshot modal for capture', captureId);
    const modal = document.getElementById(`snapshotModal_${captureId}`);
    if (modal) {
      modal.classList.remove('active');
    }
  }

  /**
   * Main initialization on DOM ready
   */
  document.addEventListener('DOMContentLoaded', function() {
    console.log('[MemberHitBtn] DOMContentLoaded - Inicializando botones member-hit');

    // Initialize all member-hit-btn buttons
    const buttons = document.querySelectorAll('.member-hit-btn');
    console.log('[MemberHitBtn] Encontrados', buttons.length, 'botones member-hit-btn');

    buttons.forEach(function(button) {
      const captureId = button.getAttribute('data-id');
      if (captureId) {
        initializeButton(button, captureId);
      }
    });
  });

  /**
   * Click handler for member-hit-btn
   */
  document.addEventListener('click', function(e) {
    const button = e.target.closest('.member-hit-btn');
    if (!button) return;

    e.preventDefault();
    e.stopPropagation();

    const captureId = button.getAttribute('data-id');
    console.log('[MemberHitBtn] Click detectado en botón member-hit-btn, captureId:', captureId);

    // Check if button is disabled
    if (button.hasAttribute('disabled')) {
      console.warn('[MemberHitBtn] ⚠️ Botón está deshabilitado, ignorando click');
      return;
    }

    console.log('[MemberHitBtn] ✓ Botón habilitado, procediendo...');

    // Validate requirements again before opening modal
    const row = button.closest('tr');
    if (!row) {
      console.error('[MemberHitBtn] ❌ Fila <tr> no encontrada');
      return;
    }

    const captureData = getCaptureDataFromRow(row, captureId);
    const validation = validateMemberHitRequirements(captureData);

    if (!validation.valid) {
      console.error('[MemberHitBtn] ❌ Validación falló:', validation.errors);
      return;
    }

    console.log('[MemberHitBtn] ✓ Validación exitosa, abriendo modal snapshot');
    openSnapshotModal(captureId);
  });

  /**
   * Transitions modal from Phase 1 (Hit creation) to Phase 2 (Member creation)
   */
  function transitionToPhase2(captureId, hitData) {
    console.log('[MemberHitBtn] Transicionando a Fase 2 para capture', captureId, 'con data:', hitData);

    // Get modal elements
    const modal = document.getElementById(`snapshotModal_${captureId}`);
    const header = modal.querySelector('.snapshot-modal-header h3');
    const body = modal.querySelector('.snapshot-modal-body');
    const footer = modal.querySelector('.snapshot-modal-footer');

    // Store hit data in modal for later use
    modal.dataset.hitId = hitData.hit_id;
    modal.dataset.legacyId = hitData.legacy_id;

    // Update header
    header.textContent = 'Crear Member - Fase 2: Información del Detenido';

    // Get capture data from row
    const row = document.querySelector(`tr[data-capture-id="${captureId}"]`);
    const nombre = row.getAttribute('data-nombre');
    const apellido_paterno = row.getAttribute('data-apellido-paterno');
    const apellido_materno = row.getAttribute('data-apellido-materno');
    const genero = row.getAttribute('data-genero');
    const organizacion = row.getAttribute('data-organizacion');
    const organization_id = row.getAttribute('data-organization-id');
    const rol = row.getAttribute('data-rol');
    const alias = row.getAttribute('data-alias');

    console.log('[MemberHitBtn] Datos precargados: rol=' + rol + ', alias=' + alias);

    // Build Phase 2 form
    const phase2Form = `
      <div class="snapshot-form-group" style="display: none;">
        <label>Legacy ID del Hit</label>
        <input type="text" readonly value="${hitData.legacy_id}" style="background-color: #f5f5f5; cursor: not-allowed;">
      </div>

      <div class="snapshot-form-group">
        <label>Nombre</label>
        <input type="text" id="memberFirstname_${captureId}" value="${nombre}" readonly style="background-color: #f5f5f5; cursor: not-allowed;">
      </div>

      <div class="snapshot-form-group">
        <label>Apellido Paterno</label>
        <input type="text" id="memberLastname1_${captureId}" value="${apellido_paterno}" readonly style="background-color: #f5f5f5; cursor: not-allowed;">
      </div>

      <div class="snapshot-form-group">
        <label>Apellido Materno</label>
        <input type="text" id="memberLastname2_${captureId}" value="${apellido_materno}" readonly style="background-color: #f5f5f5; cursor: not-allowed;">
      </div>

      <div class="snapshot-form-group">
        <label>Género (se estimará si no se selecciona)</label>
        <select id="memberGender_${captureId}" style="width: 100%; padding: 8px; border: 1px solid #ccc; border-radius: 4px;">
          <option value="">-- Auto-estimar --</option>
          <option value="MASCULINO">Masculino</option>
          <option value="FEMENINO">Femenino</option>
        </select>
      </div>

      <div class="snapshot-form-group">
        <label>Organización</label>
        <input type="text" id="memberOrganization_${captureId}" value="${organizacion}" readonly style="background-color: #f5f5f5; cursor: not-allowed;">
        <input type="hidden" id="memberOrganizationId_${captureId}" value="${organization_id}">
      </div>

      <div class="snapshot-form-group">
        <label>Rol del Member</label>
        <input type="text" id="memberRole_${captureId}" value="${rol || '(No asignado)'}" readonly style="background-color: #f5f5f5; cursor: not-allowed;">
        <input type="hidden" id="memberRoleId_${captureId}" value="${rol}">
      </div>

      <div class="snapshot-form-group">
        <label>Alias (Opcional - separados por ;)</label>
        <input type="text" id="memberAlias_${captureId}" value="${alias || ''}" placeholder="Ej: alias1; alias2; alias3">
      </div>
    `;

    // Replace body content
    body.innerHTML = phase2Form;

    // Update footer buttons
    footer.innerHTML = `
      <button class="snapshot-cancel-btn" data-capture-id="${captureId}">Cancelar</button>
      <button class="snapshot-create-member-btn" data-capture-id="${captureId}">Crear Member</button>
    `;

    console.log('[MemberHitBtn] ✓ Fase 2 lista para capture', captureId);
  }

  /**
   * Handler for Create Hit button
   */
  document.addEventListener('click', function(e) {
    if (!e.target.classList.contains('snapshot-create-hit-btn')) return;

    e.preventDefault();
    const captureId = e.target.getAttribute('data-capture-id');
    console.log('[MemberHitBtn] Click en Crear Hit para capture', captureId);

    const formData = new FormData();
    formData.append('authenticity_token', document.querySelector('meta[name="csrf-token"]').content);

    // Agregar archivo si existe
    const fileInput = document.querySelector(`#snapshotFile_${captureId}`);
    if (fileInput && fileInput.files.length > 0) {
      formData.append('hit[pdf]', fileInput.files[0]);
      console.log('[MemberHitBtn] Archivo PDF agregado:', fileInput.files[0].name, '(' + fileInput.files[0].size + ' bytes)');
    } else {
      console.log('[MemberHitBtn] No hay archivo PDF seleccionado');
    }

    // Agregar notas si existen
    const notesInput = document.querySelector(`#snapshotNotes_${captureId}`);
    if (notesInput && notesInput.value.trim()) {
      formData.append('hit[notes]', notesInput.value);
      console.log('[MemberHitBtn] Notas agregadas:', notesInput.value.substring(0, 50) + '...');
    }

    console.log('[MemberHitBtn] Enviando POST a /agent/detention_captures/' + captureId + '/create_hit');

    fetch(`/agent/detention_captures/${captureId}/create_hit`, {
      method: 'POST',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Accept': 'application/json'
      }
    })
    .then(r => {
      console.log('[MemberHitBtn] Response status:', r.status);
      return r.json();
    })
    .then(data => {
      console.log('[MemberHitBtn] Response data:', data);

      if (data.success) {
        console.log('[MemberHitBtn] ✓ Hit creado/reutilizado: ID=' + data.hit_id + ', legacy_id=' + data.legacy_id);
        const reusedMsg = data.hit_reused ? ' (reutilizado)' : '';
        console.log('[MemberHitBtn] Transicionando a Fase 2...');

        // Transition to Phase 2 dynamically (no reload)
        transitionToPhase2(captureId, {
          hit_id: data.hit_id,
          legacy_id: data.legacy_id
        });
      } else {
        console.error('[MemberHitBtn] ❌ Error:', data.errors);
        alert('❌ Error al crear Hit:\n' + (data.errors ? data.errors.join('\n') : 'Error desconocido'));
      }
    })
    .catch(err => {
      console.error('[MemberHitBtn] ❌ Fetch error:', err);
      alert('❌ Error al enviar la solicitud: ' + err.message);
    });
  });

  /**
   * Handler for Create Member button (Phase 2)
   */
  document.addEventListener('click', function(e) {
    if (!e.target.classList.contains('snapshot-create-member-btn')) return;

    e.preventDefault();
    const captureId = e.target.getAttribute('data-capture-id');
    console.log('[MemberHitBtn] Click en Crear Member para capture', captureId);

    const modal = document.getElementById(`snapshotModal_${captureId}`);
    const hitId = modal.dataset.hitId;
    const legacyId = modal.dataset.legacyId;
    const roleName = document.getElementById(`memberRoleId_${captureId}`).value;
    const alias = document.getElementById(`memberAlias_${captureId}`)?.value || '';
    const organizationId = document.getElementById(`memberOrganizationId_${captureId}`).value;
    const gender = document.getElementById(`memberGender_${captureId}`)?.value || '';

    if (!roleName || roleName.trim() === '') {
      alert('❌ El rol no está asignado en esta detención');
      return;
    }

    console.log('[MemberHitBtn] Datos del Member:', {
      hit_id: hitId,
      legacy_id: legacyId,
      role_name: roleName,
      alias: alias,
      organization_id: organizationId,
      gender: gender
    });

    const payload = {
      authenticity_token: document.querySelector('meta[name="csrf-token"]').content,
      hit_id: hitId,
      role_name: roleName,
      alias_raw: alias,
      organization_id: organizationId,
      gender: gender
    };

    console.log('[MemberHitBtn] Enviando POST a /agent/detention_captures/' + captureId + '/create_member');

    fetch(`/agent/detention_captures/${captureId}/create_member`, {
      method: 'POST',
      body: JSON.stringify(payload),
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    })
    .then(r => {
      console.log('[MemberHitBtn] Response status:', r.status);
      return r.json();
    })
    .then(data => {
      console.log('[MemberHitBtn] Response data:', data);

      if (data.success) {
        console.log('[MemberHitBtn] ✓ Member creado/actualizado: ID=' + data.member_id);
        alert('✓ Member ' + (data.member_existed ? 'actualizado' : 'creado') + ' exitosamente');
        closeSnapshotModal(captureId);
        // Note: no reload - user can continue with other captures
      } else {
        console.error('[MemberHitBtn] ❌ Error:', data.errors || data.message);
        alert('❌ Error al crear Member:\n' + (data.errors ? (Array.isArray(data.errors) ? data.errors.join('\n') : data.errors) : data.message || 'Error desconocido'));
      }
    })
    .catch(err => {
      console.error('[MemberHitBtn] ❌ Fetch error:', err);
      alert('❌ Error al enviar la solicitud: ' + err.message);
    });
  });

  /**
   * Close modal handlers
   */
  document.addEventListener('click', function(e) {
    // Close button
    if (e.target.classList.contains('snapshot-modal-close')) {
      e.preventDefault();
      const modal = e.target.closest('.snapshot-modal-overlay');
      if (modal) {
        const captureId = modal.id.replace('snapshotModal_', '');
        console.log('[MemberHitBtn] Cerrando modal (botón close) para capture', captureId);
        closeSnapshotModal(captureId);
      }
    }

    // Cancel button
    if (e.target.classList.contains('snapshot-cancel-btn')) {
      e.preventDefault();
      const modal = e.target.closest('.snapshot-modal-overlay');
      if (modal) {
        const captureId = modal.id.replace('snapshotModal_', '');
        console.log('[MemberHitBtn] Cerrando modal (botón cancel) para capture', captureId);
        closeSnapshotModal(captureId);
      }
    }
  });

  /**
   * Close modal when clicking on overlay background
   */
  document.addEventListener('click', function(e) {
    if (e.target.classList.contains('snapshot-modal-overlay') && e.target.classList.contains('active')) {
      const captureId = e.target.id.replace('snapshotModal_', '');
      console.log('[MemberHitBtn] Cerrando modal (click overlay) para capture', captureId);
      closeSnapshotModal(captureId);
    }
  });

  // Expose functions to global scope if needed
  window.MemberHitCreation = {
    validateMemberHitRequirements: validateMemberHitRequirements,
    getCaptureDataFromRow: getCaptureDataFromRow,
    initializeButton: initializeButton,
    openSnapshotModal: openSnapshotModal,
    closeSnapshotModal: closeSnapshotModal
  };
})();
