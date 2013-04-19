#!/usr/bin/env ruby
require 'mechanize'

if $*.length != 1
  puts "Usage: summary_docs_from_pandora.rb output_directory"
  exit(1)
end
output = $*[0]

agent = Mechanize.new
agent.pluggable_parser.default = Mechanize::Download

url = "http://trove.nla.gov.au/website/result?q-field0&q-type0=all&q-term0=immigration-detention-statistics&q-field1&q-type1=all&q-term1=pdf&q-field2=subject%3A&q-type2=all&q-term2&q-field3&q-type3=all&q-term3&q-year1-year&q-year2-year&q=+%28immigration-detention-statistics%29+%28pdf%29&l-urlKeyDomain=115165"

links = []

[0, 20, 40, 60].each do |index|
  page = agent.get("#{url}&s=#{index}")
  page.links_with(href: /.pdf$/i).each do |link|
    puts link.href
    file_name = link.href.match(/-(\d+\.pdf)/i)[1]
    agent.get(link.href).save(output + '/' + file_name)
  end
end

puts "got links #{links.sort.inspect}"
