=begin

  rbbr/ui/gtk/browselist.rb 

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
  class BrowseList < Gtk::TreeView
    include Observable
    def initialize(labels)
      @modul = nil
      @labels = labels
      @model = Gtk::ListStore.new(*labels.collect{|label| label.class})
      super(@model)
      
      renderer = Gtk::CellRendererText.new
      labels.each_index do |cnt|
        column = Gtk::TreeViewColumn.new(labels[cnt], renderer, {:text => cnt})
        column.sort_column_id = cnt
        append_column(column)
      end
      
      selection.mode = Gtk::SELECTION_SINGLE
      selection.signal_connect('changed') do |e|
        iter = selection.selected
        changed
        notify_selection(@modul, iter.get_value(0)) if iter
      end

      set_rules_hint(true)
    end

    private
    def notify_selection(m, text)
      # should be overridden in sub classes
    end

    public
    def update(modul)
      freeze_notify
      @model.clear
      update_list(modul)
      thaw_notify
      @modul = modul
    end
    
    def append(data)
      iter = @model.append
      @labels.each_index do |cnt|
        iter.set_value(cnt, data[cnt])
      end
    end
    
    def update_list(modul)
      # should be overridden in sub classes
    end
  end

  class MethodList < BrowseList
    def initialize
      super(["Name", "Arity"])
    end
  end

  class PublicInstanceMethodList < MethodList
    def update_list(modul)
      modul.public_instance_methods.sort.each do |name|
        self.append([name, modul.instance_method(name).arity.to_s])
      end
    end
    def notify_selection( modul, method_name )
      spec = [modul, method_name].join("#")
      notify_observers( modul, spec )
    end
  end

  class ProtectedInstanceMethodList < MethodList
    def update_list(modul)
      modul.protected_instance_methods.sort.each do |name|
        self.append([name, modul.instance_method(name).arity.to_s])
      end
    end
    def notify_selection( modul, method_name )
      spec = [modul, method_name].join("#")
      notify_observers( modul, spec )
    end
  end

  class PrivateInstanceMethodList < MethodList
    def update_list(modul)
      modul.private_instance_methods.sort.each do |name|
        self.append([name, modul.instance_method(name).arity.to_s])
      end
    end
    def notify_selection( modul, method_name )
      spec = [modul, method_name].join("#")
      notify_observers( modul, spec )
    end
  end

  class SingletonMethodList < MethodList
    def update_list(modul)
      modul.singleton_methods.sort.each do |name|
        self.append([name, modul.method(name).arity.to_s])
      end
    end
    def notify_selection( modul, method_name )
      spec = [modul, method_name].join(".")
      notify_observers( modul, spec )
    end
  end

  class ConstantList < BrowseList
    def initialize
      super(["Name", "Value"])
    end

    def update_list(modul)
      MetaInfo::ModuleNesting.true_constants(modul).sort.each do |name|
        self.append([name, modul.const_get(name).inspect])
      end
    end
    def notify_selection( modul, constant_name )
      spec = [modul, constant_name].join("::")
      notify_observers( modul, spec )
    end
  end

  class PropertyList < BrowseList
    def initialize
      super(["Name", "Type", "GType", "Flags", "Nick", "Blurb"])
    end
	
    def update_list(modul)
      if modul <= GLib::Object
        modul.properties.sort.each do |prop_name|
	  prop = modul.property(prop_name)
          if prop.owner_type == modul.gtype
            flags = ''
            flags << 'r' if prop.flags & GLib::Param::READABLE > 0
            flags << 'w' if prop.flags & GLib::Param::WRITABLE > 0
# prop.value_type.to_class doesn't work.
#            self.append([prop.name, prop.value_type.to_class.name, prop.value_type.name, flags,
#                          prop.nick, prop.blurb])
            self.append([prop.name, " ", prop.value_type.name, flags,
                         WindowUtils.conv_utf8(prop.nick), WindowUtils.conv_utf8(prop.blurb)])
          end
        end
      end
    end
  end
  
  class SignalList < BrowseList
    def initialize
      super(["Name", "Return type", "Parameters"])
    end
	
    def update_list(modul)
      if modul < GLib::Instantiatable or modul < GLib::Interface
        modul.signals.each{|signal_name|
	  signal = modul.signal(signal_name)
          self.append([signal.name, signal.return_type.name,
                        signal.param_types.map{|t| t.name}.join(", ") ])
        }
      end
    end
  end

end;end;end
