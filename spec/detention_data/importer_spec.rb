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
        CSV.read(cleaned_csv_path, { headers: true }) do
          clean_csv_data.length.should == 10
        end
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
        it{ should === 'media' }
      end

      context "with an incident type with aggressive behaviour in it" do
        let!(:original_row){ {'Type' => ' Abusive/Aggressive Behaviour' } }
        subject{ DetentionData::Importer.clean_row(original_row)['incident_category'] }
        it{ should === 'assault' }
      end

      context "with an incident type with property in it" do
        let!(:original_row){ {'Type' => 'Property - Missing' } }
        subject{ DetentionData::Importer.clean_row(original_row)['incident_category'] }
        it{ should === 'damage' }
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

    describe "['occured_on']" do

      context "with an australian formatted date" do
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

  end
end
