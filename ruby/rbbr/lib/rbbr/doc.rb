=begin

  rbbr/doc.rb - Document Referring

  $Author$
  $Date$

  Copyright (C) 2001 Hiroshi Igarashi <iga@ruby-lang.org>

  This program is free software.
  You can distribute/modify this program under
  the terms of the Ruby Distribute License.

=end

require 'rbbr/plugin'

module RBBR
  module Doc

    class LookupError < StandardError; end

    class Database

      def initialize
      end

      def lookup_module( modul )
=begin
module:Module
(retval):String
=end
	raise
      end

      def lookup_const( const )
=begin
const:Symbol
(retval):String
=end
	raise
      end

      def lookup_method( method )
=begin
method:Method
(retval):String
=end
	raise
      end

    end      


    class MultiDatabase < Database

      FeatureList = [
        'rbbr/doc/source',
	'rbbr/doc/refe',
	'rbbr/doc/ri',
	'rbbr/doc/rubyapi',
	'rbbr/doc/gtkdoc',
      ]

      DatabaseList = []

      def initialize
	@children = []
	FeatureList.each do |feature|
	  begin
	    Kernel.require( feature )
	    STDERR.puts("found database: #{feature}") if $DEBUG
	  rescue LoadError
	  end
	end

	DatabaseList.each do |klass|
	  begin
	    database = klass.new
	    @children << database
	    STDERR.puts("found database class: #{klass}") if $DEBUG
	  rescue
	    # ignore
	  end
	end
      end

      
      def lookup_module( modul )
	raise
      end

      def lookup_const( const )
	raise
      end

      def lookup_method( method )
	@children.each do |db|
	  begin
	    return db.lookup_method( method )
	  rescue LookupError
	    # ignore
	  end
	end
	raise LookupError
      end

      def find_instance_of ( dbClass )
        @children.each do |dbInstance|
          return dbInstance if dbInstance.kind_of? dbClass
        end
        nil
      end
      
    end


    class CacheDatabase < Database
    end

  end
end
