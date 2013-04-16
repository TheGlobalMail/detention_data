require 'csv'

module DetentionData::Importer

  def self.cleanCSV(csv_path, cleaned_csv_path)
    options = { headers: true, write_headers: true, return_headers: true }
    input = File.open csv_path, 'r'
    output = File.open cleaned_csv_path, 'w'
    CSV.filter input, output, options do |row|
      if row.header_row?()
        add_new_headers(row)
      else
        row = clean_row(row)
      end
    end
  end

  def self.clean_row(row)
    row['incident_type'] = clean_incident_type(row['Type'])
    row['location'] = clean_location(row['Location'])
    row['incident_category'] = add_incident_category(row['incident_type'])
    row['offshore'] = add_offshore(row['location'])
    row['occurred_on'] = add_occurrend_on(row['Occurred On'])
    row['facility_type'] = add_facility_type(row['location'])
    row['misreported_self_harm'] = add_misreported_self_harm(row)
    row['incident_references'] = add_incident_references(row)
    row
  end

  protected

  def self.add_new_headers(row)
    new_headers.each do |header|
      row[header] = header
    end
  end

  def self.new_headers()
    ['incident_type', 'location', 'incident_category', 'offshore',
      'occurred_on', 'facility_type', 'misreported_self_harm']
  end

  def self.clean_location(value)
    if value =~ /Berrimah Accommodation Facility Minor Client/
      value = 'berrimah accommodation facility'
    end
    if value =~ /\wIDC/
      value.gsub!(/IDC/, ' IDC')
    end
    value && value.downcase.strip.gsub(/\s+/, ' ')
  end

  def self.clean_incident_type(value)
    if value == 'Use of Obs Room >24 hours'
      value = 'use of observation rm > 24 hrs'
    end
    value && value.downcase.strip
  end

  def self.add_incident_category(incident_type)
    category = categories.detect{|cat|
      incident_type && incident_type =~ cat[:re]
    }
    category ? category[:name]: 'other'
  end

  def self.categories
    [
      {name: 'media', re: /media/},
      {name: 'assault', re: /assault|aggressive behaviour|weapon/},
      {name: 'disturbance', re: /disturbance|notification by welfare/},
      {name: 'complaint', re: /complaint/},
      {name: 'contraband', re: /contraband/},
      {name: 'damage', re: /damage|property|theft/},
      {name: 'external-protest', re: /threat-bomb|demonstration - offsite/},
      {name: 'protest', re: /protest|riot|voluntary starvation|barricade|demonstration - onsite/},
      {name: 'force', re: /use of force|use of restraint/},
      {name: 'escape', re: /escape/},
      {name: 'complaint', re: /complaint/},
      {name: 'injury', re: /death|emergency|infection|birth|accident|poisoning|public health risk/},
      {name: 'self-harm', re: /self harm/},
      {name: 'admin', re: /^transfer |failure|removal - aborted|use of observation|visitor/},
    ]
  end

  def self.add_offshore(location)
    !!(
      location =~ /christmas|phosphate|nauru|manus|aqua|lilac|construction camp|north west point/i
    )
  end

  def self.add_occurrend_on(date)
    date && Date.parse(date)
  end

  def self.add_facility_type(location)
    facility_type = facility_types.detect{|type|
      location && location =~ type[:re]
    }
    facility_type ? facility_type[:name]: 'other'
  end

  def self.facility_types
    [
      {name: 'idc', re: /christmas| idc|north|sa detention|berrimah/},
      {name: 'irh', re: / irh/},
      {name: 'apod', re: / apod|phosphate|aqua|lilac/},
      {name: 'ita', re: / ita/},
    ]
  end

  def self.add_misreported_self_harm(row)
    !!(
      ['location', 'Location Details', 'Summary'].detect{|col|
        row[col] =~ /self[- ]harm|harm himself|harm herself|harm themsel/i
      } && row['incident_category'] != 'self-harm'
    ) 
  end

  def self.add_incident_references(row)
    references = []
    id = row['Incident Number'] && row['Incident Number'].strip
    return unless id
    ['location', 'Location Details', 'Summary'].each do |col|
      next unless row[col]
      row[col].scan(/1-[\w]{5,}/).each do |reference|
        if reference != id && reference.length < 9
          references << reference
        end
      end
    end
    references.uniq.join(',')
  end

end
