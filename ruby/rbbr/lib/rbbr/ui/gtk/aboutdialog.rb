=begin

  rbbr/ui/gtk/about.rb 

  $Author$
  $Date$

  Copyright (C) 2002 Ruby-GNOME2 Project

  This program is free software.
  You can distribute/modify this program under
  the terms of the Ruby Distribute License.

=end

require 'gdk_pixbuf2'
require 'gtk2'
require 'rbconfig'

module RBBR
module UI
module GTK
class AboutDialog < Gtk::Dialog
    def initialize(parent = nil)
      about = %Q[<span size="xx-large" weight="bold" foreground="#440000">
<span foreground="#cc1111">R</span>u<span foreground="#dd1111">b</span>y <span foreground="#cc1111">Br</span>owser</span> Version #{RBBR::VERSION}

<span foreground="#884411">Copyright (C) 2002 Ruby-GNOME2 Project</span>
]

      super("Ruby Browser: about", parent, Gtk::Dialog::MODAL,  
            [Gtk::Stock::CLOSE, Gtk::Dialog::RESPONSE_DELETE_EVENT])
      set_default_size(520, 420)
      set_border_width(10)
      set_default_response(Gtk::Dialog::RESPONSE_DELETE_EVENT)

      icon = Gtk::Image.new(File.join(RBBR::Config::DATA_DIR, "icon.xpm"))
      label = Gtk::Label.new.set_markup(about)
      label.set_padding(10, 10)
      label.set_justify(Gtk::JUSTIFY_CENTER)
      hbox = Gtk::HBox.new
      hbox.pack_start(icon, false, false, 20)
      hbox.pack_start(label, true, true, 0)
      hbox.set_border_width(10)
      vbox.pack_start(hbox, false, false, 0)

      scwin = Gtk::ScrolledWindow.new
      vbox.pack_start(scwin, true, true, 8)

      model = Gtk::ListStore.new(String, String)
      renderer = Gtk::CellRendererText.new

      list = Gtk::TreeView.new(model)
      list.set_rules_hint(true)
      column1 = Gtk::TreeViewColumn.new("item", renderer, {:text => 0})
      column1.sort_column_id = 0
      column2 = Gtk::TreeViewColumn.new("value", renderer, {:text => 1})
      column2.sort_column_id = 1
      list.append_column(column1)
      list.append_column(column2)
      ::Config::CONFIG.keys.sort.each do |k|
        iter = model.append
        model.set_value(iter, 0, k)
        model.set_value(iter, 1, ::Config::CONFIG[k].inspect)
      end
      scwin.add(list)
      show_all
    end
  end
end;end;end

if __FILE__ == $0 
  Gtk.init
  dialog = RBBR::UI::GTK::AboutDialog.new
  dialog.run
  dialog.destroy
end
