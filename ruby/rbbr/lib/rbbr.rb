=begin

  rbbr.rb - Ruby Meta-Level Information Browser

  $Author$
  $Date$

  Copyright (C) 2000-2001 Hiroshi Igarashi <iga@ruby-lang.org>

  This program is free software.
  You can distribute/modify this program under
  the terms of the Ruby Distribute License.

=end

module RBBR
  VERSION = "0.2rev1"
  def self.main
    require 'rbbr/ui'
    ui = RBBR::UI.default
    ui.main
  end
end

if $0 == __FILE__
  RBBR.main
end
