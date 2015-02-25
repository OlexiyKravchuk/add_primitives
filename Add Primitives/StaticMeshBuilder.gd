tool
extends SurfaceTool

func add_tri(vertex_array, reverse = false, smooth = false):
	if vertex_array.size() != 3:
		pass
	else:
		var face_index = [0,2,1]
		if reverse:
			face_index.invert()
		
		if smooth:
			add_smooth_group(true)
		else:
			add_smooth_group(false)
		
		for idx in face_index:
			add_vertex(vertex_array[idx])
	
func add_quad(vertex_array, reverse = false, smooth = false):
	if vertex_array.size() != 4:
		pass
	else:
		var face_index = [0,2,1,3,0,1]
		if reverse:
			face_index.invert()
		
		if smooth:
			add_smooth_group(true)
		else:
			add_smooth_group(false)
		
		for idx in face_index:
			add_vertex(vertex_array[idx])