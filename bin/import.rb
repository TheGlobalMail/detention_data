#!/usr/bin/env ruby
$:.unshift(File.expand_path('../../lib', __FILE__))
require 'optparse'
require 'detention_data'

if $*.length != 3
  puts "Usage: import.rb incidents.csv events.csv combined_amd_file.js"
  exit(1)
end

DetentionData::Importer.cleanJS(*$*)
