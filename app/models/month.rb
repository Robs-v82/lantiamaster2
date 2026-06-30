class Month < ApplicationRecord
	belongs_to :quarter
	has_many :events
	has_many :sources, :through => :events 
	has_many :killings, :through => :events 
	has_many :detentions, :through => :events 
	has_many :victims, :through => :killings 
	has_many :detainees, :through => :detentions 
	has_many :leads, :through => :events 

	has_one_attached :violence_report
	has_one_attached :social_report
	has_one_attached :forecast_report
	has_one_attached :crime_victim_report
	has_one_attached :car_theft_report

	scope :with_violence_report, -> {
		joins("INNER JOIN active_storage_attachments ON active_storage_attachments.record_id = months.id AND active_storage_attachments.record_type = 'Month' AND active_storage_attachments.name = 'violence_report'").distinct
	}
	scope :with_social_report, -> {
		joins("INNER JOIN active_storage_attachments ON active_storage_attachments.record_id = months.id AND active_storage_attachments.record_type = 'Month' AND active_storage_attachments.name = 'social_report'").distinct
	}
	scope :with_forecast_report, -> {
		joins("INNER JOIN active_storage_attachments ON active_storage_attachments.record_id = months.id AND active_storage_attachments.record_type = 'Month' AND active_storage_attachments.name = 'forecast_report'").distinct
	}
end
