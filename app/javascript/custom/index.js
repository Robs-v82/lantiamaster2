// var ready
// ready = function(){

	$(document).ready(function(){

		// TEST JQUERY	
		$("#jquery-test").click(function(){
		  $(this).hide();
		})

		// MATERIALIZE

		// ADD AUTOCOMPLETE
		// $(document).ready(function(){
		// 	$('input.autocomplete').autocomplete({
		// 	  data: {
		// 	    "Apple": null,
		// 	    "Microsoft": null,
		// 	    "Google": 'https://placehold.it/250x250'
		// 	  },
		// 	});
		// });

		// ADD COLLAPSIBLE

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

		// BACK BUTTON
		$(document).ready(function(){
			if(performance.navigation.type == 2){
			   location.reload(true);
			}
		})
	    	
		// CUSTOM JAVASCRIPT
		// GET STATE COUNTIES
		$('#operation-state-selector').change(function() {
			$('#operation-county-selector').removeAttr('disabled')
			$('#operation-county-selector').html('')
			$.post(
				'/counties/getCounties',
				$(this).serialize(),
				function(data) {
					console.log("Hola")
					console.log(data.counties[0].name)
					var countyOptions = "<option value='' selected>Todos</option>"
					for(i=0; i<data.counties.length; i++) {
						countyOptions += "<option value='"+data.counties[i].id+"'>"+data.counties[i].name+"</option>"
					}
				$('#operation-county-selector').append(countyOptions)				
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
					console.log(data.towns[0].name)
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
					console.log("Hola")
					console.log(data.months[0])
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
					console.log("Hola")
					console.log(data.months[0])
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
					console.log("Hola")
					console.log(data.quarters[0])
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
	    	console.log(newArr);

			$('#operation-member1-selector').removeAttr('disabled')
			$('#operation-member1-selector').html('')
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
				$('#operation-member1-selector').append(memberOptions)				
				}
			)
			return false
		})

	// GET ORGANIZATION2 MEMBERS
		$('#operation-organization2-selector').change(function() {

			var mydata = $("#operation-organization2-selector").serialize();
	    	newArr = mydata.split("=")
	    	console.log(newArr);

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


