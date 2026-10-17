shader_type canvas_item;
// A transparent 3D viewport already contains premultiplied RGB. Preserve
// alpha when compositing once over video, including antialiased taper edges.
render_mode unshaded, blend_premul_alpha;
