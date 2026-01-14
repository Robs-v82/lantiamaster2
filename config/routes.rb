Rails.application.routes.draw do
    root 'users#intro'
    get 'users/index'
    post 'states/load_irco'
    post 'states/load_icon'
    post 'counties/load_irco'
    get 'counties/low_risk'
    get 'counties/high_risk'
    get 'counties/destinations'
    get 'counties/irco'
    get 'states/irco'
    get 'states/icon'
    get 'states_and_counties_api' => 'datasets#states_and_counties_api'
    get 'year_victims_api' => 'datasets#year_victims_api'
    get 'year_victims' => 'datasets#year_victims'
    get 'state_victims_api' => 'datasets#state_victims_api'
    get 'state_victims' => 'datasets#state_victims'
    get 'county_victims_api' => 'datasets#county_victims_api'
    get 'county_victims' => 'datasets#county_victims'
    get 'county_victims_map_api' => 'datasets#county_victims_map_api'
    get 'county_victims_map' => 'datasets#county_victims_map'
    get 'featured_state_api' => 'datasets#featured_state_api'
    get 'featured_county_api' => 'datasets#featured_county_api'
    get 'loadApi' => 'datasets#loadApi'
    get 'organizations/index'
    get 'organizations/back_query'
    post 'members/detentions'
    get 'members/detainees'
    get 'members/new_query'
    get 'members/detainees_freq_api'
    get 'quarters/ispyv'
    get 'months/reports' => 'months#reports'
    get 'datasets/show'
    get 'datasets/load'
    get 'datasets/api_control'
    get 'datasets/load_featured_state'
    get 'datasets/load_featured_county'
    get 'sources/twitter'
    get 'organizations/get_cartels/:myString' => 'organizations#get_cartels'
    post 'organizations/load_organizations'
    post 'organizations/load_organization_events'
    post 'organizations/load_organization_territory'
    get 'organizations/api'
    get 'queries/mapOff'
    get 'queries/mapOn'
    get 'password' => 'organizations#password'
    get 'organizations/logout' => 'organizations#logout'
    post 'organizations/login' => 'organizations#login'
    get 'intro' => 'users#intro'
    get 'organizations/main' => 'organizations#main'
    post 'counties/getCounties' => 'counties#getCounties'
    post 'towns/getTowns' => 'towns#getTowns'
    get 'sources/twitter'=>'sources#twitter'
    get 'events/killings'=>'events#killings'
    post 'events/create_killing'=>'events#create_killing'
    get 'events/victims/:killed_count' => 'events#victims'
    post 'events/create_victim' => 'events#create_victims'
    post 'events/create_single_victim' => 'events#create_single_victim'
    get 'organizations/new' => 'organizations#new'
    post 'organizations/create_organization' => 'organizations#create_organization'
    post 'organizations/getDivisions' => 'organizations#getDivisions'
    post 'organizations/getMembers/:organization_id' => 'organizations#getMembers' 
    get 'send_query' => 'events#send_query'
    post 'send_query' => 'events#send_query'
    get 'pageback/:index' => 'queries#pageback'
    get 'pageforward/:index' => 'queries#pageforward'
    get 'pageback' => 'events#pageback'
    get 'pageforward' => 'events#pageforward'
    post 'queries/get_months' => 'queries#get_months'
    post 'queries/get_regular_months' => 'queries#get_regular_months'
    post 'queries/get_quarters' => 'queries#get_quarters'
    post 'states/getStates' => 'states#getStates'
    post 'states/getCities' => 'states#getCities'
    get 'queries/files' =>'queries#files'
    get 'queries/send_file/:catalogue/:extension' => 'queries#send_file'
    get 'victims/send_file/:extension/:timeframe.csv' => 'victims#send_file'
    get 'members/send_file/:extension/:timeframe.csv' => 'members#send_file'
    get 'queries/send_query_file/:extension' => 'queries#send_query_file'
    get 'queries/test_xlsx' => 'queries#test_xlsx', as: "test"
    post 'datasets/load_ensu' 
    post 'datasets/load_briefing' 
    post 'months/load_violence_report'
    post 'months/load_social_report'
    post 'months/load_forecast_report' 
    post 'months/load_crime_victim_report' 
    post 'months/header_selector/:month' => 'months#header_selector'
    get 'datasets/victims_query'
    post 'datasets/victims_query' => 'datasets#post_victim_query'
    post 'members/query' => 'members#query'
    post 'organizations/organizations_query' => 'organizations#post_query'
    get 'organizations/organizations_query/:code' => 'organizations#get_query'
    get 'datasets/victims'
    get 'datasets/basic'
    post 'counties/getCheckboxCounties/:id' => 'counties#getCheckboxCounties'
    get 'organizations/show/:id' => 'organizations#show'
    get 'organizations/query' => 'organizations#query'
    get 'counties/set_index_county/:id' => 'counties#set_index_county'
    get 'datasets/load_victim_freq_table'
    post 'organizations/new_name' => 'organizations#new_name'
    post 'victims/query'
    get 'victims/new_query'
    post 'victims/load_victims'
    get 'victims' => 'victims#victims'
    get 'victims/national_api'
    get 'victims/national/:timeframe/:placeframe' => 'victims#national_inputs'
    get 'victims/national_joint'
    get 'victims/national_annual_state'
    get 'victims/national_annual_city'
    get 'victims/test'
    get 'victims/states_api'
    get 'victims/reset_map'
    get 'victims/county_query/:code' => 'victims#county_query'
    get 'victims/green_query'
    get 'counties/autocomplete/:myString' => 'counties#autocomplete'
    get 'states/conflict_analysis'
    post 'states/stateIndexHash'
    get 'users/preloader'
    get 'counties/testmap'
    get 'frontpage' => 'organizations#frontpage'
    get 'states/send_file.csv' => 'states#send_file'
    get 'counties/send_file.csv' => 'counties#send_file'
    get 'states/send_icon.csv' => 'states#send_icon'
    get 'organizations/send_file.csv' => 'organizations#send_file'
    get 'organizations/send_national_file.csv' => 'organizations#send_national_file'
    get 'datasets/downloads'
    get 'datasets/terrorist_panel'
    post 'datasets/upload_hits'
    post 'datasets/upload_members'
    get '/datasets/download_invalid_members', to: 'datasets#download_invalid_members', as: 'download_invalid_members'
    get 'datasets/terrorist_search'
    get 'datasets/search'
    get 'datasets/members_search'
    get 'datasets/state_members/:code' => 'datasets#state_members'
    post 'datasets/members_query'
    get 'datasets/members_outcome'
    post '/web_scrape', to: 'datasets#web_scrape', as: :web_scrape
    post '/datasets/download_scraped_links', to: 'datasets#download_scraped_links', as: :download_scraped_links
    # get 'datasets/:type/:cell' => 'datasets#sort'
    get 'datasets/redirect_to_outcome/:id', to: 'datasets#redirect_to_outcome', as: 'redirect_to_outcome'
    get 'datasets/members_outcome_pdf', to: 'datasets#members_outcome_pdf', as: :members_outcome_pdf

    get 'datasets/clear_members', to: 'datasets#clear_members'
    get 'datasets/clear_state_members/:code', to: 'datasets#clear_state_members'
    post 'datasets/merge_members', to: 'datasets#merge_members'
    post 'datasets/ignore_conflict', to: 'datasets#ignore_conflict'
    get '/sesion', to: redirect('/')
    get 'datasets/download_state_rackets/:code', to: 'datasets#download_state_rackets', as: 'download_state_rackets'
    patch 'datasets/:id/update_name', to: 'datasets#update_name', as: :update_member_name
    post '/datasets/add_member_link', to: 'datasets#add_member_link', as: :add_member_link
    post '/datasets/:member_id/fake_identities', to: 'datasets#create_fake_identity'
    post '/notes/:member_id/notes', to: 'notes#create', as: 'create_member_note'
    post '/datasets/upload_linked_organization', to: 'datasets#upload_linked_organization'
    # get "/session_probe", to: "probes#session_probe"
    resources :password_resets, only: [:create, :edit, :update], param: :token
    # config/routes.rb
    get  "/reauth", to: "reauth#new"
    post "/reauth", to: "reauth#create"
    get  "/verify_email", to: "email_verifications#verify", as: :verify_email
    # (opcional) si quieres un endpoint para reenviar:
    post "/verify_email", to: "email_verifications#send_link"
    get "/welcome", to: "welcome#show", as: :verify_and_set_password

    get  "/mfa/setup",     to: "mfa#setup"
    post "/mfa/enable",    to: "mfa#enable"
    get  "/mfa/challenge", to: "mfa#challenge"
    post "/mfa/verify",    to: "mfa#verify"
    post "/mfa/disable",   to: "mfa#disable"

    get 'users/admin'
    get 'users/new'
    get 'users/edit'
    post 'users/create'
    post "users/:id/subscription", to: "users#update_subscription", as: :update_user_subscription

    namespace :api, defaults: { format: :json } do
      namespace :v1 do
        post "members/search", to: "members#search"
      end
    end

    get  "organizations/admin", to: "organizations#admin"
    post "organizations/:id/set_search_level", to: "organizations#set_search_level", as: :set_org_search_level
    post "organizations/admin_create", to: "organizations#admin_create"


end