class ApplicationController < ActionController::Base

# ERROR CON BCRYPT! Valladares/Users/Bobsled/.rvm/gems/ruby-2.7.1/gems/bcrypt-3.1.13/lib/bcrypt/password.rb:50: warning: deprecated Object#=~ is called on Integer; it always returns nil Completed 500 Internal Server Error in 76ms (ActiveRecord: 3.2ms | Allocations: 9495) BCrypt::Errors::InvalidHash (invalid hash):

	before_action :require_login, except: [:password, :login]

	helper_method :myResouces

	def require_login
		redirect_to "/password" if session[:user_id] == nil
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

	protected

		def myResouces
			@myResouces = ["CAPTURA","CONSULTA"]
		end

end
