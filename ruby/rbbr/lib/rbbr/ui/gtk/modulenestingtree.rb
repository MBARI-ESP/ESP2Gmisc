=begin

  rbbr/ui/gtk/modulenestingtree.rb 
	
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
require 'rbbr/metainfo'

module RBBR
module UI
module GTK

  class ModuleNestingTree < Gtk::TreeView
    include Observable

    def initialize
      @model = Gtk::TreeStore.new(String)
      @column = Gtk::TreeViewColumn.new("Module Nesting", Gtk::CellRendererText.new, {:text => 0})
      super(@model)

      append_column(@column)
      selection.set_mode(Gtk::SELECTION_MULTIPLE)
      @module_nesting = MetaInfo::ModuleNesting.new

      signal_connect("row_expanded") do |tview, titer, tpath|
        child_iter = titer.first_child
	if child_iter and ! child_iter.get_value(0)
	  freeze_notify
	  @model.remove(child_iter)
	  inner_modules = @module_nesting.inner_modules(eval(titer.get_value(0)))
	  inner_modules.sort{|x, y| x.name <=> y.name}.each do |inner_module|
	    append_module(titer, inner_module)
	  end
	  thaw_notify
	end
	expand_row(tpath, false)
      end
      selection.signal_connect("changed") do |e|
	@module_spaces = []
	selection.selected_each do |model, path, iter|
	  @module_spaces << eval(iter.get_value(0))
	end
	if @module_spaces.size > 0
	  changed
	  notify_observers(@module_spaces)
	end
      end
    end

    def update
      @module_nesting = MetaInfo::ModuleNesting.new
      @model.clear
      append_module(nil, Object)
      changed
      notify_observers([])
    end

    private
    def append_module(parent, modul)
      iter = @model.append(parent)
      iter.set_value(0, modul.name)
      inner_modules = @module_nesting.inner_modules(modul)
      unless inner_modules.empty?
        child_iter = @model.append(iter) 
      end
    end

  end
end; end; end
