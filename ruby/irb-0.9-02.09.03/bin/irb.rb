#!/usr/bin/env ruby
#
#   irb.rb - intaractive ruby
#   	$Release Version: 0.9 $
#   	$Revision$
#   	$Date$
#   	by Keiju ISHITSUKA(keiju@ishitsuka.com)
#

require "irb"

if __FILE__ == $0
  IRB.start(__FILE__)
else
  # check -e option
#  tmp = ENV["TMP"] || ENV["TMPDIR"] || "/tmp"
#  if %r|#{tmp}/rb| =~ $0
  if /^-e$/ =~ $0
    IRB.start(__FILE__)
  else
    IRB.initialize(__FILE__)
  end
end
