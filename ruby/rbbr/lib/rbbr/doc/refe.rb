=begin

  rbbr/doc/refe.rb - Document Referring with ReFe

  $Author$
  $Date$

  Copyright (C) 2002 Ruby-GNOME2 Project

  Copyright (C) 2001 Hiroshi Igarashi <iga@ruby-lang.org>

  This program is free software.
  You can distribute/modify this program under
  the terms of the Ruby Distribute License.

=end

require 'rbbr/doc'
require 'refe/database'

module RBBR
  module Doc

    class ReFe < Database
=begin
Currently, This adopter require ReFe 0.4.2 or later.
=end

      def initialize
	super()
	@db = ::ReFe::Database.new( ::ReFe.database_dir(nil), true, false )
      end

      def lookup_module( modul )
	begin
#	  @db.class_document( modul )
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
	  @db.method_document( method )
	rescue ::ReFe::SearchError
	  raise LookupError, $!.message
	end
      end

      MultiDatabase::DatabaseList << self

    end

  end
end
