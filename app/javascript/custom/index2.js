		$(document).ready(function() {
			
			$("#freq-map-trigger").click(function() {
				$(".freq-entry-display").hide();
				$("#freq-entry-map").show();
				return false
		 	})

			$("#freq-list-trigger").click(function() {
				return false
		 	})

			if ($(window).height() < 600) {
				var mapHeight = 300
	        } else {
	        	var mapHeight = $(window).height()/2
	        }; 

				var data = [
					<% @placeArr.each do |place| %>
						{
							<% if @checkedStates.length != 1 %>
								code:'<%= place[:code] %>',
							<% else %>
								full_code:'<%= place[:full_code] %>',
							<% end %>
							value:<%= place[:coalition] %>, rackets:'<% place[:rackets][0..@racketLimit].each do |racket|%><span style="color:<%= racket[:color]%>; font-size:12px">- <%= racket[:name][0..32] %><% if racket[:name].length > 33 %>...<% end %><span><br><br><% end %><% if place[:rackets].length > @racketLimit %><span style="font-size:12px">...</span><% end %>',
							freq:<%= place[:freq]%>, 
							<% if place[:freq] == 1 %>
								string:'organización'
							<% else %>
								string:'organizaciones'
							<% end %>
						},
					<% end %>
				];

				Highcharts.getJSON(
					<% if @checkedStates.length != 1 %>
						'/maps/national_map.json'
					<% else %>
						'/maps/<%= State.find(@checkedStates.last).code %>.geojson'
					<% end %>
					, function (geojson) {
				    Highcharts.mapChart('org-entry-map', {
				        chart: {
				            map: geojson,
				            <% if @checkedStates.length != 1 %>
				            	height: mapHeight,
				            <% else %>	
				            	<% if @shortMap.include? @checkedStates.last %>
				            		height: mapHeight - 12,
				            	<% else %>
				            		height: mapHeight + 28,
				            	<% end %>
				            <% end %>
					        style: {
					            fontFamily: 'Montserrat'
					        },
				        },
				        legend: false,
				        title: false, 
				        credits: false,
				        mapNavigation: {
				            enabled: false,
				        },
				        <% unless session[:admin] %>
						exporting: {
							enabled: false
						},
						<% end %>
			            colorAxis: {
			            	dataClasses: [{
				                to: 0.9,
				                color: "#FF7575"
				            },{
				            	from: 0.9,
				            	to: 1.9,
				            	color: '#80cbc4'
				            },{
				            	from: 1.9,
				            	to: 2.9,
				            	color: '#ffcc80'			            	
				            },{
				            	from: 2.9,
				            	color: '#454157'	
				            }]
				        },
				        <% if @checkedStates.length != 1 %>
					        plotOptions: {
					        	series: {
					        		className: "preloader-trigger",
					        		point: {
					        			events: {
					        				<% if session[:membership] > 3 %>
						        				click: function() {
						        					$('#preloader').removeClass('preloader-disappear')
						        					var urlString = 'organizations_query/'+this.code;
						        					window.location = urlString;
						        				}
					        				<% end %>
					        			}
					        		}
					        	}
					        },
					    <% end %>
				        series: [{
				            data: data,
				            <% if @checkedStates.length != 1 %>
				            	joinBy: 'code',
				            <% else %>
				            	joinBy: 'full_code',
				            <% end %>
			            	name: 'Organizaciones',
				            borderColor: 'white',
				            borderWidth: 1,
				            nullColor: '#e0e0e0',
				            states: {
				                hover: {
				                    color: '#ffffff',
					                borderColor: '#424242'
				                }
				            },
				            <% if @checkedStates.length != 1 && session[:membership] > 3 %>
				            	cursor: 'pointer',
				            <% end %>
				            tooltip: {
				            	borderWidth: 0,
				            	headerFormat: '<span style="font-size:14px; color:#A09EAB">{point.key}</span><br>',
				            	pointFormat: '<div style="padding-bottom:14px"><span style="color:#A09EAB; font-size:14px">{point.freq} {point.string}:</span></div><br><div>{point.rackets}</div>',
				            	style: {
				            		pointerEvents: 'auto'
				            	},
							    useHTML: true, // HTML for overflow
				            }
				        }],
				    },
				);
			});	
		})
