=begin

  rbbr/ui/gtk.rb - Meta-Level Information Browser User Interface with GTK+

  $Author$
  $Date$

  Copyright (C) 2002 Ruby-GNOME2 Project

  Copyright (C) 2000-2002 Hiroshi Igarashi <iga@ruby-lang.org>

  This program is free software.
  You can distribute/modify this program under
  the terms of the Ruby Distribute License.

=end

require 'observer'
require 'gtk2'
begin
  require 'gnome2'
  $GNOME_SUPPORTED = true
rescue LoadError
  $GNOME_SUPPORTED = false
end
require 'rbbr/config'
require 'rbbr/metainfo'
require 'rbbr/doc'
require 'rbbr/ui/gtk/browselist'
require 'rbbr/ui/gtk/docviewer'
require 'rbbr/ui/gtk/moduleindex'
require 'rbbr/ui/gtk/modulenestingtree'
require 'rbbr/ui/gtk/browser'
require 'rbbr/ui/gtk/moduledisplay'
require 'rbbr/ui/gtk/modulelabel'
require 'rbbr/ui/gtk/windowutils'

['gdk_pixbuf2', 'gnomecanvas2',
  'libart2', 'libglade2', 'gconf2', 'pango'].each do |lib|
  begin
    require lib
  rescue LoadError
  end
end

module RBBR
module UI
module GTK
  def self.main
    Gtk.init
    window = Browser.new
    window.set_title("Ruby Browser")
    window.show
    GLib::Log.set_handler("Gtk", 1|2|4|8) do |domain, level, message|
      # ignore log message
    end
    Gtk.main
  end

end
end
end

if $0 == __FILE__
  RBBR::UI::GTK.main
end
