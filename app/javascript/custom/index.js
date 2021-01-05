


window.addEventListener( "pageshow", function ( event ) {
	var historyTraversal = event.persisted || 
	     (typeof window.performance != "undefined" && 
	          window.performance.navigation.type === 2 );
	if ( historyTraversal ) {
	// Handle page restore.
	window.location.reload();
	}
});

// BACK BUTTON

$(document).ready(function(){
	if(performance.navigation.type == 2){
	   location.reload(true);
	}
})


$(document).ready(function(){

	// AUTOCOMPLETE
	function myFunction() {
		var myString = $('#autocomplete-input').val();
		if (myString) {
			myString = myString;
		} else {
			myString = 'Xp987jy';
		};
		$.ajax({
			type: 'GET',
			dataType: 'json',
			url: '/organizations/get_cartels/'+myString,
			data: $(this).serialize(),
			success: function(response) {
				if (response !== undefined) {
					$('#org-entry-list').hide();
					var startHTML = '<div id="org-entry-list" class="org-entry-display"><table id="org-table" class="highlight"><tbody>';
					var myRows = '';
					for (i = 0; i < response.length; i++) {
						myRows += '<tr><td><a href="/organizations/show/'+response[i].id+'">'+response[i].name+'</a></td><tr>'
					}
					var endHTML = '</tbody></table></div>';
					var newHTML = startHTML + myRows + endHTML;
					$('#new-entry-list').html(newHTML);
				} else {
					$('#new-entry-list').html('');
					$('#org-entry-list').show();
				}
			}
		});
	}	

	// TEST JQUERY	
	$("#jquery-test").click(function(){
	  $(this).hide();
	})

	// MATERIALIZE

	$(document).ready(function(){
		$('.collapsible').collapsible();
	});

	// ADD SIDENAV
	  $(document).ready(function(){
	    $('.sidenav').sidenav();
	});

	// ADD TOOLTIPS
	  $(document).ready(function(){
	    $('.tooltipped').tooltip();
	  })

	 $('.tooltipped').tooltip({enterDelay: 200});

	// ADD DISCOVERYFEATURE
	$(document).ready(function(){
	    $('.tap-target').tapTarget();
	  });

	// ADD DATEPICKER
	$(document).ready(function(){
		$('.datepicker').datepicker();
	});

	// ADD TIMEPICKER
	  $(document).ready(function(){
	    $('.timepicker').timepicker();
	  });

	// ADD DROPDOWN
	$(document).ready(function(){
		$('.dropdown-trigger').dropdown();
	});

	// TABS
	$(document).ready(function(){
		$('.tabs').tabs();
	});

	// MODAL
	$(document).ready(function(){
	    $('.modal').modal();
	  })

	// CAROUSEL
	$(document).ready(function(){
		$('#violence-report-carousel').carousel({
			noWrap: true,
			indicators: true,
			onCycleTo: function(ele) {
  				var month = $(ele).index();
  				$.post(
  					'/months/header_selector/'+month,
  					$(this).serialize(),
  					function(data) {
  						$('#report-carousel-header').html('');
  						var new_header = data.month;
  						$('#report-carousel-header').append(new_header);
  					}
  				)
  				return false
				}
		});
	});

	// EMAIL MODAL
	$(document).ready(function(){
		if($('#email-modal').length) {
    		$('#email-modal').modal('open')
		}
	})

	// LOAD MODAL
	$(document).ready(function(){
		if($('#load-modal').length) {
    		$('#load-modal').modal('open')
		}
	})

	// EMPTY QUERY MODAL
	$(document).ready(function(){
		if($('#empty-query-modal').length) {
    		$('#empty-query-modal').modal('open')
		}
	})

	// PASSWORD ERROR MODAL
	$(document).ready(function(){
		if($('#password-error-modal').length) {
    		$('#password-error-modal').modal('open')
		}
	})

	// CUSTOM JAVASCRIPT

	// MAP HOVER
	$('path').hover(function() {
	})

	// INDEX SWITCH
	$('#index_switch').change(function() {
		if ($('#index_switch input').is(':checked')){
			$(location).attr('href','/counties/high_risk')
		} else {
			$(location).attr('href','/states/irco')
		}
	})
	

	// CLICKABLE ROW
    $(".clickable-row").click(function() {
        window.location = $(this).data("href");
    });	

    $('.clickable-row, .pseudo-clickable-row').hover(
		function () {
    		if ($(this).find("th").length > 0) return;
    		$(this).addClass("gridRowHover");
		},
		function () {
			$(this).removeClass("gridRowHover");
		}
	);


	$('#index-order-selector').change(function() {
		if($('#low_risk_query_box').is(':checked')){
			$(location).attr('href','/counties/low_risk')
		} else if ($('#high_risk_query_box').is(':checked')){
			$(location).attr('href','/counties/high_risk')
		} else {
			$(location).attr('href','/counties/destinations')
		}
	})
	
	function tabInit() {
	    $('ul.tabs').tabs();
	}

	$('#show-filter-dashboard').click(function() {
		$('#filter-dashboard').removeClass('hide-on-med-and-down hide-on-small-only');
		$("html, body").animate({ scrollTop: 0 }, "slow");
		tabInit();
	})

	$('#hide-filter-dashboard').click(function() {
		$('#filter-dashboard').addClass('hide-on-small-only');
	})

	// MAPS NAVIGATION
	$('#back-to-general-map').click(function() {
		$('.geo-distribution-display').hide();
		$('#general-map').show();
		return false
	})

	$('.go-to-state-map').click(function() {
		var myId = $(this).attr('id'); 
		var myState = myId.substr(myId.length - 2);
		$('.geo-distribution-display').hide();
		$('#'+myState+'-org-map').show();
		return false
	})

	// STATE CHARTS TOGGLE
	$('.close-state').click(function() {
		$('.detention-toggle-charts').hide();
		$('#00-detention-charts').show();
		$('.victim-toggle-charts').hide();
		$('#00-victim-charts, #00-incident-charts').show();
		$('#00000-victim-charts').show();
		$('#00000-incident-charts').show();
		$('.collection-item').show();
		$("html, body").animate({ scrollTop: 0 }, "slow");
	});

	$('.close-index-card').click(function() {
		$('.index-display').hide();
		$('#icon-table-display').show();
		$("html, body").animate({ scrollTop: 0 }, "slow");
		tabInit()
	});

	// ORGANIZATION AUTOCOMPLETE
	$('#autocomplete-input').keyup(function() {
		myFunction();
	})

	// PAGES
	var movePage = function(data) {
		var nextPage = Number(data[0])+1
		var previousPage = data[0]-1
		$('.clickable-row').hide();
		$('.org-row-'+data[0]).show();
		$('.page-number-button').hide();
		$('#page-'+nextPage+'-marker').show();
		$('#page-'+data[0]+'-marker').show();
		$('#page-'+previousPage+'-marker').show();
		$('.page-number-button').removeClass('active-page paletton-red white-text');
		$('.page-number-button').addClass('white paletton-grey-text');
		$('#page-'+data[0]+'-marker').removeClass('white paletton-grey-text').addClass('active-page paletton-red');
		if (Number(data[0]) > 2) {
			$('#back-two-pages').show();
		} else {
			$('#back-two-pages').hide();
		};
		if (Number(data[0]) > (data[1] - 2)) {
			$('#forward-two-pages').hide();
		} else {
			$('#forward-two-pages').show();
		};
	}

	$('.page-number-button').click(function() {
		var page = $(this).attr('data');
		var numberOfPages = $(this).attr('dataPlus')
		movePage([page, numberOfPages]);
	})


	$('#back-two-pages').click(function() {
		var page = $('#org-paginator').find('.active-page').attr('data');
		var target = Number(page)-2;
		var numberOfPages = $('#org-paginator').find('.active-page').attr('dataPlus');
		movePage([target, numberOfPages]);
	})

	$('#forward-two-pages').click(function() {
		var page = $('#org-paginator').find('.active-page').attr('data');
		var target = Number(page)+2;
		var numberOfPages = $('#org-paginator').find('.active-page').attr('dataPlus');
		movePage([target, numberOfPages]);
	})



	// SORT BUTTONS
		$('.sort-btn').click(function() {
			function sortTableDown(myCell) {
				var table, rows, switching, i, x, y, shouldSwitch;
				table = document.getElementById("sort-table");
				switching = true;
				/*Make a loop that will continue until
				no switching has been done:*/
				while (switching) {
						//start by saying: no switching is done:
						switching = false;
						rows = table.rows;
						/*Loop through all table rows (except the
						first, which contains table headers):*/
						for (i = 0; i < (rows.length - 1); i++) {
							//start by saying there should be no switching:
							shouldSwitch = false;
							/*Get the two elements you want to compare,
							one from current row and one from the next:*/
							x = rows[i].getElementsByTagName("TD")[myCell];
							y = rows[i + 1].getElementsByTagName("TD")[myCell];
							//check if the two rows should switch place:
							if (x.innerHTML.match(/^\d/)) {
								m = parseFloat(x.innerHTML.replace(/,/g, ''))
								n = parseFloat(y.innerHTML.replace(/,/g, ''))
								if (m < n) {
									//if so, mark as a switch and break the loop:
									shouldSwitch = true;
									break;
								}
							} else {
								if (x.innerHTML.toLowerCase() < y.innerHTML.toLowerCase()) {
									//if so, mark as a switch and break the loop:
									shouldSwitch = true;
									break;
								}
							}
					}
					if (shouldSwitch) {
						/*If a switch has been marked, make the switch
						and mark that a switch has been done:*/
						rows[i].parentNode.insertBefore(rows[i + 1], rows[i]);
						switching = true;
					}
				}
			}

			function sortTableUp(myCell) {
				var table, rows, switching, i, x, y, shouldSwitch;
				table = document.getElementById("sort-table");
				switching = true;
				/*Make a loop that will continue until
				no switching has been done:*/
				while (switching) {
						//start by saying: no switching is done:
						switching = false;
						rows = table.rows;
						/*Loop through all table rows (except the
						first, which contains table headers):*/
						for (i = 0; i < (rows.length - 1); i++) {
							//start by saying there should be no switching:
							shouldSwitch = false;
							/*Get the two elements you want to compare,
							one from current row and one from the next:*/
							x = rows[i].getElementsByTagName("TD")[myCell];
							y = rows[i + 1].getElementsByTagName("TD")[myCell];
							//check if the two rows should switch place:
							if (x.innerHTML.match(/^\d/)) {
								m = parseFloat(x.innerHTML.replace(/,/g, ''))
								n = parseFloat(y.innerHTML.replace(/,/g, ''))
								if (m > n) {
									//if so, mark as a switch and break the loop:
									shouldSwitch = true;
									break;
								}
							} else {
								if (x.innerHTML.toLowerCase() > y.innerHTML.toLowerCase()) {
									//if so, mark as a switch and break the loop:
									shouldSwitch = true;
									break;
								}
							}
						}
						if (shouldSwitch) {
							/*If a switch has been marked, make the switch
							and mark that a switch has been done:*/
							rows[i].parentNode.insertBefore(rows[i + 1], rows[i]);
							switching = true;
						}
					}
				}

			var myVal = $(this).attr('value') -1;
			if($(this).hasClass('sort-down-btn')) {
				sortTableDown(myVal);
				$(this).removeClass('sort-down-btn').addClass('sort-up-btn').html('<i class="material-icons small black-text">keyboard_arrow_up</i>');
			} else {
				sortTableUp(myVal);
				$(this).removeClass('sort-up-btn').addClass('sort-down-btn').html('<i class="material-icons small black-text">keyboard_arrow_down</i>');	
			};
			return false;
		})

	// HELP MODALS
	$(document).one('mousemove', function() {
		$('#freq-help-modal').modal('open');
	})


	// SELECT ALL BUTTONS	
		$('.select-all').click(function() {
			$(this).parent().siblings().find('input').prop('checked', true)
			$('.send_button').removeClass('disabled').addClass('white pulse')
			$('.send_button i').addClass('text-darken-3')
			$('.send-to-bottom').show();
		})

	// CLEAR ALL BUTTONS
		$('.clear-all').click(function() {
			$(this).parent().siblings().find('input').prop('checked', false)
			$('.send-to-bottom').hide();
		})


	// SWITCH FROM STATE TO CITY IN VICTM FREQUENCY TABLE	
	$("#geo_query_box input").click(function() {  
		$('#state-collapsible-tab input').prop('checked', true);
		$('#city-collapsible-tab input').prop('checked', true);
		$('#county-collapsible-tab input').prop('checked', true);
		$('#state_filter_box .select-all, #state_filter_box .clear-all').removeClass('disabled');  
		if  ($("#nation_query_box").is(':checked')){
			$('#state-collapsible-tab').addClass('collapsible-disabled');
			$('#city-collapsible-tab').addClass('collapsible-disabled');
			$('#county-collapsible-tab').addClass('collapsible-disabled');
		} else if ($("#state_query_box").is(':checked')) {
			$('#state-collapsible-tab').removeClass('collapsible-disabled');
			$('#city-collapsible-tab').addClass('collapsible-disabled');
			$('#county-collapsible-tab').addClass('collapsible-disabled');
		} else if ($("#city_query_box").is(':checked')) {  
			$('#city-collapsible-tab').removeClass('collapsible-disabled');  
			$('#state-collapsible-tab').addClass('collapsible-disabled');
			$('#county-collapsible-tab').addClass('collapsible-disabled');
		} else {  
			$('#city-collapsible-tab').addClass('collapsible-disabled');  
			$('#state-collapsible-tab').removeClass('collapsible-disabled');
			$('#state-collapsible-tab input').prop('checked', false);
			$('#state_filter_box .select-all, #state_filter_box .clear-all').addClass('disabled');
		};
	});

	// ACTIVATE GENDER IN FREQUENCY TABLE
	$('#gender_query_box').click(function() {
		if ($("#gender_split_query_box").is(':checked')) {
			$("#gender-collapsible-tab").removeClass('collapsible-disabled');
		} else {
			$("#gender-collapsible-tab").addClass('collapsible-disabled');
			$("#gender-collapsible-tab input").prop('checked', true)
		}
	})

	// ACTIVATE ORGANIZATION IN FREQUENCY TABLE
	$('#organization_query_box').click(function() {
		if ($("#organization_split_query_box").is(':checked')) {
			$("#organization-collapsible-tab").removeClass('collapsible-disabled');
		} else {
			$("#organization-collapsible-tab").addClass('collapsible-disabled');
			$("#organization-collapsible-tab input").prop('checked', true)
		}
	})

	// ACTIVATE ROLE IN FREQUENCY TABLE
	$('#role_query_box').click(function() {
		if ($("#role_split_query_box").is(':checked')) {
			$("#role-collapsible-tab").removeClass('collapsible-disabled');
		} else {
			$("#role-collapsible-tab").addClass('collapsible-disabled');
			$("#role-collapsible-tab input").prop('checked', true)
		}
	})

	// ACTIVATE COUNTIES FILTER
	$('input[name="query[freq_states][]"]').click(function () {
		if ($('#county_query_box').is(':checked')) {
			$('#state-collapsible-tab input').prop('checked', false);
			$(this).prop('checked', true);
		};
		var states = 0
		$('input[name="query[freq_states][]"]:checked').each(function() {
	    	states = this.value;
		});
		var lenghtOfUnchecked = $(this).parent().parent().parent().parent().find('input:checkbox:not(:checked)').length;
		if (lenghtOfUnchecked == 31) {
			if  ($("#county_query_box").is(':checked')) {
				$('#county-collapsible-tab').removeClass('collapsible-disabled').addClass('county-switcher')
				$('#county_checkboxes_box').html('')
				$.post(
					'/counties/getCheckboxCounties/'+states,
					$(this).serialize(),
					function(data) {
						var countyCheckboxes = ""
						for(i=0; i<data.counties.length; i++) {
							countyCheckboxes += "<div class='col s12'><label><input type='checkbox' name='query[freq_counties][]' value='"+data.counties[i].id+"' checked/><span class='white-text'>"+data.counties[i].name+"</span></label></p></div>"
						}
					$('#county_checkboxes_box').append(countyCheckboxes);
					} 
				)
			}
		} else {
			$('#county-collapsible-tab').addClass('collapsible-disabled');
			$('#county-collapsible-tab').removeClass('county-switcher');
			$('#county_checkboxes_box').html('')
		}
	})

	// SWITCH BETWEEN ROLE AND STATE DESAGGREGATION
	$('#role_split_query_box').click(function() {
		if ($('#state_query_box').is(':checked')) {
			$('#nation_query_box').prop('checked', true)
			$('#state-collapsible-tab').addClass('collapsible-disabled');
			$("#state-collapsible-tab input").prop('checked', true)
			// M.toast({html: 'No es posible desagregar por posición y estado de forma simultánea'})
		}
		if ($('#organization_split_query_box').is(':checked')) {
			$('#no_organization_split_query_box').prop('checked', true)
			$('#organization-collapsible-tab').addClass('collapsible-disabled');
			$("#organization-collapsible-tab input").prop('checked', true)
			// M.toast({html: 'No es posible desagregar por posición y organización de forma simultánea'})
		}				
	})

	$('#state_query_box').click(function() {
		if ($('#role_split_query_box').is(':checked')) {
			$('#no_role_split_query_box').prop('checked', true)
			$('#role-collapsible-tab').addClass('collapsible-disabled');
			$("#role-collapsible-tab input").prop('checked', true)
			// M.toast({html: 'No es posible desagregar por posición y estado de forma simultánea'})
		}
	})

	// SWITCH BETWEEN ORGANIZATION AND STATE DESAGGREGATION
	$('#organization_split_query_box').click(function() {
		if ($('#state_query_box').is(':checked')) {
			$('#nation_query_box').prop('checked', true)
			$('#state-collapsible-tab').addClass('collapsible-disabled');
			$("#state-collapsible-tab input").prop('checked', true)
			// M.toast({html: 'No es posible desagregar por posición y estado de forma simultánea'})
		};
		if ($('#role_split_query_box').is(':checked')) {
			$('#no_role_split_query_box').prop('checked', true)
			$('#role-collapsible-tab').addClass('collapsible-disabled');
			$("#role-collapsible-tab input").prop('checked', true)
			// M.toast({html: 'No es posible desagregar por organización y posición de forma simultánea'})
		};				
	})

	$('#state_query_box').click(function() {
		if ($('#organization_split_query_box').is(':checked')) {
			$('#no_organization_split_query_box').prop('checked', true)
			$('#organization-collapsible-tab').addClass('collapsible-disabled');
			$("#organization-collapsible-tab input").prop('checked', true)
			// M.toast({html: 'No es posible desagregar por organización y estado de forma simultánea'})
		};
	})

	// SWITCH SECTIONS IN FREQ-CARD
	$("#freq-chart-trigger").click(function() {
		$(".freq-entry-display").hide();
		$("#freq-entry-chart").show();
		return false
	})

	$("#freq-list-trigger").click(function() {
		$(".freq-entry-display").hide();
		$("#freq-entry-list").show();
		return false
	})

	// GET INDEX COUNTIES
	$('#index-state-selector').change(function() {
		var mydata = $('#index-state-selector').serialize();
		newArr = mydata.split('=');
		window.location = '/counties/set_index_county/'+newArr[1]
	})

	// GET ORGANIZATIONS
	$('#operation-organization-selector').change(function() {
		var mydata = $("#operation-organization-selector").serialize();
    	newArr = mydata.split("=");
    	window.location = '/organizations/show/'+newArr[1];	
	})

	// GET STATE COUNTIES
	$('#operation-state-selector').change(function() {
		$('#operation-county-selector').removeAttr('disabled')
		$('#operation-county-selector').html('')
		$.post(
			'/counties/getCounties',
			$(this).serialize(),
			function(data) {
				var countyOptions = "<option value='' selected>Todos</option>"
				for(i=0; i<data.counties.length; i++) {
					countyOptions += "<option value='"+data.counties[i].id+"'>"+data.counties[i].name+"</option>"
				}
			$('#operation-county-selector').append(countyOptions);				
			}
		)
		$('#operation-city-selector').html('')
		$.post(
			'/states/getCities',
			$(this).serialize(),
			function(data) {
				var cityOptions = "<option value='' selected>Todas</option>"
				for(i=0; i<data.cities.length; i++) {
					cityOptions += "<option value='"+data.cities[i].id+"'>"+data.cities[i].name+"</option>"
				}
			$('#operation-city-selector').append(cityOptions)
			}
		)
		return false
	})

	// GET COUNTY TOWNS
	$('#operation-county-selector').change(function() {
		$('#operation-town-selector').prop("disabled",false)
		$('#operation-town-selector').html('')
		$.post(
			'/towns/getTowns',
			$(this).serialize(),
			function(data) {
				var townOptions = "<option value='' selected>Todos</option>"
				for(i=0; i<data.towns.length; i++) {
					townOptions += "<option name='<%= @town_focus_model %>[town_id]' value='"+data.towns[i].id+"'>"+data.towns[i].zip_code+" "+"-"+" "+data.towns[i].name+"</option>"
				}
			$('#operation-town-selector').append(townOptions)
			}
		)
		return false
	})

	//RESET STATES AND COUNTIES WHEN SELECTING CITY
	$('#operation-city-selector').change(function() {
		$('#operation-county-shell').html('<select id="operation-county-selector" disabled class="admins-select browser-default" name="<%= @county_search_input %>"></select>')
		$('#operation-state-selector').html('')
		$.post(
			'/states/getStates',
			$(this).serialize(),
			function(data) {
				var stateOptions = "<option value='' selected>Todos</option>"
				for(i=0; i<data.states.length; i++) {
					stateOptions += "<option value='"+data.states[i].id+"'>"+data.states[i].name+"</option>"
				}
			$('#operation-state-selector').append(stateOptions)
			}
		)
		return false
	})

	// GET REGULAR MONTHS
	$('.g-operation-year-selector').change(function() {
		$('.g-operation-month-selector').removeAttr('disabled')
		$('.g-operation-month-selector').html('')
		$.post(
			'/queries/get_regular_months',
			$(this).serialize(),
			function(data) {
				var monthOptions = "<option value='' selected>Todos</option>"
				for (i=0; i<data.months.length; i++) {
					monthOptions += "<option name='query[month]' value='"+data.months[i]+"'>"+data.months[i]+"</option>"
				}
			$('.g-operation-month-selector').append(monthOptions)
			}
		)
		return false
	})

	$('.g-operation-quarter-year-selector').change(function(){
		$('.g-operation-quarter-selector').removeAttr('disabled');
		$('.g-operation-quarter-selector').html('');
		$.post(
			'/queries/get_quarters',
			$(this).serialize(),
			function(data) {
				var quarterOptions = "<option value='' selected>Todos</option>"
				for (i=0; i<data.quarters.length; i++) {
					quarterOptions += "<option name='query[quarter]' value='"+data.quarters[i]+"'>"+data.quarters[i]+"</option>"
				}
			$('.g-operation-quarter-selector').append(quarterOptions)
			}
		)
		return false
	})

	// GET MONTHS
	$('#operation-year-selector').change(function() {
		$('#operation-month-selector').removeAttr('disabled')
		$('#operation-month-selector').html('')
		$.post(
			'/queries/get_months',
			$(this).serialize(),
			function(data) {
				var monthOptions = "<option value='' selected>Todos</option>"
				for (i=0; i<data.months.length; i++) {
					monthOptions += "<option name='query[month]' value='"+data.months[i]+"'>"+data.months[i]+"</option>"
				}
			$('#operation-month-selector').append(monthOptions)
			}
		)
		return false
	})

	// GET ORGANIZATION1 MEMBERS
	$('#operation-organization1-selector').change(function() {

		var mydata = $("#operation-organization1-selector").serialize();
    	newArr = mydata.split("=")
		$('#operation-member1-selector').removeAttr('disabled')
		$('#operation-member1-selector').html('')
		$.post(
			'/organizations/getMembers/'+newArr[1],
			$(this).serialize(),
			function(data) {
				var memberOptions = "<option value='' selected></option>"
				for(i=0; i<data.members.length; i++) {
					memberOptions += "<option value='"+data.members[i].id+"'>"+data.members[i].firstname+" "+data.members[i].lastname1+"</option>"
				}
			$('#operation-member1-selector').append(memberOptions)				
			}
		)
		return false
	})

// GET ORGANIZATION2 MEMBERS
	$('#operation-organization2-selector').change(function() {

		var mydata = $("#operation-organization2-selector").serialize();
    	newArr = mydata.split("=")
		$('#operation-member2-selector').removeAttr('disabled')
		$('#operation-member2-selector').html('')
		$.post(
			'/organizations/getMembers/'+newArr[1],
			$(this).serialize(),
			function(data) {
				var memberOptions = "<option value='' selected></option>"
				for(i=0; i<data.members.length; i++) {
					memberOptions += "<option value='"+data.members[i].id+"'>"+data.members[i].firstname+" "+data.members[i].lastname1+"</option>"
				}
			$('#operation-member2-selector').append(memberOptions)				
			}
		)
		return false
	})

	// GET SECTOR DIVISIONS
	$('#operation-sector-selector').change(function() {
		$('#division-checkbox-container').html('')
		$.post(
			'/organizations/getDivisions',
			$(this).serialize(),
			function(data) {
				var divisionOptions = ""
				for(i=0; i<data.divisions.length; i++) {
					divisionOptions += "<div class='col s12 label-row'><label><input class='white' name='organization[division_id]' value='"+data.divisions[i].id+"' type='checkbox'><span class='mini-label white-text'>"+data.divisions[i].name.toUpperCase()+"</span></label></div>"
					}
			$('#division-checkbox-container').append(divisionOptions)				
			}
		)
		return false
	})

	// SWITCH FROM SEVERAL TO SINGLE VICTIM PROFILES
	$('#victim_profile_switch').change(function() {
		$('#multi_victim_profile_container').toggle()
		$('#single_victim_profile_container').toggle()
	})

	$('.tap-target-trigger').mouseenter(function() {
		$('.tap-target').tapTarget('open')
	})

	// ALLOW ONLY ONE OR ALL STATES IN ORGANIZATIONS
	$('#org_state_filter_box input').click(function() {
		console.log("working!!!");
		$('#org_state_filter_box input').prop('checked', false);
		$(this).prop('checked', true);
	})


	// DEFINE FREQ TABLE TIMEFRAME
	$('.freq_filer_form input').change(function() {
		var lenghtOfUnchecked = $('#state_filter_box').find('input:checkbox:not(:checked)').length
		var mydata = $(this).serialize()
		newArr = mydata.split("=")
		$('.send_button').removeClass('disabled').addClass('white pulse')
		$('.send_button i').addClass('text-darken-3')
		if ($("#county_query_box").is(':checked') && lenghtOfUnchecked == 32) {
			$('.send-to-bottom').hide()	
		} else {
			$('.send-to-bottom').show()
		}
	})

	$('#county_checkboxes_box').on('click', 'input', function() {
		$('.send-to-bottom').show()			
	})

	// ENABLE QUERY FIELDS
	$('#general_query_selector input').click(function() {
		$('.all-query-group').prop('disabled', true)
		$('.all-query-label').removeClass('white-text')
		$('.all-query-label').addClass('cyan-text')
	})

	$('#killing_query_box').click(function() {
			$('.border-section').slideUp()
		    $('.killing_query_group').removeAttr('disabled')
		    $('.killing_query_label').toggleClass('cyan-text white-text')
		    $('#state-query-section, #county-query-section, #killing-query-section').slideDown()
	})

	$('#victim_query_box').click(function() {
			$('.border-section').slideUp()
		    $('.victim_query_group').removeAttr('disabled')
		    $('.victim_query_label').toggleClass('cyan-text white-text')
		    $('#state-query-section, #county-query-section, #killing-query-section, #victim-query-section').slideDown()
	})

	$('#source_query_box').click(function() {
			$('.border-section').slideUp()
		    $('.source_query_group').removeAttr('disabled')
		    $('.source_query_label').toggleClass('cyan-text white-text')
		    $('#state-query-section, #county-query-section, #source-query-section').slideDown()
	})
})

// AVOID PAGE TO THE BOTTOM
$(document).on('click', 'input:checkbox', function() {
	$("html, body").animate({ scrollTop: 0 }, "fast");
})
