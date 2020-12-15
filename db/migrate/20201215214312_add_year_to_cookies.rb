class AddYearToCookies < ActiveRecord::Migration[6.0]
  def change
    add_reference :cookies, :year, foreign_key: true
  end
end
