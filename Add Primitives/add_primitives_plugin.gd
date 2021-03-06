#==============================================================================#
# Copyright (c) 2015 Franklin Sobrinho.                                        #
#                                                                              #                                                   
# Permission is hereby granted, free of charge, to any person obtaining        #
# a copy of this software and associated documentation files (the "Software"), #
# to deal in the Software without restriction, including without               #
# limitation the rights to use, copy, modify, merge, publish,                  #
# distribute, sublicense, and/or sell copies of the Software, and to           #
# permit persons to whom the Software is furnished to do so, subject to        #
# the following conditions:                                                    #
#                                                                              #
# The above copyright notice and this permission notice shall be               #
# included in all copies or substantial portions of the Software.              #
#                                                                              #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,              #
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF           #
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.       #
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY         #
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,         #
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE            #
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                       #
#==============================================================================#

tool
extends EditorPlugin

class DirectoryUtilities:
	extends Directory
	
	func get_scripts_from_list(list_files):
		var scripts = []
		
		for file in list_files:
			if file.extension() == 'gd':
				scripts.append(file)
			
		return scripts
		
	func get_file_list(path):
		var list = []
		
		if dir_exists(path):
			open(path)
			list_dir_begin()
			
			while true:
				list.append(get_next())
				if list[list.size() - 1] != '.':
					continue
				else:
					list.append(get_next())
					break
					
			list_dir_end()
			
		return list
		
#End DirectoryUtilities

class AddMeshPopup:
	extends Control
	
	var window
	
	var menu_button
	var options
	var popup_panel
	
	var parameters
	var smooth_button
	var reverse_button
	
	var modifiers
	var transform
	
	func get_dialogs():
		var dialogs = []
		
		for i in popup_panel.get_children():
			dialogs.append(i)
			
		return dialogs
	
	func _init():
		window = preload('gui/AddMeshPopup.xml').instance()
		
		parameters = window.get_node('PopupPanel/Parameters/Settings')
		smooth_button = window.get_node('PopupPanel/Parameters/Smooth')
		reverse_button = window.get_node('PopupPanel/Parameters/Reverse')
		
		modifiers = window.get_node('PopupPanel/Modifiers/Modifier')
		transform = window.get_node('PopupPanel/Transform/Dialog')
		
		menu_button = window.get_node('MenuButton')
		options = menu_button.get_popup()
		popup_panel = window.get_node('PopupPanel')
		
		add_child(window)
		window.hide()
		
