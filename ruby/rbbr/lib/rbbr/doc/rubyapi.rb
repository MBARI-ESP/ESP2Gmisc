=begin

  rbbr/doc/rubyapi.rb - Document Referring with rubyapi

  $Author$
  $Date$

  Copyright (C) 2002 Ruby-GNOME2 Project

  Copyright (C) 2001 Hiroshi Igarashi <iga@ruby-lang.org>

  This program is free software.
  You can distribute/modify this program under
  the terms of the Ruby Distribute License.

=end

require 'rbbr/doc'
require 'rbbr/config'
require 'gdbm'

module RBBR
  module Doc

    class RubyAPI < Database

      def initialize
	super()

	@db = GDBM.open(File.join(RBBR::Config::DATA_DIR, "rubyapi.db"))
      end

      def lookup_module( modul )
	begin
#	  @db.class_document( modul )
	  raise LookupError, "module/class is not supported"
#	rescue ::SearchError
#	  raise LookupError, $!.message
	end
      end

      def lookup_const( const )
	raise LookupError, "constant is not supported"
      end
      
      def lookup_method( method )
	begin
	  result = @db[ method ]
	  if result.nil?
	    raise LookupError, "document not found"
	  else
	    result
	  end
#	rescue ::SearchError
#	  raise LookupError, $!.message
	end
      end

      MultiDatabase::DatabaseList << self

    end

  end
end
