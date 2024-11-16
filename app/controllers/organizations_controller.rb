class OrganizationsController < ApplicationController
  require 'pp'
  after_action :remove_password_error_message, only: [:password]
  after_action :remove_empty_query_message, only: [:index]
  after_action :remove_empty_request, only: [:query]
  after_action :stop_organization_help, only: [:index]

  skip_before_action :verify_authenticity_token
  before_action :require_pro, only: [:post_query, :get_query]
  before_action :require_premium, only: [:show]
  before_action :require_organization_access, only: [:index, :show]
  # before_action :quick_preload, only: [:query]

  def stop_organization_help
    User.find(session[:user_id]).update(:organization_help=>false)
  end

  def password    
    if params["key"]
      if Key.where(:key=>params["key"]).any?
        target_user = Key.where(:key=>params["key"]).last.user
        session[:user_id] = target_user[:id]
        if target_user.membership_type
          session[:membership] = target_user.membership_type 
        else
          session[:membership] = 0
        end
        helpers.clear_session
        redirect_to '/intro'
      else
       session[:password_error] = true 
      end
    end
    if session[:password_error]
        @password_error = true
    end 
  end

    def query
      if session[:empty_request]
        session[:empty_query] = true
      end
      helpers.clear_session
      cartels = Sector.where(:scian2=>98).last.organizations.uniq
      cartels = cartels.sort_by{|cartel| cartel.name}
      coalitionKeys = helpers.coalitionKeys
      typeKeys = cartels.pluck(:mainleague_id).uniq
      session[:organization_selection] = [typeKeys, coalitionKeys]
      redirect_to '/organizations/index'
    end

    def post_query
      session[:organization_selection][0] = organization_selection_params[:types]

      coalitionKeys = helpers.coalitionKeys
      checkedCoalitions = []

      coalitionKeys.each{|coalition| 
        if organization_selection_params[:coalitions].include? coalition["name"]
          checkedCoalitions.push(coalition)
        end
      }
      session[:organization_selection][1] = checkedCoalitions
      if organization_selection_params[:freq_states]
        myArr = organization_selection_params[:freq_states].map(&:to_i)
        Cookie.create(:data=>myArr)
        session[:checkedStates] = Cookie.last.id
      end
      redirect_to '/organizations/index'
    end

    def get_query
      target = [State.where(:code=>params[:code]).last.id]
      Cookie.create(:data=>target)
      session[:checkedStates] = Cookie.last.id
      redirect_to '/organizations/index'
    end

    def back_query
      if session[:organization_selection]
        redirect_to '/organizations/index'
      else
        redirect_to '/organizations/query'  
      end  
    end

  def index
    @user = User.find(session[:user_id])
    @organizations = true
    @racketLimit = 40
    @quarters = helpers.get_specific_quarters(Year.all, "leads")
    @states = State.all.sort
    @allActivities = Sector.where(:scian2=>"98").last.divisions
    if session[:checkedStates]
      @checkedStates = Cookie.find(session[:checkedStates]).data
    elsif session[:membership] < 2
      @checkedStates = helpers.demo_states.pluck(:id)
    else
      @checkedStates = State.pluck(:id)
    end

    @shortMap = [
      State.where(:code=>"12").last.id,
      State.where(:code=>"16").last.id,
      State.where(:code=>"20").last.id,
      State.where(:code=>"27").last.id,
      State.where(:code=>"29").last.id,
      State.where(:code=>"31").last.id,
    ]
    allCartels = Sector.where(:scian2=>98).last.organizations.uniq

      @checkedTypes = []
      session[:organization_selection][0].each{|key|
        @checkedTypes.push(League.find(key.to_i))
      }

      @type_title = get_type_title(@checkedTypes)

      @typeKeys = allCartels.pluck(:mainleague_id).uniq
      @allTypes = []
      @typeKeys.each{|key|
        @allTypes.push(League.find(key.to_i))
      }

      @allCoalitions = helpers.coalitionKeys

      @checkedCoalitions = session[:organization_selection][1]

      @myActivities = []
      activityArr = [
        "Narcotráfico",
        "Narcomenudeo",
        "Extorsión",
        "Lavado de dinero",
        "Mercado Ilícito de Hidrocarburos",
        "Trata y tráfico de personas"
      ]

      @allActivities = Sector.where(:scian2=>"98").last.divisions
      @allActivities.each{|activity|
        if activityArr.include? activity.name
          @myActivities.push(activity)
        end
      }

      @cartels = []
      myStates = []
      @checkedStates.each{|id|
        state = State.find(id.to_i)
        myStates.push(state)
        # localOrganizations = state.rackets.where(:active=>true).uniq
        localOrganizations = state.rackets
        localOrganizations = helpers.indexCartels(localOrganizations)
        @checkedTypes.each{|type|
          @cartels.push(type.organizations.merge(localOrganizations))
        }
      }
      @cartels.flatten!
      @cartels = @cartels.uniq
      @cartels = @cartels.sort_by{|cartel| cartel.name}
      byType = [[],[],[]]
      @cartels.each{|cartel|
        if cartel.league == "Cártel"
          byType[0].push(cartel)
        elsif cartel.league == "Mafia"
          byType[1].push(cartel)
        else
          byType[2].push(cartel)
        end
      }
      @cartels = byType.flatten
      if @checkedStates.length == 32 && @checkedCoalitions == helpers.coalitionKeys && @checkedTypes.length == 3
        @colorArr = Cookie.where(:category=>"organizations").last.data[0][:colorData]
        @alliedCartels = Cookie.where(:category=>"organizations").last.data[0][:alliedCartels]
        @alliedCartels = @alliedCartels.uniq
      else
        @colorArr = []
        @alliedCartels = []
        @cartels.each {|cartel|
          cartelIn = false
          @checkedCoalitions.each{|thisCoalition|
            if cartel.coalition = thisCoalition["name"]
               @colorArr.push(thisCoalition["material_color"])
               cartelIn = true
            end
            unless cartelIn
              @colorArr.push(thisCoalition["material_color"])
              cartelIn = true
            end
            # leader = Organization.where(:name=>coalition["name"]).last
            # if leader
            #   if cartel.name == leader.name or leader.subordinates.include? cartel or leader.allies.include? cartel.id
            #     @colorArr.push(coalition["material_color"])
            #     cartelIn = true 
            #   end
            # else
            #   unless cartelIn
            #     @colorArr.push(coalition["material_color"])
            #     cartelIn = true         
            #   end
            # end
          }
          if cartelIn
            @alliedCartels.push(cartel)
          end
        }
      end

      if @alliedCartels.empty?
        session[:empty_request] = true
        redirect_to '/organizations/query'
      end

      @n = @alliedCartels.length-1

      if @checkedStates.length == 1
        myPlaces = State.find(@checkedStates).last.counties
      else
        myPlaces = myStates
      end

     
      if myPlaces == State.all && @checkedCoalitions == helpers.coalitionKeys && @checkedTypes.length == 3
        @placeArr = Cookie.where(:category=>"organizations").last.data[0][:placeData].uniq
      else
        @placeArr = []
        myPlaces.each{|place|
          placeRackets = place.rackets.merge(@alliedCartels)
          myRackets = []
          myLeaders = []
          placeRackets.each{|racket|
            racketHash = {}
            if @alliedCartels.include? racket
              racketHash[:name] = racket.name
            end
            cartelIn = false
            @checkedCoalitions.each{|coalition|              
              if racket.coalition == coalition["name"]
                myLeaders.push(coalition["name"])
                cartelIn = true
                racketHash[:color] = coalition["dark_color"]
              end
            }
            unless cartelIn
              racketHash[:color] = '#454157'         
            end
            myRackets.push(racketHash)
          }
          myLeaders = placeRackets.pluck(:coalition).uniq
          if myLeaders.include? "Cártel de Sinaloa"
            if myLeaders.include? "Cártel Jalisco Nueva Generación"
              placeCoalition = 0
            else
              placeCoalition = 1
            end
          else
            if myLeaders.include? "Cártel Jalisco Nueva Generación"
              placeCoalition = 2
            else
              placeCoalition = 3
            end
          end
          if @checkedStates.length == 1
            placeHash = {:name=>place.name, :shortname=>place.shortname, :full_code=>place.full_code, :freq=>myRackets.length, :rackets=>myRackets, :coalition=>placeCoalition}
          else
            placeHash = {:name=>place.name, :shortname=>place.shortname, :code=>place.code, :freq=>myRackets.length, :rackets=>myRackets, :coalition=>placeCoalition}
          end
          unless placeHash[:freq] == 0
            @placeArr.push(placeHash)
          end
        }
      end

      State.all.each{|state|
        stateRackets = state.rackets.uniq
        myRackets = []

        stateRackets.each{|racket|
          racketHash = {}
          if @alliedCartels.include? racket
            myRackets.push(racket)
          end
          cartelIn = false
        }
      }

      if @checkedCoalitions.length == 1
        @lightMapColor = @checkedCoalitions[0]["color"]
        @darkMapColor = @checkedCoalitions[0]["dark_color"]
      else
        @lightMapColor = "#ffcdd2"
        @darkMapColor = "#c62828"
      end

      # PAGES
      @page_scope = 10
      @numberOfPages = @n/@page_scope
      session[:indexPage] = 0
      @beginning = 1+((session[:indexPage]-1)*@page_scope) 
      if session[:indexPage] >= (@n/@page_scope.to_f).ceil
        @finalPage = true
      end
      if session[:indexPage]+1 >= (@n/@page_scope.to_f).ceil
        @finalPagePlus = true
      end

      # UNDEFINED COUNTIES FOR SINGLE STATE MAP
      if @checkedStates.length == 1
        # @undefined = @alliedCartels.clone
        @undefined = []      
        @alliedCartels.each{|cartel|
            cartelUndefined = true
            State.find(@checkedStates.last).counties.where.not(:name=>"Sin definir").each{|county| 
            if county.rackets.include? cartel
              cartelUndefined = false
            end
          }
          if cartelUndefined
            @undefined.push(cartel)
          end
        }       
      end

      # ADD COOKIE THAT WE WILL USE FOR DOWNLOADS
      alliedArr = []
      @alliedCartels.each{|cartel|
        alliedArr.push(cartel.id)
      }
      Cookie.create(:category=>"send_file", :data=>alliedArr) 
      Cookie.create(:category=>"send_map_data", :data=>@checkedStates) 
    end

    def api
      # cartels = Sector.where(:scian2=>"98").last.organizations.where(:active=>true).uniq
      cartels = Sector.where(:scian2=>"98").last.organizations
      cartels = helpers.indexCartels(cartels)
      coalitionKeys = helpers.coalitionKeys
      cartels.each{|cartel|
        cartelIn = false
        coalitionKeys.each{|coalition|
          leader = Organization.where(:name=>coalition["name"]).last
          if leader
            if cartel.name == leader.name or leader.subordinates.include? cartel or leader.allies.include? cartel.id
              cartel.update(:coalition=>coalition["name"],:color=>coalition["color"])
              cartelIn = true 
            elsif cartel.parent
              if cartel.parent.coalition == leader.name
                cartel.update(:coalition=>coalition["name"],:color=>coalition["color"])
                cartelIn = true 
              end
            end
          end
        }
        unless cartelIn
          cartel.update(:coalition=>coalitionKeys[2]["name"],:color=>coalitionKeys[2]["color"])
          cartelIn = true       
        end
      }

      byType = [[],[],[]]
      cartels.each{|cartel|
        if cartel.league == "Cártel"
          byType[0].push(cartel)
        elsif cartel.league == "Mafia"
          byType[1].push(cartel)
        else
          byType[2].push(cartel)
        end
      }

      cartels = byType.flatten
      @colorArr = []
      @alliedCartels = []
      cartels.each {|cartel|
        cartelIn = false
        coalitionKeys.each{|coalition|
          if cartel.coalition == coalition["name"]
            @colorArr.push(coalition["material_color"])
            cartelIn = true 
          end
          unless cartelIn
            @colorArr.push(coalition["material_color"])
            cartelIn = true         
          end
        }
        if cartelIn
          @alliedCartels.push(cartel)
        end
      }

      @placeArr = []
      State.all.each{|place|
        # placeRackets = place.rackets.where(:active=>true).uniq
        placeRackets = place.rackets
        placeRackets = helpers.indexCartels(placeRackets)
        myRackets = []
        myLeaders = []
        placeRackets.each{|racket|
          racketHash = {:name=> racket.name}
          cartelIn = false
          helpers.coalitionKeys.each{|coalition|
            leader = Organization.where(:name=>coalition["name"]).last
            if leader
              if racket.name == leader.name or leader.subordinates.include? racket or leader.allies.include? racket.id
                myLeaders.push(leader.name)
                cartelIn = true
                racketHash[:color] = coalition["dark_color"]
              end
            end
          }
          unless cartelIn
            racketHash[:color] = '#454157'         
          end
          myRackets.push(racketHash)
        }
        myLeaders = placeRackets.pluck(:coalition).uniq
        if myLeaders.include? "Cártel de Sinaloa"
          if myLeaders.include? "Cártel Jalisco Nueva Generación"
            placeCoalition = 0
          else
            placeCoalition = 1
          end
        else
          if myLeaders.include? "Cártel Jalisco Nueva Generación"
            placeCoalition = 2
          else
            placeCoalition = 3
          end
        end
        placeHash = {:name=>place.name, :shortname=>place.shortname, :code=>place.code, :freq=>myRackets.length, :rackets=>myRackets, :coalition=>placeCoalition}
        unless placeHash[:freq] == 0
          @placeArr.push(placeHash)
        end
      }
      dataArr = [
        {
          :placeData=>@placeArr,
          :colorData=>@colorArr,
          :alliedCartels=>@alliedCartels.uniq
        }
      ]
      Cookie.create(:category=>"organizations", :data=>dataArr)
      
      # CREATE NATIONAL SEND FILE COOKIE
      fileData = []
      header = ['NOMBRE','TIPO','SUBTIPO','COALICIÓN']
      validStates = State.all.sort_by{|state| state.code}
      validStates.each{|state|
        header.push(state.shortname)
      }
      fileData.push(header)
      # cartels = Sector.where(:scian2=>"98").last.organizations.where(:active=>true).uniq
      cartels = Sector.where(:scian2=>"98").last.organizations
      cartels = helpers.indexCartels(cartels)
      cartels.each {|myCartel|
        row = []
        row.push(myCartel.name)
        row.push(myCartel.league)
        if myCartel.subleague
          row.push(myCartel.subleague)
        else 
          row.push('N.D.') 
        end
        row.push(myCartel.coalition)
        validStates.each{|state|
          if state.rackets.include? myCartel
            row.push(1)
          else
            row.push(0)
          end
          fileData.push(row)
        }
      }
      Cookie.create(:category=>"organizations_national_file", :data=>fileData)
      redirect_to '/organizations/query'
    end

    def show
      @organizations = true
      if session[:organization_selection].nil?
        helpers.clear_session
        cartels = Sector.where(:scian2=>98).last.organizations.uniq
        cartels = cartels.sort_by{|cartel| cartel.name}
        coalitionKeys = helpers.coalitionKeys
        typeKeys = cartels.pluck(:mainleague_id).uniq
        session[:organization_selection] = [typeKeys, coalitionKeys]
      end
      # REPEATED STUFF FOR FILTER-BOX
      allCartels = Sector.where(:scian2=>98).last.organizations.uniq
      @states = State.all.sort
      if session[:checkedStates]
        @checkedStates = Cookie.find(session[:checkedStates]).data
      else
        @checkedStates = State.pluck(:id)
      end     
      @checkedTypes = []
      session[:organization_selection][0].each{|key|
        @checkedTypes.push(League.find(key.to_i))
      }

      @typeKeys = allCartels.pluck(:mainleague_id).uniq
      @allTypes = []
      @typeKeys.each{|key|
        @allTypes.push(League.find(key.to_i))
      }

      @allCoalitions = helpers.coalitionKeys

      @checkedCoalitions = session[:organization_selection][1][0..-2]
      if session[:organization_selection][2] == true
        @checkedCoalitions.push({"name"=>"Sin coalición","color"=>'#f5f5f5'})
      end

      @myActivities = []
      activityArr = [
        "Narcotráfico",
        "Narcomenudeo",
        "Extorsión",
        "Mercado Ilícito de Hidrocarburos",
        "Trata y tráfico de personas",
        "Lavado de dinero"
      ]

      @allActivities = Sector.where(:scian2=>"98").last.divisions
      @allActivities.each{|activity|
        if activityArr.include? activity.name
          @myActivities.push(activity)
        end
      }

      @cartels = []
      @checkedTypes.each{|type|
        @cartels.push(type.organizations)
      }
      @cartels.flatten!
      @cartels = @cartels.sort_by{|cartel| cartel.name}
      @colorArr = []
      @alliedCartels = []
      @cartels.each {|cartel|
        cartelIn = false
        session[:organization_selection][1].each{|coalition|
          leader = Organization.where(:name=>coalition["name"]).last
          if leader
             if cartel.name == leader.name or leader.subordinates.include? cartel or leader.allies.include? cartel.id
              @colorArr.push(coalition["material_color"])
              cartelIn = true 
            end
          else
            @colorArr.push(coalition["material_color"])
            cartelIn = true
          end
        }
        if cartelIn
          @alliedCartels.push(cartel)
        end
      }
      @checkedCoalitions = session[:organization_selection][1]
      @n = @alliedCartels.length-1

      # PROPER SHOW STUFF
      session[:map] = true
      @myOrganization = Organization.find(params[:id])
      @racketStates = @myOrganization.states.uniq
      @racketCounties = @myOrganization.counties

      # HEADER
      @headerTitle = @myOrganization.name

      @cartels = Sector.where(:scian2=>98).last.organizations.uniq
      @cartels = @cartels.sort_by{|cartel| cartel.name}

      @aliasSections = []
      if @myOrganization.alias?
        aliasSection = {
          :title=>"Otras denominaciones",
          :records=>@myOrganization.alias,
          :links=>false,
        }
        @aliasSections.push(aliasSection)
      end

      unless @myOrganization.origin == []
        @thisString = @myOrganization.origin.last
        unless Organization.where(:name=>@thisString).empty?
          @originOrganization = Organization.where(:name=>@thisString).last
        end
      end
      @myActivities = @myOrganization.divisions.where.not(:name=>"General").uniq
        
      @treeSections = []
      unless @myOrganization.subordinates.empty? 
        subordinatesSection = {
          :title=>"Grupos subordinados",
          :records=>@myOrganization.subordinates,
          :links=>true,
        }
        @treeSections.push(subordinatesSection)
      end
      unless @myOrganization.rivals.empty?
        rivalSection = {
          :title=>"Conflictos en curso",
          :records=>@myOrganization.rivals,
          :links=>true,
        }
        @treeSections.push(rivalSection)
      end
      if @myOrganization.allies?
        alliesSection = {
          :title=>"Aliados",
          :records=>@myOrganization.allies,
          :links=>true,
        }
        @treeSections.push(alliesSection)
      end

      @singleSections = []
      if @myOrganization.parent
            parentSection = {
          :title=>"Subordinada a ",
          :record=>@myOrganization.parent
        }
        @singleSections.push(parentSection)
      end
      
      @leads = @myOrganization.leads.sort_by{|lead| lead.event.event_date}
      @leads.reverse!
      @leadArr = []
      myCounter = 0
      @leads.each{|lead|
        leadHash = {}
        leadHash[:myObject] = lead 
        # leadHash[:label] = labels[myCounter]
        myCounter +=1
        leadHash[:counter] = myCounter
        leadHash[:category] = lead.category
        leadHash[:geo] = false
        if lead.event.town.name == "Sin definir"
          leadHash[:geo] = true
          leadHash[:lat] = lead.event.town.latitude
          leadHash[:lng] = lead.event.town.longitude 

      # DEFINED TOWNS: EDIT LATER TO GEOLOCATE NEIGHBORHOODS
        else
          myCounty = lead.event.town.county
          leadHash[:geo] = true
          pseudoTown = myCounty.towns.where(:name=>"Sin definir").last
          leadHash[:lat] = pseudoTown.latitude
          leadHash[:lng] = pseudoTown.longitude 
        end
        unless leadHash[:lat].nil?
          @leadArr.push(leadHash)
        end 
      } 

      @key = Rails.application.credentials.google_maps_api_key


      @allCoalitions = helpers.coalitionKeys
      cartelIn = false
      @allCoalitions.each{|coalition|
        leader = Organization.where(:name=>coalition["name"]).last
        if leader
          if @myOrganization.name == leader.name or leader.subordinates.include? @myOrganization or leader.allies.include? @myOrganization.id
            cartelIn = true
            @coalitionColor = coalition["color"]
          end
        end 
        unless cartelIn
            @coalitionColor = '#454157'  
        end     
      }
    end

    def main
      @myYears = helpers.get_years  
      @states = State.all.sort
      @cities = City.all.sort_by{|city|city.name}
      @county_search_input = "query[county_id]"
      session[:page] = nil
      session[:params] = nil

      @myQueries = [
        {caption:"Eventos", box_id:"killing_query_box", name:"for_killing"},
      {caption:"Víctimas", box_id:"victim_query_box", name:"for_victim"},
      # {caption:"Fuentes", box_id:"source_query_box", name:"for_source"},
      ]

      @victim_checkboxes = [
        {caption: "NOMBRE", name:"query[victim_name]"},
        {caption: "ALIAS", name:"query[victim_alias]"},
        {caption: "SEXO", name:"query[victim_gender]"},
        {caption: "EDAD", name:"query[victim_age]"},
        {caption: "CARACTERÍSTICAS", name:"query[victim_boolean]"},
      ]

      @state_checkboxes = [
        {caption: "NOMBRE", name:"query[state_name]"},
        {caption: "ABREVIATURA", name:"query[state_acronym]"},
        {caption: "CLAVE", name:"query[state_code]"},
        {caption: "POBLACIÓN", name:"query[state_population]"},
      ]

      @county_checkboxes = [
        {caption: "NOMBRE", name:"query[county_name]"},
        {caption: "CLAVE",  name:"query[county_full_code]"},
        {caption: "POBLACIÓN", name:"query[county_population]"},
        {caption: "Z. METRO.", name: "query[city_name]"},
      ]

      @event_checkboxes = [
        {caption: "FECHA", name:"query[event_date]"},
        {caption: "FUENTES", name:"query[event_sources]"},
        {caption: "# VÍCTIMAS", name:"query[killed_count]"},
        {caption: "# AGRESORES", name:"query[aggresor_count]"},
        {caption: "TIPO DE LUGAR", name:"query[type_of_place]"},
        {caption: "ARMAS USADAS", name:"query[weapons]"},
        {caption: "# VEHÍCULOS", name:"query[killer_vehicle_count]"},
        {caption: "CARACTERÍSTICAS", name:"query[killing_boolean]"},

      ]

      @source_checkboxes = [
        {caption: "FECHA", name:"query[source_publication]"},
        {caption: "MEDIO/LINK",  name:"query[source_organization]"},
        {caption: "AUTOR", name:"query[source_member]"},
        {caption: "INCIDENTES", name: "query[event_description]"},
      ]

      @events = Event.all
      @killings = Killing.all
      @victims = Victim.all
      @sources = Source.all
      # @papers = Division.where(:scian3=>510).last.organizations
    end

    def login
      target_user = User.find_by_mail(password_params[:mail])
      if target_user && target_user.authenticate(password_params[:password])
        session[:user_id] = target_user[:id]
        if target_user.membership_type
          session[:membership] = target_user.membership_type 
        else
          session[:membership] = 0
        end
        helpers.clear_session
        redirect_to '/intro'
      else
        session[:password_error] = true
        redirect_to '/password'
      end   
    end

  def logout
    session[:user_id] = nil
    redirect_to '/password'
  end

  def new
    @county_search_input = "query"
    @organization_header = form_header("account_balance","Organización")
    @states = State.all
    @sectors = Sector.all.sort_by{|record| record.scian2}
    @organization_text_inputs = [
      {field_name: "name", caption: "NOMBRE", selector: "organization_name_selector"},
      {field_name: "legal_name", caption: "RAZÓN SOCIAL", selector: "organization_legal_name_selector"},
      {field_name: "rfc", caption: "RFC", selector: "organization_rfc_selector"},
      {field_name: "acronym", caption: "SIGLAS", selector: "organization_acronym_selector"},
    ]
  end

  def create_organization
    myName = create_organization_params[:name]
    myrfc = create_organization_params[:rfc]
    myAcronym = create_organization_params[:acronym]
    myCounty = create_organization_params[:county_id]
    thisDivision = create_organization_params[:division_id]
    Organization.create(:name=>myName,:rfc=>myrfc,:acronym=>myAcronym,:county_id=>myCounty)
    Organization.last.avatar.attach(create_organization_params[:avatar])
    myDivision = Division.find(thisDivision)
    targetOrganization = Organization.last
    unless targetOrganization.divisions.include? (myDivision) 
      targetOrganization.divisions << myDivision
    end
    redirect_to "/organizations/new"
  end

  def getDivisions
      targetSector = getDivisions_params[:sector_id].to_i
      targetDivisions = Sector.find(targetSector).divisions
      render json: {divisions: targetDivisions}     
  end


  def getMembers
      targetOrganization = params[:organization_id].to_i
      targetMembers = Organization.find(targetOrganization).members
      render json: {members: targetMembers}   
  end

  def get_cartels
    myCartels = Sector.where(:scian2=>98).last.organizations.uniq
    matches = myCartels.select{|cartel| helpers.bob_decode(cartel.name).downcase.include? helpers.bob_decode(params[:myString]).downcase}    
    if matches.length >= 1 && matches.length <= 10 
      render json: matches
    end
  end

  def load_organizations
    divisions = [
      {:slot=>11,:scian3=>981,:name=>"Narcotráfico"},
      {:slot=>12,:scian3=>982,:name=>"Narcomenudeo"},
      {:slot=>13,:scian3=>983,:name=>"Extorsión"},
      {:slot=>14,:scian3=>984,:name=>"Mercado Ilícito de Hidrocarburos"},
      {:slot=>15,:scian3=>985,:name=>"Trata y tráfico de personas"},
      {:slot=>16,:scian3=>986,:name=>"Tráfico de armas"},
      {:slot=>17,:scian3=>987,:name=>"Robo de ferrocarril"},
      {:slot=>18,:scian3=>988,:name=>"Robo de transportistas"},
      {:slot=>19,:scian3=>989,:name=>"Tala clandestina"},
      {:slot=>20,:scian3=>991,:name=>"Contrabando de mercancías"},
      {:slot=>21,:scian3=>992,:name=>"Lavado de dinero"},
      {:slot=>22,:scian3=>994,:name=>"Fraude"},
      {:slot=>23,:scian3=>993,:name=>"Actos de terrorismo"},
      {:slot=>24,:scian3=>995,:name=>"Vandalismo"},
      {:slot=>25,:scian3=>996,:name=>"Robo a comercio"},
      {:slot=>26,:scian3=>997,:name=>"Robo a casa habitación"},
      {:slot=>27,:scian3=>998,:name=>"Robo de vehículo"},
      {:slot=>28,:scian3=>993,:name=>"Piratería"},
      {:slot=>29,:scian3=>1000,:name=>"Autogobierno penitenciario"}
    ]

    myFile = load_organizations_params[:file]
    table = CSV.parse(File.read(myFile))

    table.each{|x|
      x = x.collect{ |e| e ? e.strip : e }
    # CREATE ORGANIZATION IF IT DOES NOT EXIST
      if Organization.where(:name=>x[0].strip).empty?
        print "NEW ORGANIZATION :" + x[0]
        Organization.create(:name=>x[0].strip)
      end
    }

     
    table.each{|x|
      x = x.collect{ |e| e ? e.strip : e }
      targetOrganization = Organization.where(:name=>x[0]).last
    
      # UPDATE GENERAL INFO
      targetActive = false
      if x[1] == "Activa"
        targetActive = true
      end
      myAcronym = x[4]
      unless myAcronym.nil?
        myAcronym = myAcronym
      end
      targetOrganization.update(:acronym=>myAcronym, :league=>x[5], :subleague=>x[6], :active=>targetActive)

      # UPDATE DIVIDIONS

      divisions.each{|y|
        generalDivision = Division.where(:scian3=>980).last
        unless targetOrganization.divisions.include? (generalDivision)
          targetOrganization.divisions << generalDivision
        end
        myDivision = Division.where(:scian3=>y[:scian3]).last
        if x[y[:slot]] == "1"
          print "ACITVITY HIT!!!"
          unless targetOrganization.divisions.include? (myDivision)
          targetOrganization.divisions << myDivision
          end
        end
      }

      # UPDATE PARENT ORIGIN ALLIES AND RIVALS
      targetOrganization = Organization.where(:name=>x[0]).last
      unless x[3].nil?
        myNames = x[3].split(";")
        cleanNames = []
        myNames.each {|myName|
          myName = myName
          cleanNames.push(myName)
        }
        targetOrganization.update(:alias=>cleanNames)
      end 
      unless x[7].nil?
        unless Organization.where(:name=>x[7]).empty?
          parentOrganization = Organization.where(:name=>x[7]).last
          targetOrganization.update(:parent_id=>parentOrganization.id)
        end
      end
      unless x[8].nil?
        myOrigins = []
        x[8].split(";").each{|org|
          org = org
          # unless Organization.where(:name=>org).empty?
          #   originOrganization = Organization.where(:name=>org).last
          #   myOrigins.push(originOrganization.id)
          # end 
          myOrigins.push(org) 
        }
        targetOrganization.update(:origin=>myOrigins)
      end 
      unless x[9].nil?
        myAllies = []
        x[9].split(";").each{|org|
          org = org
          unless Organization.where(:name=>org).empty?
            alliedOrganization = Organization.where(:name=>org).last
            myAllies.push(alliedOrganization.id)
          end 
        }
        targetOrganization.update(:allies=>myAllies)
      end 
      unless x[10].nil?
        myRivals = []
        x[10].split(";").each{|org|
          org = org
          unless Organization.where(:name=>org).empty?
            print org
            rivalOrganization = Organization.where(:name=>org).last
            myRivals.push(rivalOrganization.id)
          end
        }
        targetOrganization.update(:rivals=>myRivals)  
      end 
    }

    cartels = Sector.where(:scian2=>98).last.organizations.uniq

    cartels.each{|cartel|
      unless cartel.league.nil?
        clearLeague = cartel.league
      end
      unless cartel.subleague.nil?
        clearSubleague = cartel.subleague
      end
      cartel.update(:league=>clearLeague,:subleague=>clearSubleague)
    }
    helpers.recyprocal_organizations
    helpers.update_league 

    session[:filename] = load_organizations_params[:file].original_filename
    session[:load_success] = true

    redirect_to "/datasets/load"
  end

  def load_organization_events

    myCategories = [
      "Abatimiento en operativo",
      "Agresión a civiles",
      "Agresión a servidores públicos",
      "Base social criminal",
      "Bloqueo de vías de comunicación",
      "Denuncia ciudadana",
      "Desplazamiento forzado",
      "Detención de alto perfil",
      "Ejecución de integrantes",
      "Enfrentamiento con autoridades",
      "Enfrentamiento con civiles",
      "Fuga penitenciaria",
      "Narcomensaje",
      "Operativo de instituciones de seguridad",
      "Presencia registrada en investigación académica",
      "Presencia registrada en medios",
      "Presencia registrada por autoridades",
      "Reclutamiento",
      "Servidores públicos con vínculos criminales"
    ] 
    
    myFile = load_organization_events_params[:file]
    table = CSV.parse(File.read(myFile))

    table.each{|x|
      countyString = x[1].to_i
      countyString = countyString + 100000
      countyString = countyString.to_s
      countyString = countyString[1..-1]
      x = x.collect{ |e| e ? e.strip : e }
      if Lead.where(:legacy_id=>x[0]).empty?
        if myCategories.include? x[8]
          unless Organization.where(:name=>x[3]).empty?
            myOrganization = Organization.where(:name=>x[3]).last.id
            myString = x[9][6..-1]+"_"+x[9][3,2]
            myMonth =  Month.where(:name=>myString).last.id
            unless x[2].nil? 
              towns = []
              townArr = x[2].split(";")
              townArr.each{|townName|
                unless County.where(:full_code=>countyString).last.towns.where(:name=>townName).empty?
                  thisTown = County.where(:full_code=>countyString).last.towns.where(:name=>townName).last.full_code
                  towns.push(thisTown)
                else
                  towns.push(countyString+"0000")
                end
                towns = towns.uniq
              }
            else
              towns = [countyString+"0000"]
            end
            towns.each{|town|
              myTown = Town.where(:full_code=>town).last.id
              # ADD EVENT AND SOURCES
              Event.create(:organization_id=>myOrganization, :town_id=>myTown, :event_date=>x[9], :month_id=>myMonth)
              (10..14).each{|y|
                Source.create(:url=>x[y])
                mySource = Source.last
                unless Event.last.sources.include? (mySource)
                  Event.last.sources << mySource
                end
              }

              # ADD LEAD
              myEvent = Event.last.id
              Lead.create(:legacy_id=>x[0], :category=>x[8], :event_id=>myEvent)  
            }
            
            # ADD MEMBERS
             unless Organization.where(:name=>x[3]).empty?
              unless x[4].nil? && x[7].nil?
                if Organization.where(:name=>x[3]).last.members.where(:firstname=>x[4],:lastname1=>x[5],:lastname2=>x[7]).empty?
                  myAlias = nil
                  unless x[7].nil?
                    myAlias = x[7].split(";")
                  end
                  Member.create(:organization_id=>myOrganization,:firstname=>x[4],:lastname1=>x[5],:lastname2=>x[7], :alias=>myAlias)
                end
              end
            end
          end
        end
      else
        if myCategories.include? x[8]
          myLead = Lead.where(:legacy_id=>x[0])
          myLead.update(:category=>x[8])
        end 
      end
    }

    session[:filename] = load_organization_events_params[:file].original_filename
    session[:load_success] = true

    redirect_to "/datasets/load"
  end

  def load_organization_territory

    myFile = load_organization_events_params[:file]
    table = CSV.parse(File.read(myFile))

    table.each{|x|
      x = x.collect{ |e| e ? e.strip : e }
      unless x[2].nil?
        unless Organization.where(:name=>x[2]).empty?
          targetOrganization = Organization.where(:name=>x[2]).last
          towns = []
          countyString = x[0].to_i
          countyString = countyString + 100000
          countyString = countyString.to_s
          countyString = countyString[1..-1]
          pseudoTown = Town.where(:full_code=>countyString+"0000").last
          towns.push(pseudoTown)
          unless x[1].nil?
            x[1].split(";").each{|town|
              unless County.where(:full_code=>countyString).last.towns.where(:name=>town)
                myTown = County.where(:full_code=>x[0]).last.towns.where(:name=>town).last
                towns.push(myTown)
              end
            }
          end

          towns.each{|town|
            if targetOrganization.towns.where(:full_code=>town.full_code).empty?
              targetOrganization.towns << town
            end
          }
        end 
      end
    }

    myFile = load_organization_territory_params[:file]
    table = CSV.parse(File.read(myFile))


    session[:filename] = load_organization_territory_params[:file].original_filename
    session[:load_success] = true
    redirect_to "/states/conflict_analysis"   
  end

  def new_name
    myOrganization = Organization.find(new_name_params[:cartel_id])
    legacy_names = myOrganization.legacy_names
    myHash = {
      :name=> myOrganization.name,
      :change_date=> Date.today
    }
    legacy_names.push(myHash)
    myOrganization.alias.each{|myString| myString.strip!}
    aliasArr = myOrganization.alias
    aliasArr.push(myOrganization.name)
    myOrganization.update(:alias=>aliasArr)
    myOrganization.update(:name=>new_name_params[:new_name], :legacy_names=>legacy_names)
    if  myOrganization.alias.include? new_name_params[:new_name]
      myOrganization.alias.delete(new_name_params[:new_name])
    end
    redirect_to "/datasets/load"
  end

  def get_type_title(types)
    if types.length == 1
      if types[0][:name] == "Banda"
        myString = "Bandas"
      elsif types[0][:name] == "Mafia"
        myString = "Mafias"
      else
        myString = "Cárteles"
      end
    elsif types.length == 2
      if types.pluck(:name).include? "Banda" 
        if types.pluck(:name).include? "Mafia" 
          myString = "Mafias y Bandas"
        else
          myString = "Cárteles y Bandas"
        end
      else
        myString = "Cárteles y Mafias"
      end 
    else
      myString = "Presencia reportada de organizaciones criminales"
    end
    return myString
  end

  def frontpage
    render :layout => false 
  end

   def send_file
      recipient = User.find(session[:user_id])
      current_date = Date.today.strftime
      downloadCounter = recipient.downloads
      downloadCounter += 1
      recipient.update(:downloads=>downloadCounter)
      
      # ADDING STRING TO STATE FILE
      mapData = Cookie.where(:category=>"send_map_data").last.data
      if mapData.length > 1
        file_name = "Organizaciones_"+downloadCounter.to_s+"_"+current_date+".csv"
      else 
        if mapData[0] < 10
          trueCode = "0"+mapData[0].to_s  
        else
          trueCode = mapData[0]
        end
        myState = State.where(:code=>trueCode).last
        file_name = "Organizaciones_"+myState.shortname+"_"+downloadCounter.to_s+"_"+current_date+".csv"
      end
      
      def build_file        
          myData = Cookie.where(:category=>"send_file").last.data
          CSV.generate do |writer|
              writer.to_io.write "\uFEFF"
              header = ['NOMBRE','TIPO','SUBTIPO','COALICIÓN']
              mapData = Cookie.where(:category=>"send_map_data").last.data
              validStates = State.all.sort_by{|state| state.code}
              if mapData.length > 1
                # validStates.each{|state|
                #   header.push(state.shortname)
                # }
                header =  Cookie.where(:category=>"organizations_national_file").last.data[0]
              else
              if mapData[0] < 10
                trueCode = "0"+mapData[0].to_s  
              else
                trueCode = mapData[0]
              end
                myState = State.where(:code=>trueCode).last
                allCounties = myState.counties.sort_by{|county| county.code}
                validCounties = []
                allCounties.each{|county|
                  unless county.rackets.where(:active=>true).length == 0
                    validCounties.push(county)
                    myString = county.full_code+" - "+county.name
                    header.push(myString)
                  end
                } 
              end
              writer << header
              myData.each do |id|
                  row = []
                  myCartel = Organization.find(id)
                  row.push(myCartel.name)
                  row.push(myCartel.league)
                  if myCartel.subleague
                    row.push(myCartel.subleague)
                  else 
                    row.push('N.D.') 
                  end
                  row.push(myCartel.coalition)
                  if mapData.length > 1                 
                    validStates.each{|state|
                      if state.rackets.include? myCartel
                        row.push(1)
                      else
                        row.push(0)
                      end
                    }
                  else
                    validCounties.each{|county|
                      if county.rackets.include? myCartel
                        row.push(1)
                      else
                        row.push(0)                    
                      end
                    }
                  end
                  writer << row
              end
          end
      end
          
      myFile = build_file
      respond_to do |format|
        format.html
        format.csv { send_data myFile, filename: file_name}
      end        
  end


  private

  def organization_selection_params
    params.require(:query).permit(types: [], coalitions: [], freq_states: [])
  end

  def load_organizations_params
    params.require(:query).permit(:file)
  end

  def load_organization_events_params
    params.require(:query).permit(:file)
  end

  def load_organization_territory_params
    params.require(:query).permit(:file)
  end
    
  def password_params
    params.require(:user).permit(:mail, :password)
  end

  def create_organization_params
    params.require(:organization).permit(:name, :rfc, :acronym, :county_id, :division_id, :avatar)
    
  end

  def getDivisions_params
      params.require(:organization).permit(:sector_id)
  end

  def getMembers_params
    params.require(:source).permit(:organization_id)
  end

  def getFields_params
    params.require(:query).permit(:general)
  end

  def new_name_params
    params.require(:query).permit(:cartel_id, :new_name)
  end
end