class AddPrimitives:
	extends HBoxContainer
	
	var start
	var index = 0
	
	var hbox
	var add_mesh_popup
	
	var node
	var mesh_instance
	
	var original_mesh
	var meshes_to_modify = []
	
	var current_script
	var mesh_scripts = {}
	var modifier_scripts = {}
	var extra_modules = {}
	
	#Utilites
	static func get_plugins_folder():
		var path = OS.get_data_dir()
		path = path.substr(0, path.find_last('/'))
		path = path.substr(0, path.find_last('/'))
		return path + '/plugins'
		
	func edit(object):
		node = object
		
	func update_menu():
		var popup_menu = get_node('spatial_toolbar_menu').get_popup()
		popup_menu.set_name('spatial_menu')
		
		popup_menu.clear()
		
		for i in popup_menu.get_children():
			if i.get_type() == 'PopupMenu':
				popup_menu.remove_and_delete_child(i)
		
		var dir = extra_modules['directory_utilites']
		
		var submenus = {}
		
		var path = get_plugins_folder() + '/Add Primitives'
		
		var scripts = dir.get_file_list(path + '/meshes')
		scripts = dir.get_scripts_from_list(scripts)
		
		for name in scripts:
			var key = 'Add ' + name.substr(0, name.find_last('.')).capitalize()
			mesh_scripts[key] = path + '/meshes/' + name
			
			var temp_script = load(mesh_scripts[key]).new()
			
			if temp_script.has_method('container'):
				var container = temp_script.container()
				if submenus.has(container):
					submenus[container].append(key)
				else:
					submenus[container] = [key]
			else:
				popup_menu.add_item(key)
				
		if submenus.size() != 0:
			popup_menu.add_separator()
		
		for i in submenus.keys():
			
			var submenu = PopupMenu.new()
			submenu.set_name(i)
			popup_menu.add_child(submenu)
			popup_menu.add_submenu_item(i, i)
			
			for j in submenus[i]:
				submenu.add_item(j)
			
		popup_menu.add_separator()
		popup_menu.add_item('Reload Menu')
		
		if not popup_menu.is_connected("item_pressed", self, "popup_signal"):
			popup_menu.connect("item_pressed", self, "popup_signal")
		
	func popup_signal(id):
		current_script = null
		
		var popup = get_node('spatial_toolbar_menu').get_popup()
		
		var command = popup.get_item_text(popup.get_item_index(id))
		
		if command == 'Reload Menu':
			update_menu()
			
		else:
			current_script = load(mesh_scripts[command]).new()
			
			if current_script.has_method('build_mesh'):
				var mesh
				if current_script.has_method('mesh_parameters'):
					start = OS.get_ticks_msec()
					mesh = current_script.build_mesh(1)
					print('built in: ', OS.get_ticks_msec() - start, ' milisecs')
					print('====================================================')
					mesh_popup(command)
				else:
					start = OS.get_ticks_msec()
					mesh = current_script.build_mesh()
					print('built in: ', OS.get_ticks_msec() - start, ' milisecs')
					print('====================================================')
					
				mesh.set_name(command.split(' ')[1])
				
				if mesh != null:
					add_mesh_instance(mesh)
				
	func load_modifiers(tree):
		var dir = extra_modules['directory_utilites']
		var path = get_plugins_folder() + '/Add Primitives/meshes/modifiers'

		tree.clear()
	
		if dir.dir_exists(path):
			var modifiers = dir.get_file_list(path)
			modifiers = dir.get_scripts_from_list(modifiers)
			
			for mod in modifiers:
				var name = mod.substr(0, mod.find_last('.')).capitalize()
				modifier_scripts[name] = load(path + '/' + mod).new()
				
				var temp = weakref(modifier_scripts[name])
				
				if temp.get_ref().has_method('modifier_parameters'):
					tree.set_hide_root(true)
					tree.set_columns(2)
					tree.set_column_min_width(0, 2)
					
					var root = tree.get_root()
					if not root:
						root = tree.create_item()
						
					var item = tree.create_item(root)
					item.set_text(0, temp.get_ref().get_name())
					item.set_cell_mode(1, 1)
					item.set_checked(1, false)
					item.set_editable(1, true)
					item.set_text(1, 'On')
					
					temp.get_ref().modifier_parameters(item, tree)
					
	func transform_dialog(tree):
		tree.clear()
		tree.set_hide_root(true)
		tree.set_columns(2)
		tree.set_column_min_width(0, 3)
		tree.set_column_titles_visible(true)
		tree.set_column_title(0, 'Axis')
		tree.set_column_title(1, 'Value')
		
		var root = tree.create_item()
		
		var translate = tree.create_item(root)
		translate.set_text(0, 'Translation')
		translate.set_selectable(0, false)
		translate.set_selectable(1, false)
		
		var rotate = tree.create_item(root)
		rotate.set_text(0, 'Rotation')
		rotate.set_selectable(0, false)
		rotate.set_selectable(1, false)
		
		var scale = tree.create_item(root)
		scale.set_text(0, 'Scale')
		scale.set_selectable(0, false)
		scale.set_selectable(1, false)
		
		var axis = ['x', 'y', 'z']
		
		var item = root.get_children()
		
		while true:
			for a in axis:
				var i = tree.create_item(item)
				i.set_text(0, a)
				i.set_cell_mode(1, 2)
				if item.get_text(0) != 'Scale':
					i.set_range(1, 0)
				else:
					i.set_range(1, 1)
				i.set_range_config(1, -100, 100, 0.1)
				i.set_editable(1, true)
			item = item.get_next()
			
			if not item:
				break
				
	func mesh_popup(key):
		set_current_dialog(0)
		
		var dir = extra_modules['directory_utilites']
		
		modifier_scripts.clear()
		original_mesh = null
		
		add_mesh_popup.window.set_title(key)
		
		var settings = add_mesh_popup.parameters
		var modifier = add_mesh_popup.modifiers
		
		settings.clear()
		settings.set_hide_root(true)
		settings.set_columns(2)
		settings.set_column_title(0, 'Parameter')
		settings.set_column_title(1, 'Value')
		settings.set_column_titles_visible(true)
		settings.set_column_min_width(0, 2)
		
		var smooth_button = add_mesh_popup.smooth_button
		smooth_button.set_pressed(false)
		var reverse_button = add_mesh_popup.reverse_button
		smooth_button.set_pressed(false)
		
		if not settings.is_connected('item_edited', self, 'update_mesh'):
			settings.connect('item_edited', self, 'update_mesh', [key, settings, modifier, smooth_button, reverse_button])
		if not smooth_button.is_connected('pressed', self, 'update_mesh'):
			smooth_button.connect('pressed', self, 'update_mesh', [key, settings, modifier, smooth_button, reverse_button])
		if not reverse_button.is_connected('pressed', self, 'update_mesh'):
			reverse_button.connect('pressed', self, 'update_mesh', [key, settings, modifier, smooth_button, reverse_button])
		
		load_modifiers(modifier)
		
		if not modifier.is_connected("item_edited", self, 'modify_mesh'):
			modifier.connect("item_edited", self, 'modify_mesh', [modifier])
			
		var dialog = add_mesh_popup.transform
		
		transform_dialog(dialog)
		
		if not dialog.is_connected('item_edited', self, 'transform_mesh'):
			dialog.connect('item_edited', self, 'transform_mesh', [dialog])
		
		current_script.mesh_parameters(settings)
		
		add_mesh_popup.show()
		add_mesh_popup.window.popup_centered()
		
	func get_tree_children(root):
		var items = []
		
		var item = root.get_children()
		while true:
			items.append(item)
			
			item = item.get_next()
			if item == null:
				break
				
		return items
		
	func update_mesh(key, settings, modifier, smooth_button, reverse_button):
		var values = []
		
		var smooth = smooth_button.is_pressed()
		var reverse = reverse_button.is_pressed()
		
		var items = current_script.get_parameters()
		
		for i in items:
			var cell = i.get_cell_mode(1)
			
			if cell == 0:
				values.append(i.get_text(1))
			elif cell == 1:
				values.append(i.is_checked(1))
			elif cell == 2:
				if i.get_text(1):
					var text = i.get_text(1)
					text = text.split(',')
					values.append(text[i.get_range(1)])
				else:
					values.append(i.get_range(1))
					
		start = OS.get_ticks_msec()
		var mesh = current_script.build_mesh(values, smooth, reverse)
		print(' built in: ', OS.get_ticks_msec() - start, ' milisecs')
		print('====================================================')
		#center geometry######
		mesh.center_geometry()
		######################
		
		assert( mesh.get_type() == 'Mesh' )
		
		mesh_instance.set_mesh(mesh)
		
		original_mesh = mesh
		
		modify_mesh(modifier)
		
	func modify_mesh(tree):
		var root = tree.get_root()
		var item = root.get_children()
		
		meshes_to_modify.clear()
		
		var count = 0
		
		if original_mesh == null:
			original_mesh = mesh_instance.get_mesh()
			
		while true:
			var values = []
			
			var script
			
			if item.is_checked(1):
				script = modifier_scripts[item.get_text(0)]
				count += 1
				
				var par = get_tree_children(item)
				
				assert( not par.empty() )
				
				for p in par:
					var  cell = p.get_cell_mode(1)
					if cell == 0:
						values.append(p.get_text(1))
					elif cell == 1:
						values.append(p.get_checked(1))
					elif cell == 2:
						if p.get_text(1):
							var text = p.get_text(1)
							text = text.split(',')
							values.append(text[p.get_range(1)])
						else:
							values.append(p.get_range(1))
							
				assert( mesh_instance.get_mesh() )
				
				if count == 1:
					mesh_instance.set_mesh(original_mesh)
					mesh_instance.set_mesh(script.modifier(values, mesh_instance.get_aabb(), original_mesh))
					
				elif count > 1:
					meshes_to_modify.resize(count - 1)
					meshes_to_modify[count - 2] = mesh_instance.get_mesh()
					
					mesh_instance.set_mesh(meshes_to_modify[count - 2])
					mesh_instance.set_mesh(script.modifier(values, mesh_instance.get_aabb(), meshes_to_modify[count - 2]))
					
				values.clear()
				
			if count == 0:
				mesh_instance.set_mesh(original_mesh)
				
			item = item.get_next()
			
			if item == null:
				break
				
	func transform_mesh(dialog):
		var val = []
		var transform = {}
		
		var root = dialog.get_root()
		
		var item = root.get_children()
		
		while true:
			var child = item.get_children()
			
			for i in range(3):
				val.append(child.get_range(1))
				
				child = child.get_next()
			
			transform[item.get_text(0)] = Vector3(val[0], val[1], val[2])
			val.clear()
			
			item = item.get_next()
			
			if not item:
				break
				
		mesh_instance.set_translation(transform['Translation'])
		mesh_instance.set_rotation(transform['Rotation']/rad2deg(1))
		mesh_instance.set_scale(transform['Scale'])
		
		
	func add_mesh_instance(mesh):
		mesh_instance = MeshInstance.new()
		#center geometry######
		mesh.center_geometry()
		######################
		mesh_instance.set_mesh(mesh)
		mesh_instance.set_name(mesh.get_name())
		
		var root
		
		if is_inside_tree():
			root = get_tree().get_edited_scene_root()
			
			node.add_child(mesh_instance)
			mesh_instance.set_owner(root)
			
	func set_current_dialog(id):
		var popup_panel = add_mesh_popup.popup_panel
		var options = add_mesh_popup.options
		
		if id == index:
			pass
			
		else:
			popup_panel.get_child(index).hide()
			popup_panel.get_child(id).show()
			
			add_mesh_popup.menu_button.set_text(options.get_item_text(options.get_item_index(id)))
			
			index = id
			
	func _notification(what):
		if what == NOTIFICATION_ENTER_TREE:
			add_mesh_popup = AddMeshPopup.new()
			
			for i in add_mesh_popup.get_dialogs():
				add_mesh_popup.options.add_item(i.get_name())
				
			add_mesh_popup.options.connect('item_pressed', self, 'set_current_dialog')
			
			add_mesh_popup.menu_button.set_text(add_mesh_popup.options.get_item_text(add_mesh_popup.options.get_item_index(0)))
			
			add_child(add_mesh_popup)
			add_mesh_popup.hide()
			
	func _init(editor_plugin):
		extra_modules['directory_utilites'] = DirectoryUtilities.new()
		
		var separator = VSeparator.new()
		var spatial_menu = MenuButton.new()
		spatial_menu.set_name('spatial_toolbar_menu')
		
		var icon = load(get_plugins_folder() + '/Add Primitives/icon_mesh_instance_add.png')
		spatial_menu.set_button_icon(icon)
		spatial_menu.set_tooltip("Add New MeshInstance")
		
		add_child(separator)
		add_child(spatial_menu)
		
		editor_plugin.add_custom_control(CONTAINER_SPATIAL_EDITOR_MENU, self)
		
		update_menu()
		
#End AddPrimitives

var add_primitives

static func get_name():
	return "Add Primitives"
	
func edit(object):
	add_primitives.edit(object)
	
func handles(object):
	return object.is_type('Spatial')
	
func make_visible(visible):
	if visible:
		add_primitives.show()
	else:
		add_primitives.hide()
		add_primitives.edit(null)

func _init():
	print("ADD PRIMITIVES INIT")
	
func _enter_tree():
	add_primitives = AddPrimitives.new(self)
	
	if not add_primitives.is_inside_tree():
		add_child(add_primitives)
		
	add_primitives.hide()
	
func _exit_tree():
	add_primitives.free()
	