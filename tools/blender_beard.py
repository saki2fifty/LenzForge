"""Blender add-on: round-trip LenzForge beard guides as editable poly curves.

Install this file as a Blender add-on, then use File > Import/Export > LenzForge
beard (.json). Geometry is a face-width reference in the XY plane. The viewer
rebinds roots to live landmarks; curve edits control each strand's rest shape.
"""
import copy
import json
import math

bl_info = {'name': 'LenzForge Beard Curves', 'author': 'saki2fifty',
           'version': (1, 0, 0), 'blender': (4, 0, 0),
           'location': 'File > Import/Export', 'category': 'Import-Export'}


def curve_override(points, base_length, root_width, tip_width):
    """Convert Blender XY points to a bounded, normalized Godot rest guide."""
    if not 2 <= len(points) <= 65 or not .00001 < base_length < 5:
        raise ValueError('Use 2–65 points per strand and a valid exported base length.')
    if any(len(p) < 2 or not all(math.isfinite(v) for v in p) for p in points):
        raise ValueError('Curve coordinates must be finite.')
    if not .1 <= root_width <= 12 or not 0 <= tip_width <= 12:
        raise ValueError('Widths must fit the viewer range: root 0.1–12, tip 0–12.')
    relative = [(p[0] - points[0][0], -(p[1] - points[0][1])) for p in points]
    length = sum(math.dist(a, b) for a, b in zip(relative, relative[1:]))
    if length < 1e-6:
        return {'length': 0.0, 'root_width': root_width, 'tip_width': tip_width}
    if length / base_length > 3.00001:
        raise ValueError('A strand exceeds the 3× length limit. Increase the base length in LenzForge first.')
    return {'length': min(3.0, length / base_length), 'root_width': root_width,
            'tip_width': tip_width, 'guide': [[x / length, y / length] for x, y in relative]}


def edited_document(original, curves):
    if original.get('format') != 'lenzforge-beard' or original.get('version') != 1:
        raise ValueError('Unsupported beard file.')
    guides = original.get('geometry', {}).get('guides', [])
    if not 16 <= len(guides) <= 1024 or len(curves) != len(guides):
        raise ValueError('Keep the exported strand count; change density in LenzForge.')
    result = copy.deepcopy(original)
    result.setdefault('strands', {})
    for guide, curve in zip(guides, curves):
        index = str(guide['index'])
        edit = curve_override(curve['points'], guide['base_length'], curve['root_width'], curve['tip_width'])
        result['strands'].setdefault(index, {}).update(edit)
        if 'guide' not in edit:
            result['strands'][index].pop('guide', None)
    result.pop('geometry', None)  # The viewer regenerates neutral export geometry.
    return result


try:
    import bpy
    from bpy_extras.io_utils import ImportHelper, ExportHelper
except ImportError:
    bpy = None  # Pure interchange functions remain testable without Blender.


