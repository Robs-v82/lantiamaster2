class ApplicationController < ActionController::Base

# ERROR CON BCRYPT! Valladares/Users/Bobsled/.rvm/gems/ruby-2.7.1/gems/bcrypt-3.1.13/lib/bcrypt/password.rb:50: warning: deprecated Object#=~ is called on Integer; it always returns nil Completed 500 Internal Server Error in 76ms (ActiveRecord: 3.2ms | Allocations: 9495) BCrypt::Errors::InvalidHash (invalid hash):
	before_action :enforce_session_timeout
	before_action :enforce_session_version
	before_action :allow_iframe
	before_action :require_login, except: [:frontpage, :password, :login, :states_and_counties_api, :year_victims_api, :state_victims, :state_victims_api, :county_victims, :county_victims_api, :county_victims_map_api, :county_victims_map, :year_victims, :featured_state_api, :featured_county_api]
	before_action :set_variables
	helper_method :myResouces
	after_action :stop_freq_help, only: [:victims, :detainees]

	def quick_preload
		render :template => "users/preloader"
	end

	def stop_freq_help
		User.find(session[:user_id]).update(:victim_help=>false)
	end

	def allow_iframe
    	response.headers['X-Frame-Options'] = 'ALLOWALL'
  	end

	def set_variables
 		unless session[:user_id] == nil
 			@member = User.find(session[:user_id]).member
 		end
	end

	def require_login
		if session[:user_id] == nil
			if Rails.env.production?
				client = request.remote_ip
			else
				client = '::1'		
			end
			valid_index = Organization.pluck(:ip_address).uniq
			if valid_index.include? client
				myOrganization = Organization.where(:ip_address == client).last
				if myOrganization.users.empty?
					# SWITCH TO FRONTPAGE VERSION
					redirect_to "/frontpage"
					# redirect_to "/password"
				else
					session[:user_id] = myOrganization.users.first.id
					session[:membership] = 4
				end
			else
				# SWITCH TO FRONTPAGE VERSION
				redirect_to "/frontpage"	
				# redirect_to "/password"	
			end
		end
	end

	def sync_membership_session
	  return unless current_user
	  plan_id = current_user.current_plan_id
	  active  = current_user.membership_active?
	  session[:membership] = (active && plan_id) ? plan_id.to_i : 1

	  # Opcional: reflejar en DB cuando expire
	  if !active && current_user.membership_type != 1
	    current_user.update_columns(membership_type: 1, updated_at: Time.current)
	  end
	end

	# def require_login
	# 	redirect_to "/password" if session[:user_id] == nil
	# end

	def clear_this_session
		helpers.clear_session
	end

	def clear_this_member_session
		helpers.clear_member_session
	end	

	def require_pro
		redirect_to "/users/index" unless session[:membership] > 3
	end

	def require_premium
		redirect_to "/users/index" unless session[:membership] > 2
	end

	def require_basic
		redirect_to "/users/index" unless session[:membership] > 1
	end

	def require_victim_access
		redirect_to "/users/index" unless User.find(session[:user_id]).victim_access
	end

	def require_organization_access
		redirect_to "/users/index" unless User.find(session[:user_id]).organization_access
	end

	def require_detention_access
		redirect_to "/users/index" unless User.find(session[:user_id]).detention_access
	end

	def require_irco_access
		redirect_to "/users/index" unless User.find(session[:user_id]).irco_access
	end

	def require_icon_access
		redirect_to "/users/index" unless User.find(session[:user_id]).icon_access
	end

	def authenticate_terrorist_access
		user = User.find_by(id: session[:user_id])
		org_id = user&.member&.organization_id

		unless [4283, 4284].include?(org_id)
			redirect_to root_path, alert: "Acceso restringido a organizaciones autorizadas."
		end
	end

	def form_header(icon,title)
		myHeader = {
			icon: icon,
			title: title
		}
		return myHeader
	end

	def type_of_place
		myTypes = [
				"Vía pública",
				"Lote baldío (urbano)",
				"Interior de vivienda de la(s) víctima(s)",
				"Interior de vivienda (sin especificar)",
				"Acceso a vivienda",
				"Paraje (rural)",
				"Carretera",
				"Camino de terracería",
				"Automovil particular",
				"Taxi",
				"Transporte público",
				"Canal/Lago/Río",
				"Barranca",
				"Antro/Bar",
				"Narcofosa",
				"Zona montañosa"
			].sort
		myTypes.push("Otro")
		return myTypes
	end

	def hard_roles
		myRoles= [
			"Taxista",
			"Comerciante",
			"Músico",
			"Abogado",
			"Profesor",
			"Mecánico",
			"Albañil",
			"Campesino",
			"Velador",
			"Taquero",
			"Mesero",
			"Empresario",
			"Chofer",
			"Policía Municipal",
			"Policía Estatal",
			"Funcionario Público",
			"Policía No Especificado",
			"Civil accidentalmente ejecutado",
			"Militar",
			"Marino",
		].sort
		myRoles.push("Otro")
		return myRoles
	end

	def remove_email_message
		if session[:email_success]
			session[:email_success] = nil
			print "****"
			print "REMOVING EMAIL SUCCESS"
		end
	end

	def remove_load_message
		if session[:load_success]
			session[:load_success] = nil
			print "****"
			print "REMOVING LOAD SUCCESS"
		end
		if session[:bad_briefing]
			session[:bad_briefing] = nil
			print "****"
			print "REMOVING BAD BRIEFING"
		end
		if session[:scraped_links_file]
			File.delete(session[:scraped_links_file])
			session.delete(:scraped_links_file)
		end
	end

	def remove_password_error_message
		if session[:password_error]
			session[:password_error] = nil
			print "****"
			print "REMOVING PASSWORD ERROR "
		end
	end

	def remove_empty_query_message
		if session[:empty_query]
			session[:empty_query] = nil
			print "****"
			print "REMOVING EMPTY QUERY "
		end
	end

	def remove_empty_request
		if session[:empty_request]
			session[:empty_request] = nil
			print "****"
			print "REMOVING EMPTY QUERY "
		end
	end

	def clear_query_params
  		session[:params] = nil
	end

	SESSION_TIMEOUT = 60.minutes
	
	protected

		def myResouces
			@myResouces = ["CAPTURA","CONSULTA"]
		end
		
		def enforce_session_timeout
			now  = Time.current.to_i
			last = session[:last_seen_at]

			if last && (now - last) > SESSION_TIMEOUT.to_i
			reset_session
			# redirect_to '/login', alert: 'Sesión expirada'  # si quieres redirigir
			end
			session[:last_seen_at] = now
		end

		def current_user_safe
		    # usa tu método actual si existe; si no, intenta con session[:user_id]
		    return current_user if respond_to?(:current_user) && current_user
		    User.find_by(id: session[:user_id])
		  end

		  def enforce_session_version
		    u = current_user_safe
		    return unless u

		    if session[:session_version].blank?
		      # primera petición post-login: “sellar” la sesión con la versión actual del usuario
		      session[:session_version] = u.session_version
		    elsif session[:session_version] != u.session_version
		      reset_session
		      redirect_to "/login", alert: "Por seguridad, vuelve a iniciar sesión." and return
		    end
		end

end
