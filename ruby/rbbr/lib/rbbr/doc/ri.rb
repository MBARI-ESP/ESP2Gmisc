=begin

  rbbr/doc/ri.rb - Document Referring with ri

  $Author$
  $Date$

  Copyright (C) 2002 Ruby-GNOME2 Project

  Copyright (C) 2001 Hiroshi Igarashi <iga@ruby-lang.org>

  This program is free software.
  You can distribute/modify this program under
  the terms of the Ruby Distribute License.

=end

require 'rbbr/doc'

module RBBR
  module Doc

    class RI < Database

      def initialize
	super()
      end

      def lookup_module( modul )
	begin
	  raise LookupError, "module/class is not supported"
	rescue ::ReFe::SearchError
	  raise LookupError, $!.message
	end
      end

      def lookup_const( const )
	raise LookupError, "constant is not supported"
      end
      
      def lookup_method( method )
	begin
	  result = `ri "#{method}"`
	  if /(?:Cannot|Couldn't) find/ === result
	    raise LookupError
	  else
	    result
	  end
	rescue
	  raise LookupError, $!.message
	end
      end

      MultiDatabase::DatabaseList << self

    end

  end
end
