#!/usr/bin/env ruby

BIN_IRB_TOOLS = []
LIB_IRB_TOOLS = ["mbari.rb", "objectspace.rb", "sourceref.rb"]

require "rbconfig.rb"
include Config

destdir = ARGV[0] || ''

bindir = destdir+CONFIG["bindir"]
sitelibdir = destdir+CONFIG["sitelibdir"]

$:.unshift CONFIG["srcdir"]+"/lib"

require "ftools"

for f in BIN_IRB_TOOLS
  File.install f, "#{bindir}/#{File.basename(f, '.rb')}", 0755, true
end


for f in LIB_IRB_TOOLS
  File.install f, sitelibdir, 0644, true
end


