=begin

  rbbr/ui.rb - Meta-Level Information Browser User Interface

  $Author$
  $Date$

  Copyright (C) 2002 Ruby-GNOME2 Project

  Copyright (C) 2001 Hiroshi Igarashi <iga@ruby-lang.org>

  This program is free software.
  You can distribute/modify this program under
  the terms of the Ruby Distribute License.

=end

require 'observer'

module RBBR

  module UI

    class Factory

      def initialize
      end

      def create_window
      end

    end

    def self.default
      require 'rbbr/ui/gtk'
      RBBR::UI::GTK
    end

  end

end
