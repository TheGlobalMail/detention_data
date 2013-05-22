require 'csv'
require 'tempfile'
require 'json'
require 'open-uri'

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

  def self.cleanJSON(csv_path, events_path, cleaned_json_path)
    output = File.open cleaned_json_path, 'w'
    Tempfile.open('cleaned_csv') do |f|
      cleanCSV(csv_path, f.path)
      incidents = extract_interesting_incidents(CSV.read(f.path, {headers: true}))
      incidents = updateWithDetentionLogsData(incidents)
      events = extract_events(CSV.read(events_path, {headers: true}))
      all_incidents = incidents + events
      jsonData = {
        data: hash_by_id(all_incidents),
        months: extract_months(all_incidents)
      }
      output.write(JSON.pretty_generate(jsonData))
    end
    output.close
  end

  def self.cleanJS(csv_path, events_path, cleaned_js_path)
    output = File.open cleaned_js_path, 'w'
    Tempfile.open('cleaned_json') do |f|
      cleanJSON(csv_path, events_path, f.path)
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
    summary = row['Summary'] || '';
    row['words_in_summary'] = summary.split(/\s/).length;
    row['characters_in_summary'] = summary.length;
    row
  end

  protected

  def self.downloadDetentionLogsData()
    api = ENV['DETENTION_LOGS_API']
    raise "No uri for api" unless api
    JSON.parse(open(api).read)
  end

  def self.updateWithDetentionLogsData(incidents)
    dententionLogsData = downloadDetentionLogsData
    incidents.each do |incident|
      dLIncident = dententionLogsData.detect{|dl| dl['incident_number'] == incident['id']} 
      if dLIncident
        incident['detailed_report'] = !!dLIncident['detailed_report_file_name']
        # get more accurate date
        incident['occurred_on'] = Time.parse(dLIncident['occured_on'])
      else
        incident['occurred_on'] = Date.parse(incident['occurred_on']).to_time
      end
    end
    incidents
  end

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
    return value && value.gsub(/ *null/i, '').gsub(/--/, '-');
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
    row['incident_type'] &&
    row['incident_type'] !~ /-minor|- minor|transfer|use of ob|failure|^media|complaint|injury - serious/mi &&
    !(row['incident_type'] =~ /aggressive behaviour/ && row['Level'] == 'Minor')
  end

  def self.extract_months(data)
    month_lookup = {}
    data.each do |incident|
      incident['month'] = Date.new(incident['occurred_on'].year, incident['occurred_on'].month, 1)
      month = incident['month']
      month_lookup[month] ||= { month: month, incidents: [] }
      month_lookup[month][:incidents] << incident
    end
    # return as sorted list by month
    months = month_lookup.values.sort_by{|m| m[:month] }
    # sort the incidents within each month by date and only return the id
    months.each do |month|
      month[:incidents] = month[:incidents]
        .sort_by{|incident|
          incident['occurred_on'].to_time
        }.map{|incident| 
          incident['id']
        }
    end
    months
  end

  def self.extract_interesting_incidents(csv_data)
    csv_data.map{|row|
      reduced_data = {}
      data = row.to_hash
      reduced_data['id'] = data['Incident Number']
      reduced_data['event_type'] = 'incident'
      reduced_data['incident_type'] = data['incident_type']
      reduced_data['Level'] = data['Level']
      reduced_data['Summary'] = data['Summary']
      reduced_data['location'] = data['location']
      reduced_data['incident_category'] = data['incident_category']
      reduced_data['occurred_on'] = data['occurred_on']
      reduced_data
    }.select{|incident|
      true #incident['interest']
    }
  end

  # Convert the csv row to an array of hashes
  def self.extract_events(csv_data)
    csv_data.map{|row|
      event = row.to_hash
      if (event['occurred_on'] =~ /\d+\/\d+\/\d+ \d+:\d+/)
        event['occurred_on'] = Time.strptime(event['occurred_on'], '%d/%m/%y %H:%M')
      else
        event['occurred_on'] = Date.strptime(event['occurred_on'], '%d/%m/%y')
      end
      event['event_type'] = 'event'
      event
    }
  end
  
  def self.hash_by_id(incidents)
    hash = {}
    incidents.each do |incident|
      hash[incident['id']] = incident
    end
    hash
  end

end
