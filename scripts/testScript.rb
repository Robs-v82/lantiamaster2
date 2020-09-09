print "hello world"
require 'csv'
table = CSV.parse(File.read("medios(2020-07-22).csv"))
print table[0]
