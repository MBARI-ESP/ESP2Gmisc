#!/usr/bin/env ruby

require "rbconfig.rb"
include Config

destdir = ARGV[0] || ''

bindir = destdir+CONFIG["bindir"]
rubylibdir = destdir+CONFIG["rubylibdir"]

$:.unshift CONFIG["srcdir"]+"/lib"

require "ftools"
require "find"

File.install "bin/irb.rb", "#{bindir}/irb", 0755, true

Find.find("lib") do |f|
  next if f.include?('/CVS/') or File.directory?(f)
  dir = rubylibdir+"/"+File.dirname(f[4..-1])
  File.makedirs dir, true unless File.directory? dir
  File.install f, dir, 0644, true
end


