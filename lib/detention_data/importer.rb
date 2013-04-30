require 'csv'
require 'tempfile'
require 'json'

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
    input.close
    output.close
  end

  def self.cleanJSON(csv_path, cleaned_json_path)
    output = File.open cleaned_json_path, 'w'
    Tempfile.open('cleaned_csv') do |f|
      cleanCSV(csv_path, f.path)
      incidents = {}
      csv_data = CSV.read(f.path, {headers: true})
      csv_data = csv_data.map{|row|
        data = row.to_hash
        data['offshore'] = data['offshore'] == 'true'
        data['misreported_self_harm'] = data['add_misreported_self_harm'] == 'true'
        data['occurred_on'] = Date.parse(data['occurred_on'])
        data['month'] = Date.new(data['occurred_on'].year, data['occurred_on'].month, 1)
        # also create incidents hash
        incidents[data['Incident Number']] = data
        data
      }
      jsonData = { data: incidents }
      jsonData[:months] = extract_months(csv_data)
      output.write(JSON.pretty_generate(jsonData))
    end
    output.close
  end

  def self.cleanJS(csv_path, cleaned_js_path)
    output = File.open cleaned_js_path, 'w'
    Tempfile.open('cleaned_json') do |f|
      cleanJSON(csv_path, f.path)
      json = IO.read(f.path)
      output.write('define(' + json + ');')
    end
    output.close
  end

  def self.clean_row(row)
    row['Incident Number'] = remove_null(row['Incident Number'])
    row['incident_type'] = clean_incident_type(row['Type'])
    row['location'] = remove_null(clean_location(row['Location']))
    row['incident_category'] = add_incident_category(row['incident_type'])
    row['offshore'] = add_offshore(row['location'])
    row['occurred_on'] = add_occurrend_on(row['Occurred On'])
    row['facility_type'] = add_facility_type(row['location'])
    row['misreported_self_harm'] = add_misreported_self_harm(row)
    row['incident_references'] = add_incident_references(row)
    row['contraband_category'] = add_contraband_category(row)
    row['interest'] = add_interest(row)
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
      'occurred_on', 'facility_type', 'misreported_self_harm',
      'incident_references', 'contraband_category', 'interest'
    ]
  end

  def self.clean_location(value)
    if value =~ /christmas island/i
      value = 'north west point immigration facility'
    end
    if value =~ /Minor Client/i
      value = 'berrimah accommodation facility'
    end
    if value =~ /\wIDC/
      value.gsub!(/IDC/, ' IDC')
    end
    value && value.downcase.strip
      .gsub(/\s+/, ' ').gsub(/\d+\/\d+\/\d+ +/, '')
  end

  def self.remove_null(value)
    return value && value.gsub(/ *null/i, '')
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
      {name: 'media or protest', re: /media|threat-bomb|demonstration - offsite/},
      {name: 'violence', re: /assault|aggressive behaviour|weapon|use of force|use of restraint/},
      {name: 'disturbance or damage', re: /disturbance|notification by welfare|damage|property|theft|contraband/},
      {name: 'complaint', re: /complaint/},
      {name: 'protest', re: /protest|riot|voluntary starvation|barricade|demonstration - onsite|escape/},
      {name: 'complaint', re: /complaint/},
      {name: 'injury', re: /death|emergency|infection|birth|accident|poisoning|public health risk/},
      {name: 'self-harm', re: /self harm/},
      #{name: 'admin', re: /^transfer |failure|removal - aborted|use of observation|visitor/},
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

  def self.contraband_categories
    [
      {name: 'alcohol', re: /alcohol|fermented|fermenting|wine|jamisons|gin |jack danials|spirit|home brew|vodka|johnnie walker|rotten fruit|hooch/i},
      {name: 'phone-or-camera', re: /phone|camera/i},
      {name: 'pornography', re: / porn/i},
      {name: 'noose', re: /noose/i},
      {name: 'weapon', re: /nail clippers|nail|scissors|Mirror|Knife|sharp|sharps|ceramic cup|screwdriver|pliers|work tools|stapler|razor blades|razor/i},
      #{name: 'noose'}- rope / bed sheet / noose

      #- Syringe / nail clippers / nail / scissors / Mirror / Knife / sharp / sharps / ceramic cup / screwdriver / pliers / work tools / stapler / razor blades / razor 

      #- plant / cannabis

      #- aerosol / breath spray

      #- medication / pill / cough mixture / tablets / bong

      #- pool que / pool cue / metal vacuum cleaner pipe

      #- tools of escape / step ladder
    ]
  end

  def self.add_contraband_category(row)
    contraband_category = contraband_categories.detect{|type|
      row['Summary'] && row['Summary'] =~ type[:re]
    }
    contraband_category ? contraband_category[:name]: 'other'
  end

  def self.add_interest(row)
    row['incident_type'] && row['incident_type'] !~ /-minor|transfer|use of ob|failure/mi
  end

  def self.extract_months(data)
    months = {}
    data.each do |incident|
      month = incident['month']
      months[month] ||= { month: month, incidents: [] }
      months[month][:incidents] << incident['Incident Number']
    end
    # return as sorted list by month
    months.values.sort_by{|m| m[:month] }
  end

end
