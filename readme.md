Detention Data
---------------

Gem for importing detention incidents data. It adds the following columns to
the data:

* `incident_type`: cleaned version of `Type`
* `location`: cleaned version of `Location`
* `incident_category`: high level groupings of `incident_type`
* `offshore`: true if the facility is offshore
* `occurred_on`: clean version of `Occurred On`
* `facility_type`: facility type i.e. IDC, ITA, APOD, other.
* `misreported_self_harm`: self-harm was mentioned in the description but the
  `Type` was not `self-harm`. This is not definitive. Often there are multiple
  incident reports surround the actual incident.
* `incident_references`: any other incidents mentioned in the text
* `contraband_category`: groupings for contraband
* `interest`: attempt to identify interesting events vs minor incidents

Install by putting the following in your Gemfile:

`gem 'detention_data', :git => 'https://YOUR_ACCOUNT@github.com/TheGlobalMail/detention_data.git'`
