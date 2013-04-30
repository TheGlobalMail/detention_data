#!/usr/bin/env ruby
$:.unshift(File.expand_path('../../lib', __FILE__))
require 'optparse'
require 'detention_data'

if $*.length != 2
  puts "Usage: import.rb input.csv output.json"
  exit(1)
end

DetentionData::Importer.cleanJS(*$*)