if bpy:
    class LENZFORGE_OT_import_beard(bpy.types.Operator, ImportHelper):
        bl_idname = 'import_curve.lenzforge_beard'
        bl_label = 'Import LenzForge Beard'
        bl_options = {'REGISTER', 'UNDO'}
        filename_ext = '.json'
        filter_glob: bpy.props.StringProperty(default='*.json', options={'HIDDEN'})

        def execute(self, context):
            try:
                with open(self.filepath, encoding='utf-8-sig') as file:
                    text = file.read(8 * 1024 * 1024 + 1)
                if len(text.encode('utf-8')) > 8 * 1024 * 1024:
                    raise ValueError('File exceeds 8 MB.')
                data = json.loads(text)
                guides = data.get('geometry', {}).get('guides', [])
                if data.get('format') != 'lenzforge-beard' or data.get('version') != 1 or not 16 <= len(guides) <= 1024:
                    raise ValueError('Use Export in the LenzForge Beard tab to include curve geometry.')
                # Validate every guide before adding an object to the scene.
                for guide in guides:
                    if any(len(point) != 3 for point in guide['points']):
                        raise ValueError('Each exported point needs X, Y, and Z coordinates.')
                    curve_override(guide['points'], guide['base_length'], guide['root_width']*300, guide['tip_width']*300)
                curve = bpy.data.curves.new(data['name'], 'CURVE')
                curve.dimensions = '3D'
                curve.resolution_u = 1
                curve.bevel_resolution = 1
                curve.bevel_depth = .5 / 300
                for guide in guides:
                    spline = curve.splines.new('POLY')
                    spline.points.add(len(guide['points'])-1)
                    for index, (point, xyz) in enumerate(zip(spline.points, guide['points'])):
                        point.co = (*xyz[:3], 1)
                        t = index / (len(guide['points'])-1)
                        point.radius = 300 * ((1-t)*guide['root_width'] + t*guide['tip_width'])
                obj = bpy.data.objects.new(data['name'], curve)
                context.collection.objects.link(obj)
                obj['lenzforge_document'] = json.dumps(data)
                for selected in context.selected_objects:
                    selected.select_set(False)
                obj.select_set(True)
                context.view_layer.objects.active = obj
                self.report({'INFO'}, 'Edit points/radii in the XY plane. Roots remain attached to the face on import.')
                return {'FINISHED'}
            except (ValueError, KeyError, TypeError, OSError) as error:
                self.report({'ERROR'}, str(error))
                return {'CANCELLED'}

    class LENZFORGE_OT_export_beard(bpy.types.Operator, ExportHelper):
        bl_idname = 'export_curve.lenzforge_beard'
        bl_label = 'Export LenzForge Beard'
        filename_ext = '.json'
        filter_glob: bpy.props.StringProperty(default='*.json', options={'HIDDEN'})

        def execute(self, context):
            try:
                obj = context.active_object
                if obj is None or obj.type != 'CURVE' or 'lenzforge_document' not in obj:
                    raise ValueError('Select a beard imported with this add-on.')
                original = json.loads(obj['lenzforge_document'])
                curves = []
                for spline in obj.data.splines:
                    if spline.type != 'POLY':
                        raise ValueError('Convert splines to Poly before exporting; use at most 65 points per strand.')
                    curves.append({'points': [list(point.co[:3]) for point in spline.points],
                                   'root_width': spline.points[0].radius*obj.data.bevel_depth*600,
                                   'tip_width': spline.points[-1].radius*obj.data.bevel_depth*600})
                result = edited_document(original, curves)
                result['name'] = obj.name[:80]
                with open(self.filepath, 'w', encoding='utf-8') as file:
                    json.dump(result, file, indent=2, allow_nan=False)
                self.report({'INFO'}, 'Exported 2D rest curves. Object transforms and depth are not applied.')
                return {'FINISHED'}
            except (ValueError, KeyError, TypeError, OSError, IndexError) as error:
                self.report({'ERROR'}, str(error))
                return {'CANCELLED'}

    def _import_menu(self, context):
        self.layout.operator(LENZFORGE_OT_import_beard.bl_idname, text='LenzForge beard (.json)')

    def _export_menu(self, context):
        self.layout.operator(LENZFORGE_OT_export_beard.bl_idname, text='LenzForge beard (.json)')

    def register():
        bpy.utils.register_class(LENZFORGE_OT_import_beard)
        bpy.utils.register_class(LENZFORGE_OT_export_beard)
        bpy.types.TOPBAR_MT_file_import.append(_import_menu)
        bpy.types.TOPBAR_MT_file_export.append(_export_menu)

    def unregister():
        bpy.types.TOPBAR_MT_file_import.remove(_import_menu)
        bpy.types.TOPBAR_MT_file_export.remove(_export_menu)
        bpy.utils.unregister_class(LENZFORGE_OT_export_beard)
        bpy.utils.unregister_class(LENZFORGE_OT_import_beard)

    if __name__ == '__main__':
        register()
