$:.unshift(File.expand_path('../../../lib', __FILE__))

require 'spec_helper'
require 'csv'
require 'detention_data'

describe DetentionData::Importer do

  describe ".cleanCSV" do

    context  "with a path to a csv file and an output file" do

      let(:csv_path){  File.expand_path('../../fixtures/test.csv', __FILE__) }
      let(:cleaned_csv_path){  File.expand_path('../../fixtures/test_output.csv', __FILE__) }
      before{ DetentionData::Importer.cleanCSV(csv_path, cleaned_csv_path) }

      it "should put the cleaned data in the output file" do
        clean_csv_data = CSV.read(cleaned_csv_path, { headers: true })
        clean_csv_data.length.should == 10
      end
    end
  end

  describe ".cleanJSON" do

    context  "with a path to a csv file and an output file" do

      let(:csv_path){  File.expand_path('../../fixtures/test.csv', __FILE__) }
      let(:cleaned_json_path){  File.expand_path('../../fixtures/test_output.json', __FILE__) }
      before{ DetentionData::Importer.cleanJSON(csv_path, cleaned_json_path) }

      it "should put the cleaned data in the output file" do
        json = JSON.parse(IO.read(cleaned_json_path))
        incidents = json['data']
        incidents.length.should == 10
        incidents.should have_key('1-2PQQH5')
        incidents['1-2PQQH5']['misreported_self_harm'].should be_false 
        incidents['1-2RG4E3']['offshore'].should be_true 
        months = json['months']
        months.first['month'].should == '2009-01-01'
        months.first['incidents'].sort.should == ["1-2PDPSN", "1-2PDPVF", "1-2PK97X"]
      end
    end
  end

  describe ".cleanJS" do

    context  "with a path to a csv file and an output file" do

      let(:csv_path){  File.expand_path('../../fixtures/test.csv', __FILE__) }
      let(:cleaned_js_path){  File.expand_path('../../fixtures/test_output.js', __FILE__) }
      before{ DetentionData::Importer.cleanJS(csv_path, cleaned_js_path) }

      it "should put the cleaned data in the output file" do
        js = IO.read(cleaned_js_path)
        js.should =~ /define\(\{/
      end
    end
  end

  describe ".clean_row" do

    describe "['location']" do

      context "with a location with spaces" do

        let!(:original_row){ {'Location' => '  some where  ' } }
        subject{ DetentionData::Importer.clean_row(original_row)['location'] }
        it{ should === 'some where' }
      end

      context "with a date accidently put in there" do

        let!(:original_row){ {'Location' => '21/02/2010  some where  ' } }
        subject{ DetentionData::Importer.clean_row(original_row)['location'] }
        it{ should === 'some where' }
      end
      
      context "with a location with 'null' in it" do

        let!(:original_row){ {'Location' => '  some wherenull' } }
        subject{ DetentionData::Importer.clean_row(original_row)['location'] }
        it{ should === 'some where' }
      end

      context "with a location missing a space before IDC" do

        let!(:original_row){ {'Location' => 'MaribyrnongIDC' } }
        subject{ DetentionData::Importer.clean_row(original_row)['location'] }
        it{ should === 'maribyrnong idc' }
      end

      context "with excess spaces between words" do

        let!(:original_row){ {'Location' => 'Maribyrnong   IDC' } }
        subject{ DetentionData::Importer.clean_row(original_row)['location'] }
        it{ should === 'maribyrnong idc' }
      end

      context "with the location 'Christmas Island'" do

        let!(:original_row){ {'Location' => ' Christmas Island ' } }
        subject{ DetentionData::Importer.clean_row(original_row)['location'] }
        it{ should === 'north west point immigration facility' }
      end
    end

    describe "['incident_type']" do

      context "with a incident type with mixed case and spaces" do

        let!(:original_row){ {'Type' => '  Some Incident  ' } }
        subject{ DetentionData::Importer.clean_row(original_row)['incident_type'] }
        it{ should === 'some incident' }
      end
    end

    describe "['incident_category']" do

      context "with an incident type with media in it" do
        let!(:original_row){ {'Type' => ' Media - Approach staff/clients  ' } }
        subject{ DetentionData::Importer.clean_row(original_row)['incident_category'] }
        it{ should === 'media or protest' }
      end

      context "with an incident type with aggressive behaviour in it" do
        let!(:original_row){ {'Type' => ' Abusive/Aggressive Behaviour' } }
        subject{ DetentionData::Importer.clean_row(original_row)['incident_category'] }
        it{ should === 'violence' }
      end

      context "with an incident type with property in it" do
        let!(:original_row){ {'Type' => 'Property - Missing' } }
        subject{ DetentionData::Importer.clean_row(original_row)['incident_category'] }
        it{ should === 'disturbance or damage' }
      end

      context "with an incident type with demonstration - onsite" do
        let!(:original_row){ {'Type' => 'Demonstration - onsite' } }
        subject{ DetentionData::Importer.clean_row(original_row)['incident_category'] }
        it{ should === 'protest' }
      end
    end

    describe "['offshore']" do

      context "with a Location in an offshore location" do
        let!(:original_row){ {'Location' => 'Christmas Island' } }
        subject{ DetentionData::Importer.clean_row(original_row)['offshore'] }
        it{ should be_true }
      end

      context "with a Location in an onshore location" do
        let!(:original_row){ {'Location' => 'Brisbane ITA' } }
        subject{ DetentionData::Importer.clean_row(original_row)['offshore'] }
        it{ should be_false }
      end

    end

    describe "['Incident Number']" do

      context "with a null in the id" do
        let!(:original_row){ {'Incident Number' => '1-79RZQA  null' } }
        subject{ DetentionData::Importer.clean_row(original_row)['Incident Number'] }
        it{ should == '1-79RZQA' }
      end
    end

    describe "['occured_on']" do

      context "with an YYYY-MM-DD formatted date" do
        let!(:original_row){ {'Occurred On' => '2012-03-09' } }
        subject{ DetentionData::Importer.clean_row(original_row)['occurred_on'] }
        it{ should == Date.new(2012, 3, 9) }
      end
    end

    describe "['facility_type']" do

      context "with IDC in location" do
        let!(:original_row){ {'Location' => 'Perth IDC' } }
        subject{ DetentionData::Importer.clean_row(original_row)['facility_type'] }
        it{ should == 'idc' }
      end

      context "with a known IDC location" do
        let!(:original_row){ {'Location' => 'Christmas Island' } }
        subject{ DetentionData::Importer.clean_row(original_row)['facility_type'] }
        it{ should == 'idc' }
      end

      context "with IRH in location" do
        let!(:original_row){ {'Location' => 'Perth IRH' } }
        subject{ DetentionData::Importer.clean_row(original_row)['facility_type'] }
        it{ should == 'irh' }
      end

      context "with APOD in location" do
        let!(:original_row){ {'Location' => 'Leonora APOD' } }
        subject{ DetentionData::Importer.clean_row(original_row)['facility_type'] }
        it{ should == 'apod' }
      end

      context "with a known APOD location" do
        let!(:original_row){ {'Location' => 'Lilac Aqua' } }
        subject{ DetentionData::Importer.clean_row(original_row)['facility_type'] }
        it{ should == 'apod' }
      end

      context "with ITA in location" do
        let!(:original_row){ {'Location' => 'Melbourne ITA' } }
        subject{ DetentionData::Importer.clean_row(original_row)['facility_type'] }
        it{ should == 'ita' }
      end

      context "not matching any known facility type" do
        let!(:original_row){ {'Location' => 'Virginia Palms Motel' } }
        subject{ DetentionData::Importer.clean_row(original_row)['facility_type'] }
        it{ should == 'other' }
      end
    end

    describe "['misreported_self_harm']" do

      context "with any text saying self harm but not reported as self-harm" do

        let!(:original_row){ {'Location' => '  self harm  ' } }
        subject{ DetentionData::Importer.clean_row(original_row)['misreported_self_harm'] }
        it{ should be_true  }
      end
    end

    describe "['incident_references']" do

      context "with any reference to incident ids that are not the current incident id" do

        let!(:original_row){ {'Incident Number' => '1-2PQQH5', 
          'Location Details' => 'Refers to 1-2RX4AZ. Not a reference no: 1-7 and 1-2342342423432',
          'Summary' => 'Refers to 1-2RG4EW.1-2RG4EW. 16-01-2011' } }
        subject{ DetentionData::Importer.clean_row(original_row)['incident_references'] }
        it{ should == '1-2RX4AZ,1-2RG4EW'  }
      end
    end

    describe "['contraband_category']" do

      context "with an alcohol reference in the Summary" do
        let!(:original_row){ {'Summary' => 'made me some hooch' } }
        subject{ DetentionData::Importer.clean_row(original_row)['contraband_category'] }
        it{ should == 'alcohol' }
      end
    end

    describe "['interest']" do

      ['disturbance-minor', 'assualt-minor', 'damage-minor', 'transfer to apod', 
        'use of observation rm > 24 hrs', 'failure - it systems'].each do |incident_type|

        context "with the less interesting category e.g. #{incident_type}" do
          let!(:original_row){ { 'Type' => incident_type } }
          subject{ DetentionData::Importer.clean_row(original_row)['interest'] }
          it{ should be_false }
        end
      end

      ['self-harm'].each do |incident_type|

        context "with an interesting category e.g. #{incident_type}" do
          let!(:original_row){ { 'Type' => incident_type } }
          subject{ DetentionData::Importer.clean_row(original_row)['interest'] }
          it{ should be_true }
        end
      end
    end
  end
end
