#!/usr/bin/env ruby

BIN_IRB_TOOLS = ["rtags.rb"]
LIB_IRB_TOOLS = ["frame.rb", "xmp.rb", "completion.rb"]

require "rbconfig.rb"
include Config

destdir = ARGV[0] || ''

version = "/"+CONFIG["MAJOR"]+"."+CONFIG["MINOR"]
bindir = destdir+CONFIG["bindir"]
rubylibdir = destdir+CONFIG["prefix"]+"/lib/ruby"+version
irblibdir = rubylibdir + "/irb"

$:.unshift CONFIG["srcdir"]+"/lib"

require "ftools"

for f in BIN_IRB_TOOLS
  File.install f, "#{bindir}/#{File.basename(f, '.rb')}", 0755, true
end


for f in LIB_IRB_TOOLS
  File.install f, irblibdir, 0644, true
end


