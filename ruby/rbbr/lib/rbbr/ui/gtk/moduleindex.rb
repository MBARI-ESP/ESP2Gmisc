=begin

  rbbr/ui/gtk/moduleindex.rb 

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

  class ModuleIndex < Gtk::TreeView
    include Observable
    
    def initialize
      @model = Gtk::TreeStore.new(String)
      @column = Gtk::TreeViewColumn.new("Classes/Modules", 
                                        Gtk::CellRendererText.new, {:text => 0})
      super(@model)
      
      append_column(@column)
      self.selection.set_mode(Gtk::SELECTION_SINGLE)
      @dag = nil
    end
    
    def update(module_spaces)
      @model.clear
      build_tree(module_spaces)
    end
    
    private
    def build_tree(module_spaces, dag = nil)
      if dag
        @dag = dag
      else
        @dag =
          if module_spaces.empty?
            RBBR::MetaInfo::ModuleDAG.full_module_dag
          else
            RBBR::MetaInfo::ModuleDAG.filtered_module_dag(module_spaces)
          end
      end
      
      root = @model.append(nil)
      root.set_value(0, "<root>")
      append_child(root, Object)
      
      root_module_iter = @model.append(root)
      root_module_iter.set_value(0, "<modules>")
      
      root_modules = (@dag.roots - [Object]).sort{|x, y| x.name <=> y.name}
      root_modules.each do |root_module|
        append_child(root_module_iter, root_module) if root_module.name != ""
      end
      
      signal_connect("row_expanded") do |tview, titer, tpath|
        append_children(titer)
        expand_row(tpath, false)
      end
      
      selection.signal_connect("changed") do |e|
        iter = selection.selected
        if iter
          klassname = iter.get_value(0)
          if klassname !~ /<.*>/
            changed
            notify_observers(eval(klassname))
          end
        end
      end
      
      expand_row(root.path, false)
    end
    
    def append_children(titer)
      child_iter = titer.first_child
      if child_iter != nil and ! child_iter.get_value(0)
        @model.remove(child_iter)
        children = Array.new
        subclasses = @dag.arc(eval(titer.get_value(0)))
        subclasses.sort{|x, y| x.name <=> y.name}.each do |child_iter|
          children << append_child(titer, child_iter)
        end
      end
    end
    
    def append_child(parent, klass)
      if klass.name.size > 0
        iter = @model.append(parent)
        iter.set_value(0, klass.name)
        subclasses = @dag.arc(klass)
        unless subclasses.empty?
          @model.append(iter)
        end
      end
    end
    
=begin
    def select_module(modul)
      @treeitems[modul].select
    end
=end
     
  public
  def expand_all
    @model.each do |model, path, iter|
      append_children(iter)
      false
    end
    super
  end
end

end;end;end
