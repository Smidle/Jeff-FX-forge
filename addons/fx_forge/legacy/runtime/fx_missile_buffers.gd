@tool
extends RefCounted
## Typed members are mutated in place: no dictionary-to-local PackedArray COW copy.
var vertices:=PackedByteArray()
var attributes:=PackedByteArray()
var vertex_stride: int
var attribute_stride: int
var color_offset: int
var uv_offset: int
func _init(format: int, count: int) -> void:
	vertex_stride=RenderingServer.mesh_surface_get_format_vertex_stride(format,count)
	attribute_stride=RenderingServer.mesh_surface_get_format_attribute_stride(format,count)
	color_offset=RenderingServer.mesh_surface_get_format_offset(format,count,Mesh.ARRAY_COLOR)
	uv_offset=RenderingServer.mesh_surface_get_format_offset(format,count,Mesh.ARRAY_TEX_UV)
	vertices.resize(vertex_stride*count)
	attributes.resize(attribute_stride*count)
func write(index: int, point: Vector3, direction: Vector3, fraction: float, side: float) -> void:
	var offset: int=index*vertex_stride
	vertices.encode_float(offset,point.x)
	vertices.encode_float(offset+4,point.y)
	vertices.encode_float(offset+8,point.z)
	var co: int=index*attribute_stride+color_offset
	attributes[co]=clampi(int((direction.x*.5+.5)*255),0,255)
	attributes[co+1]=clampi(int((direction.y*.5+.5)*255),0,255)
	attributes[co+2]=clampi(int((direction.z*.5+.5)*255),0,255)
	attributes[co+3]=255
	var uv: int=index*attribute_stride+uv_offset
	attributes.encode_float(uv,fraction)
	attributes.encode_float(uv+4,side)
func upload(mesh: ArrayMesh) -> void:
	mesh.surface_update_vertex_region(0,0,vertices)
	mesh.surface_update_attribute_region(0,0,attributes)
func byte_count() -> int:
	return vertices.size()+attributes.size()
