$(document).ready(function() {
  console.log('monthly_captures.js loaded');
  console.log('Found link buttons:', $('.link-btn').length);
  console.log('Found edit buttons:', $('.edit-btn').length);
  console.log('Found delete buttons:', $('.delete-btn').length);

  // Initialize Materialize modals
  $('.modal').modal();

  // Link button handler
  $(document).on('click', '.link-btn', function() {
    console.log('Link button clicked');
    const url = $(this).data('url');
    console.log('URL:', url);
    if (url) {
      window.open(url, '_blank');
    }
  });

  // Load form data (states, organizations)
  function loadFormData() {
    $.ajax({
      url: '/agent/get_states',
      type: 'GET',
      success: function(data) {
        const stateSelect = $('#estado');
        stateSelect.find('option:not(:first)').remove();
        data.states.forEach(state => {
          stateSelect.append(`<option value="${state}">${state}</option>`);
        });
      }
    });

    $.ajax({
      url: '/agent/get_organizations',
      type: 'GET',
      success: function(data) {
        const orgSelect = $('#organizacion');
        orgSelect.find('option:not(:first)').remove();
        data.organizations.forEach(org => {
          orgSelect.append(`<option value="${org}">${org}</option>`);
        });
      }
    });
  }

  // Update municipalities when state changes
  $(document).on('change', '#estado', function() {
    const state = $(this).val();
    const municipioSelect = $('#municipio');
    municipioSelect.find('option:not(:first)').remove();

    if (state) {
      $.ajax({
        url: '/agent/get_counties',
        type: 'GET',
        data: { state: state },
        success: function(data) {
          data.counties.forEach(county => {
            municipioSelect.append(`<option value="${county}">${county}</option>`);
          });
        }
      });
    }
  });

  // Edit button handler
  $(document).on('click', '.edit-btn', function() {
    console.log('Edit button clicked');
    const captureId = $(this).data('id');
    console.log('Capture ID:', captureId);
    const row = $(`tr[data-capture-id="${captureId}"]`);

    // Populate form with row data
    const cells = row.find('td');
    $('#captureId').val(captureId);
    $('#incident_date').val(cells.eq(1).text().split('/').reverse().join('-'));
    $('#detenidos').val(cells.eq(5).text());
    $('#nombre').val(cells.eq(6).text());

    // Helper to check if institution checkbox is marked (checks for fa-check-circle icon)
    const isInstitutionChecked = (cellIndex) => {
      return cells.eq(cellIndex).find('.fa-check-circle').length > 0;
    };

    // Set institution checkboxes based on icons in table (cells 7-16)
    document.getElementById('sedena').checked = isInstitutionChecked(7);
    document.getElementById('semar').checked = isInstitutionChecked(8);
    document.getElementById('gn').checked = isInstitutionChecked(9);
    document.getElementById('sscp').checked = isInstitutionChecked(10);
    document.getElementById('fgr').checked = isInstitutionChecked(11);
    document.getElementById('ssp_estatal').checked = isInstitutionChecked(12);
    document.getElementById('fge_pgj').checked = isInstitutionChecked(13);
    document.getElementById('policia_municipal').checked = isInstitutionChecked(14);
    document.getElementById('otro').checked = isInstitutionChecked(15);

    // Load form data first
    loadFormData();

    // Set estado and wait for it to populate, then set municipio
    const selectedEstado = cells.eq(2).text();
    const selectedMunicipio = cells.eq(3).text();
    const selectedOrganizacion = cells.eq(4).text();

    // Set estado
    $('#estado').val(selectedEstado);

    // Load municipalities for this state, then set value
    $.ajax({
      url: '/agent/get_counties',
      type: 'GET',
      data: { state: selectedEstado },
      success: function(data) {
        const municipioSelect = $('#municipio');
        municipioSelect.find('option:not(:first)').remove();
        data.counties.forEach(county => {
          municipioSelect.append(`<option value="${county}">${county}</option>`);
        });
        municipioSelect.val(selectedMunicipio);
      }
    });

    // Set organizacion
    $('#organizacion').val(selectedOrganizacion);

    const editModalInstance = M.Modal.getInstance(document.getElementById('editModal'));
    editModalInstance.open();
  });

  // Delete button handler
  $(document).on('click', '.delete-btn', function() {
    console.log('Delete button clicked');
    const captureId = $(this).data('id');
    const row = $(`tr[data-capture-id="${captureId}"]`);
    const cells = row.find('td');

    const deleteInfo = `
      <div class="alert alert-info">
        <strong>Información a eliminar:</strong><br>
        Estado: ${cells.eq(2).text()}<br>
        Municipio: ${cells.eq(3).text()}<br>
        Organización: ${cells.eq(4).text()}<br>
        Nombre: ${cells.eq(6).text()}
      </div>
    `;

    $('#deleteInfo').html(deleteInfo);
    $('#confirmDeleteBtn').data('capture-id', captureId);

    const deleteModalInstance = M.Modal.getInstance(document.getElementById('deleteModal'));
    deleteModalInstance.open();
  });

  // Save changes
  $(document).on('click', '#saveBtn', function() {
    console.log('Save button clicked');
    const captureId = $('#captureId').val();
    const formData = new FormData($('#editForm')[0]);

    $.ajax({
      url: `/agent/detention_captures/${captureId}`,
      type: 'PATCH',
      data: formData,
      processData: false,
      contentType: false,
      success: function(response) {
        if (response.success) {
          const editModalInstance = M.Modal.getInstance(document.getElementById('editModal'));
          editModalInstance.close();
          alert('Captura actualizada exitosamente');
          location.reload();
        } else {
          alert('Error: ' + response.errors.join(', '));
        }
      },
      error: function(xhr) {
        alert('Error al actualizar la captura');
      }
    });
  });

  // Confirm delete
  $(document).on('click', '#confirmDeleteBtn', function() {
    console.log('Confirm delete button clicked');
    const captureId = $(this).data('capture-id');

    $.ajax({
      url: `/agent/detention_captures/${captureId}`,
      type: 'DELETE',
      dataType: 'json',
      success: function(response) {
        if (response.success) {
          const deleteModalInstance = M.Modal.getInstance(document.getElementById('deleteModal'));
          deleteModalInstance.close();
          alert('Captura eliminada exitosamente');
          location.reload();
        } else {
          alert('Error: ' + response.errors.join(', '));
        }
      },
      error: function(xhr) {
        alert('Error al eliminar la captura');
      }
    });
  });

  // Export button
  $(document).on('click', '#confirmExportBtn', function() {
    console.log('Export button clicked');
    alert('Exportación no disponible aún');
  });
});
