=begin

  rbbr/ui/gtk/modulelabel.rb 

  $Author$
  $Date$

  Copyright (C) 2002 Ruby-GNOME2 Project

  Copyright (C) 2000-2002 Hiroshi Igarashi <iga@ruby-lang.org>

  This program is free software.
  You can distribute/modify this program under
  the terms of the Ruby Distribute License.

=end

module RBBR
module UI
module GTK

  class ModuleLabel < Gtk::Entry
    def initialize
      #super("")
      #self.set_justify(Gtk::JUSTIFY_LEFT)
      super
      self.set_editable(false)
    end

    def update(modul)
      text = 
        if Class === modul
          "class #{modul.name}"
        else # Module
          "module #{modul.name}"
        end
      if Class === modul and Object != modul
        text << " < #{modul.superclass.name}"
      end
      included_modules_at = modul.included_modules_at
      unless included_modules_at.empty?
        text << "; include " << included_modules_at.join(", ")
      end
      self.set_text(text)
    end
  end

end;end;end
