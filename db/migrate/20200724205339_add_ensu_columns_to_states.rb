class AddEnsuColumnsToStates < ActiveRecord::Migration[6.0]
  def change
  	add_column :states, :ensu_bp_1_1_2015_Q1, :float
  	add_column :states, :ensu_bp_1_1_2015_Q2, :float
  	add_column :states, :ensu_bp_1_1_2015_Q3, :float
  	add_column :states, :ensu_bp_1_1_2015_Q4, :float
  	add_column :states, :ensu_bp_1_1_2016_Q1, :float
  	add_column :states, :ensu_bp_1_1_2016_Q2, :float
  	add_column :states, :ensu_bp_1_1_2016_Q3, :float
  	add_column :states, :ensu_bp_1_1_2016_Q4, :float
  	add_column :states, :ensu_bp_1_1_2017_Q1, :float
  	add_column :states, :ensu_bp_1_1_2017_Q2, :float
  	add_column :states, :ensu_bp_1_1_2017_Q3, :float
  	add_column :states, :ensu_bp_1_1_2017_Q4, :float
  	add_column :states, :ensu_bp_1_1_2018_Q1, :float
  	add_column :states, :ensu_bp_1_1_2018_Q2, :float
  	add_column :states, :ensu_bp_1_1_2018_Q3, :float
  	add_column :states, :ensu_bp_1_1_2018_Q4, :float
  	add_column :states, :ensu_bp_1_1_2019_Q1, :float
  	add_column :states, :ensu_bp_1_1_2019_Q2, :float
  	add_column :states, :ensu_bp_1_1_2019_Q3, :float
  	add_column :states, :ensu_bp_1_1_2019_Q4, :float
  	add_column :states, :ensu_bp_1_1_2020_Q1, :float
  	add_column :states, :ensu_bp_1_1_2020_Q2, :float
  	add_column :states, :ensu_bp_1_1_2020_Q3, :float
  	add_column :states, :ensu_bp_1_1_2020_Q4, :float
  end
end