=begin

  rbbr/ui/gtk/windowutils.rb 

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
  class LibrarySelectionDialog < Gtk::Dialog
    attr_reader :result
    def initialize(parent)
      super("Select a library", parent, Gtk::Dialog::MODAL, 
            [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_DELETE_EVENT],
            [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK])
      set_default_response(Gtk::Dialog::RESPONSE_DELETE_EVENT)
      set_default_size(384, 256)

      library_treeview_scwin = Gtk::ScrolledWindow.new
      vbox.pack_start(library_treeview_scwin)
      library_treeview_scwin.set_policy(Gtk::POLICY_AUTOMATIC,
                                        Gtk::POLICY_AUTOMATIC)

      model = Gtk::ListStore.new(String, String, String)
      renderer = Gtk::CellRendererText.new

      library_treeview = Gtk::TreeView.new(model)
      library_treeview.selection.mode = Gtk::SELECTION_SINGLE
      library_treeview.rules_hint = true
      library_treeview.grab_focus
      library_treeview.append_column(Gtk::TreeViewColumn.new("Feature", renderer, {:text => 0}))
      library_treeview.append_column(Gtk::TreeViewColumn.new("LibType", renderer, {:text => 1}))
      library_treeview.append_column(Gtk::TreeViewColumn.new("Filename", renderer, {:text => 2}))
      library_treeview_scwin.add(library_treeview)

      RBBR::MetaInfo::Library.libraries.sort.each do |library|
        iter = model.append
        iter.set_value(0, library.feature)
        iter.set_value(1, library.libtype)
        iter.set_value(2, library.filename)
      end

      library_treeview.selection.signal_connect('changed') do |selection|
        iter = selection.selected
        @result = iter.get_value(0)
      end
      show_all
    end
  end

end;end;end
