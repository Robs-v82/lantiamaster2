class StatesController < ApplicationController
  before_action :set_state, only: [:show, :edit, :update, :destroy]

  # GET /states
  # GET /states.json
  
  def api
    myHash = {}

    myYear = Year.where(:name=>"2020")
    myPeriod = helpers.get_specific_months(myYear, "victims").last
    myHash[:update] = myPeriod.first_day
    
    topKillings = myPeriod.killings
    topKillings = topKillings.sort_by{|k| -k.killed_count}
    myHash[:killings] = topKillings[0,5]


    
    stateArr = []
    State.all.each{|state|
      stateHash = {}
      stateHash[:code] = state.code
      stateHash[:name] = state.name
      stateHash[:shortname] = state.shortname
      stateHash[:victims] = myPeriod.victims.merge(state.victims).length 
      stateArr.push(stateHash)
    }
        myHash[:states] = stateArr
    render json: myHash
  end

  def getStates
    states = State.all
    render json: {states: states}
  end

  def getCities
    cities = City.all.sort_by{|city|city.name}
    render json: {cities: cities}
  end

  def index
    @states = State.all
  end

  # GET /states/1
  # GET /states/1.json
  def show
  end

  # GET /states/new
  def new
    @state = State.new
  end

  # GET /states/1/edit
  def edit
  end

  # POST /states
  # POST /states.json
  def create
    @state = State.new(state_params)

    respond_to do |format|
      if @state.save
        format.html { redirect_to @state, notice: 'State was successfully created.' }
        format.json { render :show, status: :created, location: @state }
      else
        format.html { render :new }
        format.json { render json: @state.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /states/1
  # PATCH/PUT /states/1.json
  def update
    respond_to do |format|
      if @state.update(state_params)
        format.html { redirect_to @state, notice: 'State was successfully updated.' }
        format.json { render :show, status: :ok, location: @state }
      else
        format.html { render :edit }
        format.json { render json: @state.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /states/1
  # DELETE /states/1.json
  def destroy
    @state.destroy
    respond_to do |format|
      format.html { redirect_to states_url, notice: 'State was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_state
      @state = State.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def state_params
      params.require(:state).permit(:name, :shortname, :code, :population)
    end
end
