class UsersController < ApplicationController
  
  layout false, only: [:intro, :index]
  # before_action :set_user, only: [:show, :edit, :update, :destroy]

  # GET /users
  # GET /users.json
  # def index
  #   if current_user
  #     @users = User.all
  #   else
  #     redirect_to '/users/password'
  #   end
  # end

  # def password
  #   if session[:password_error]
  #     @password_error = true
  #     print "******PASSWORD ERROR!!!!!*******"
  #   end
  # end

  def preloader
    
  end

  def index
    @intro = true
    
  end

  def intro
  end

  def landing
  end

  # def login
  #   target_user = User.find_by_mail(user_params[:mail])
  #   if target_user && target_user.authenticate(user_params[:password])
  #     print "***Succes***"*500
  #     session[:user_id] = target_user[:id]
  #     redirect_to '/'
  #   else
  #     redirect_to '/users/password'
  #   end   
  # end

  # GET /users/1
  # GET /users/1.json
  # def show
  # end

  # GET /users/new
  # def new
  #   @user = User.new
  # end

  # GET /users/1/edit
  # def edit
  # end

  # POST /users
  # POST /users.json
  # def create
  #   @user = User.new(user_params)

  #   respond_to do |format|
  #     if @user.save
  #       format.html { redirect_to @user, notice: 'User was successfully created.' }
  #       format.json { render :show, status: :created, location: @user }
  #     else
  #       format.html { render :new }
  #       format.json { render json: @user.errors, status: :unprocessable_entity }
  #     end
  #   end
  # end

  # PATCH/PUT /users/1
  # PATCH/PUT /users/1.json
  # def update
  #   respond_to do |format|
  #     if @user.update(user_params)
  #       format.html { redirect_to @user, notice: 'User was successfully updated.' }
  #       format.json { render :show, status: :ok, location: @user }
  #     else
  #       format.html { render :edit }
  #       format.json { render json: @user.errors, status: :unprocessable_entity }
  #     end
  #   end
  # end

  # DELETE /users/1
  # DELETE /users/1.json
  # def destroy
  #   @user.destroy
  #   respond_to do |format|
  #     format.html { redirect_to users_url, notice: 'User was successfully destroyed.' }
  #     format.json { head :no_content }
  #   end
  # end

  private
    # Use callbacks to share common setup or constraints between actions.
    # def set_user
    #   @user = User.find(params[:id])
    # end

    # Only allow a list of trusted parameters through.
    def user_params
      params.require(:user).permit(:mail, :password)
    end
end
