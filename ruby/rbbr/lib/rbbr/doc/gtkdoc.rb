=begin

  rbbr/doc/gtkdoc.rb - Document Referring with gtkdoc

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

module RBBR
  module Doc

    class GtkDoc < Database

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
	kname, mname = method.split( "#" )

	knames = kname.split( "::" )
	dir = knames[0].downcase
	file = knames.join.downcase + ".sgml"
	nodeid = (knames + [mname]).join("-").upcase
	function = (knames + [mname]).join("_").downcase

	docdir = "gtk-reference"
	dir2 = "tmpl"
	absfile = File.join( RBBR::Config::DATA_DIR, docdir, dir, dir2, file )

	begin
	  buf = ""
	  File.open( File.expand_path( absfile ) ) do |file|
	    while line = file.gets and
		not /##### FUNCTION #{function}/ === line
	    end
	    while line = file.gets and not /#####/ === line
	      buf << line
	    end
	  end
	  if buf.empty?
	    raise LookupError
	  end
	  buf
	rescue
	  raise LookupError
	end
	
      end

      MultiDatabase::DatabaseList << self

    end

  end
end
