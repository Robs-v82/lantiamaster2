// var ready
// ready = function(){

	window.addEventListener( "pageshow", function ( event ) {
	  var historyTraversal = event.persisted || 
	                         ( typeof window.performance != "undefined" && 
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
      				console.log(month)
      				$.post(
      					'/months/header_selector/'+month,
      					$(this).serialize(),
      					function(data) {
      						console.log(data.month);
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

		// PASSWORD ERROR MODAL
		$(document).ready(function(){
			if($('#password-error-modal').length) {
	    		$('#password-error-modal').modal('open')
			}
		})




		// CUSTOM JAVASCRIPT


		$('#show-filter-dashboard').click(function() {
			console.log('working!')
			$('#filter-dashboard').removeClass('hide-on-small-only');
		})

		$('#hide-filter-dashboard').click(function() {
			console.log('working!')
			$('#filter-dashboard').addClass('hide-on-small-only');
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
				console.log(myVal)
				if($(this).hasClass('sort-down-btn')) {
					sortTableDown(myVal);
					$(this).removeClass('sort-down-btn').addClass('sort-up-btn').html('<i class="material-icons small black-text">keyboard_arrow_up</i>');
				} else {
					sortTableUp(myVal);
					$(this).removeClass('sort-up-btn').addClass('sort-down-btn').html('<i class="material-icons small black-text">keyboard_arrow_down</i>');	
				};
				return false;
			})


		// SELECT ALL BUTTONS
		
			$('.select-all').click(function() {
				$(this).parent().siblings().find('input').prop('checked', true)
				$('.send_button').removeClass('disabled').addClass('teal lighten-5 pulse')
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
			}
			$('#state-collapsible-tab input').prop('checked', true);
			$('#city-collapsible-tab input').prop('checked', true);
			$('#county-collapsible-tab input').prop('checked', true);  
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

		// ACTIVATE COUNTIES FILTER
		$('input[name="query[freq_states][]"]').click(function () {
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

		// GET QUARTERS
		$('#operation-quarter-year-selector').change(function() {
			$('#operation-quarter-selector').removeAttr('disabled')
			$('#operation-quarter-selector').html('')
			$.post(
				'/queries/get_quarters',
				$(this).serialize(),
				function(data) {
					var quarterOptions = "<option value='' selected>Todos</option>"
					for (i=0; i<data.quarters.length; i++) {
						quarterOptions += "<option name='query[quarter]' value='"+data.quarters[i]+"'>"+data.quarters[i]+"</option>"
					}
				$('#operation-quarter-selector').append(quarterOptions)
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
					console.log("Hola")
					console.log(data.members[0].name)
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
					console.log("Hola")
					console.log(data.divisions[0].name)
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

		// DEFINE FREQ TABLE TIMEFRAME
		$('#victim_freq_table input').change(function() {
			var mydata = $(this).serialize()
			newArr = mydata.split("=")
			$('.send_button').removeClass('disabled').addClass('teal lighten-5 pulse')
			$('.send_button i').addClass('text-darken-3')
			$('.send-to-bottom').show()
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
// }

// $(document).ready(ready)
// $(document).on('turbolinks:load', ready)


