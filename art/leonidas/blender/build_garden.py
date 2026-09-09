"""Rebuild the original Blender scene for Leonidas's first story.

Run with Blender 4.5 LTS:
  blender --background --python build_garden.py -- --output /absolute/artifact/dir
No external models, textures, image generation, or network calls are used.
The garden is a tabletop study; the courtyard itself remains unplanted.
"""
import argparse
import json
import math
import random
import struct
import sys
import zlib
from pathlib import Path

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--samples', type=int, default=512)
parser.add_argument('--size', type=int, default=1536)
options = parser.parse_args(args)
options.output.mkdir(parents=True, exist_ok=True)
random.seed(42)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def material(name, color, roughness=.5, metal=0, texture=0, scale=7):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metal
    if texture:
        nodes = mat.node_tree.nodes
        noise = nodes.new('ShaderNodeTexNoise')
        noise.inputs['Scale'].default_value = scale
        noise.inputs['Detail'].default_value = 3
        bump = nodes.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value = texture
        bump.inputs['Distance'].default_value = .06
        mat.node_tree.links.new(noise.outputs['Fac'], bump.inputs['Height'])
        mat.node_tree.links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
    return mat


stone = material('Aubergine limestone', (.12, .10, .125), .88, texture=.28)
edge_stone = material('Pale carved edges', (.27, .245, .24), .7, texture=.18)
wood = material('Dark walnut', (.078, .036, .018), .43, texture=.17, scale=3)
gold = material('Aged brushed brass', (.43, .25, .085), .27, .78, texture=.13)
gold_light = material('Polished brass details', (.7, .47, .17), .23, .82)
paper = material('Ivory drawing paper', (.66, .58, .41), .88, texture=.08, scale=65)
ink = material('Garden plan ink', (.135, .2, .16), .75)
leaves = material('Study leaves - sage', (.13, .23, .115), .55, texture=.1)
leaf_light = material('Study leaves - young', (.23, .37, .13), .54)
soil = material('Dark potting earth', (.028, .017, .012), .98, texture=.4, scale=40)
leather = material('Oxblood folio', (.09, .019, .026), .6, texture=.13)
ivory = material('Ivory candle wax', (.73, .61, .39), .4)


def assign(obj, mat):
    obj.data.materials.append(mat)
    return obj


def bevel(obj, width=.06, segments=3):
    mod = obj.modifiers.new('Soft carved edges', 'BEVEL')
    mod.width = width
    mod.segments = segments
    obj.modifiers.new('Weighted corner normals', 'WEIGHTED_NORMAL')
    return obj


def box(name, location, dimensions, mat, soft=.02):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign(obj, mat)
    if soft:
        bevel(obj, soft)
    return obj


def cylinder(name, location, radius, depth, mat, vertices=64):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
                                     depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    assign(obj, mat)
    bevel(obj, min(.028, radius * .1), 3)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def sphere(name, location, radius, mat, scaling=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12,
                                       radius=radius, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scaling
    assign(obj, mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def tube(name, points, mat, radius=.02, cyclic=False):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.resolution_u = 12
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    path = curve.splines.new('POLY')
    path.points.add(len(points) - 1)
    for point, coords in zip(path.points, points):
        point.co = (*coords, 1)
    path.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    assign(obj, mat)
    return obj


def ring(name, center, radius, mat, thickness=.025, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=thickness,
                                    major_segments=96, minor_segments=12,
                                    location=center, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    assign(obj, mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def area(name, position, target, color, energy, size):
    data = bpy.data.lights.new(name, 'AREA')
    data.energy = energy
    data.color = color
    data.shape = 'DISK'
    data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = position
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()
    return obj


def emissive(name, color, strength):
    mat = material(name, color)
    node = mat.node_tree.nodes.get('Principled BSDF')
    node.inputs['Emission Color'].default_value = (*color, 1)
    node.inputs['Emission Strength'].default_value = strength
    return mat


def candle(x, y, z, height=.8):
    cylinder('Candle saucer', (x, y, z), .22, .065, gold)
    cylinder('Ivory candle', (x, y, z + height / 2), .1, height, ivory)
    flame_z = z + height + .075
    flame = sphere('Candle flame', (x, y, flame_z), .065,
                   emissive('Amber flame', (1, .34, .065), 7), (.62, .62, 1.8))
    data = bpy.data.lights.new('Candle practical', 'POINT')
    data.energy = 14
    data.color = (1, .43, .13)
    data.shadow_soft_size = .2
    lamp = bpy.data.objects.new('Candle practical', data)
    bpy.context.collection.objects.link(lamp)
    lamp.location = (x, y, flame_z + .08)


# Empty circular courtyard: inset paving and an open observatory arch.
cylinder('Courtyard plinth', (0, 1, -.23), 8.8, .42, stone, 128)
for radius in (3.8, 5.5, 7.3):
    ring('Paving brass inlay', (0, 1, .006), radius, gold, .012)
for angle in range(0, 360, 20):
    a = math.radians(angle)
    tube('Radial paving joint', [(3.8 * math.cos(a), 1 + 3.8 * math.sin(a), .012),
                                (8.7 * math.cos(a), 1 + 8.7 * math.sin(a), .012)],
         edge_stone, .012)

for x in (-5.5, -3.45, 3.45, 5.5):
    y = 4.6 if abs(x) < 4 else 2.9
    box('Column foot', (x, y, .25), (.9, .95, .5), edge_stone, .08)
    cylinder('Stone column', (x, y, 2.8), .29, 5.1, stone)
    cylinder('Column brass foot band', (x, y, .66), .305, .09, gold)
    cylinder('Column brass capital band', (x, y, 5.15), .34, .1, gold)
    box('Column capital', (x, y, 5.36), (.82, .82, .26), edge_stone, .04)

for r, mat, thick in ((3.46, edge_stone, .2), (3.18, gold, .035), (3.65, stone, .2)):
    points = [(r * math.cos(i * math.pi / 96), 4.6,
               5.22 + r * math.sin(i * math.pi / 96)) for i in range(97)]
    tube('Observatory arch', points, mat, thick)

# Low side walls and empty planting beds continue the unfinished courtyard.
for x in (-6.2, 6.2):
    box('Courtyard parapet', (x, 1.4, .85), (.45, 7.4, 1.7), stone, .07)
    box('Parapet cap', (x, 1.4, 1.73), (.6, 7.5, .16), edge_stone, .035)
for x in (-4.2, 4.2):
    box('Empty bed', (x, 2.3, .3), (1.15, 2.35, .5), edge_stone, .08)
    box('Unplanted bed earth', (x, 2.3, .55), (.96, 2.1, .018), soil, .01)

night = emissive('Night sky', (.005, .009, .022), .5)
box('Distant sky', (0, 16, 6), (150, .1, 120), night, 0)
star_mat = emissive('Distant starlight', (.57, .68, 1), 2)
for i in range(125):
    x = random.uniform(-12, 12)
    z = random.uniform(1.5, 14)
    sphere('Distant star', (x, 12.35, z), random.uniform(.012, .031), star_mat)
moon = emissive('Moon surface', (.59, .66, .85), 1.1)
sphere('Moon beyond arch', (-1.5, 12, 6.85), .49, moon)

# Drafting table, open atlas, an actual raised study rather than a finished garden.
cylinder('Walnut drafting table rim', (0, -.15, 1.66), 2.7, .19, wood, 128)
ring('Table edge brass', (0, -.15, 1.67), 2.71, gold, .025)
for x, y in ((-1.5, -1.4), (1.5, -1.4), (-1.5, 1.05), (1.5, 1.05)):
    cylinder('Tapered table leg', (x, y, .83), .085, 1.52, gold)
    sphere('Table foot', (x, y, .08), .12, gold, (1, 1, .7))

book = box('Garden folio cover', (-.25, -.35, 1.79), (3.48, 2.24, .09), leather, .04)
box('Thick folio pages', (-.25, -.35, 1.855), (3.37, 2.12, .07), paper, .025)
box('Open drafting sheet', (-.25, -.35, 1.9), (3.34, 2.1, .015), paper, .008)
tube('Folio center seam', [(-.25, -1.38, 1.913), (-.25, .66, 1.913)], gold, .012)
for inset in (0, .11):
    x0, x1 = -1.79 + inset, 1.29 - inset
    y0, y1 = -1.22 + inset, .52 - inset
    tube('Plan border', [(x0, y0, 1.918), (x1, y0, 1.918),
                         (x1, y1, 1.918), (x0, y1, 1.918)], ink, .008, True)

# Garden plan paths and six as-yet empty plot outlines.
for x in (-1.12, -.48, .24):
    for y in (-.74, .04):
        tube('Plan plot outline', [(x - .21, y - .22, 1.923), (x + .21, y - .22, 1.923),
                                   (x + .21, y + .22, 1.923), (x - .21, y + .22, 1.923)],
             ink, .009, True)
for y in (-.36, -.32):
    tube('Planned path', [(-1.6, y, 1.923), (1.08, y, 1.923)], gold, .011)
for i in range(5):
    tube('Hand drawn garden note', [(.65, -.92 + i * .075, 1.925),
                                    (1.07 - i * .034, -.92 + i * .075, 1.925)], ink, .004)

# A small botanical specimen on the drawing table, a study for the garden.
px, py, pz = -.52, .44, 1.96
bpy.ops.mesh.primitive_cone_add(vertices=64, radius1=.28, radius2=.4, depth=.45,
                               location=(px, py, pz + .19))
pot = bpy.context.object
pot.name = 'Brass botanical specimen pot'
assign(pot, gold)
bevel(pot, .025)
ring('Rolled pot rim', (px, py, pz + .425), .399, gold_light, .037)
cylinder('Specimen earth', (px, py, pz + .43), .367, .025, soil)
stem_base = pz + .445
tube('Seedling stem', [(px, py, stem_base), (px - .03, py, stem_base + .32),
                       (px + .07, py, stem_base + .72), (px + .025, py, stem_base + 1.08)],
     leaves, .022)


def leaf(name, start, end, width, mat):
    start, end = Vector(start), Vector(end)
    axis = end - start
    side = axis.cross(Vector((0, 0, 1))).normalized() * width
    mid = start.lerp(end, .48)
    ridge = mid + Vector((0, 0, .09))
    vertices = [start, mid + side, end, mid - side, ridge]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)])
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    assign(obj, mat)
    solid = obj.modifiers.new('Leaf thickness', 'SOLIDIFY')
    solid.thickness = .009
    sub = obj.modifiers.new('Organic leaf surface', 'SUBSURF')
    sub.levels = 2
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    tube('Leaf vein', [start, ridge + Vector((0, 0, .006)), end], gold, .006)


for index, (dx, dy, height, lift) in enumerate(((-.66, .04, .28, .17), (.62, -.08, .41, .23),
                                              (-.5, .09, .68, .27), (.43, .13, .83, .27))):
    start = (px + .015, py, stem_base + height)
    end = (px + dx, py + dy, stem_base + height + lift)
    leaf('Botanical study leaf', start, end, .23 if index < 2 else .17,
         leaves if index % 2 else leaf_light)

# Rolled sketches, folios, calipers, and one restrained lantern.
for i, (z, angle) in enumerate(((1.83, .14), (1.98, -.06))):
    obj = box('Closed archival folio', (1.6, .32, z), (.62, 1.1, .13), leather if i else wood, .025)
    obj.rotation_euler[2] = angle
    for j in range(3):
        stripe = box('Folio binding', (1.63 + (j - 1) * .12, -.24, z), (.022, .022, .13), gold, .003)
scroll = cylinder('Rolled ivory drawing', (-1.85, .26, 1.98), .10, 1.04, paper)
scroll.rotation_euler = (math.pi / 2, 0, -.2)
ring('Drafting lens', (.8, -.53, 1.97), .2, gold_light, .018)
tube('Drafting lens handle', [(1, -.55, 1.97), (1.32, -.7, 1.97)], gold, .035)
candle(1.93, -.74, 1.79, .73)

# Armillary instrument behind the table: a physical brass instrument, not a hologram.
ax, ay, az = -2.8, 2.05, 2.25
cylinder('Armillary base', (ax, ay, .17), .65, .32, wood)
cylinder('Armillary stem', (ax, ay, .96), .08, 1.37, gold)
for tilt, turn in ((math.pi / 2, 0), (.65, .4), (1.18, -.5), (0, 0)):
    ring('Armillary brass orbit', (ax, ay, az), .87, gold, .029, (tilt, 0, turn))
sphere('Armillary globe', (ax, ay, az), .24, gold)
tube('Armillary axis', [(ax, ay, az - 1), (ax, ay, az + 1)], gold, .03)
for x, y, height in ((3.1, 2.6, 1.8), (-3.7, 3.4, 1.4), (4.6, -.5, 1.2)):
    cylinder('Candle pedestal', (x, y, height / 2), .21, height, stone)
    candle(x, y, height + .02, .7)

area('Warm candlelit key', (-3.4, -3.2, 5.5), (0, 0, 1.6), (1, .66, .31), 680, 4.0)
area('Moonlit arch fill', (1.8, 5.4, 7.0), (0, -.2, 2), (.28, .45, 1), 1100, 5)
area('Soft neutral face of the study', (4.2, -5.5, 5.5), (0, 0, 1.8), (.78, .81, 1), 380, 5)
area('Amber rim on brass', (-4, 3.3, 4), (0, .1, 2), (1, .39, .12), 340, 3)

scene = bpy.context.scene
world = bpy.data.worlds.new('Moonlit ambient')
world.use_nodes = True
world.node_tree.nodes.get('Background').inputs[0].default_value = (.09, .115, .2, 1)
world.node_tree.nodes.get('Background').inputs[1].default_value = .16
scene.world = world

bpy.ops.object.camera_add(location=(6.3, -10.6, 6.4))
camera = bpy.context.object
camera.name = 'Courtyard study camera'
target = Vector((-.05, .4, 2.75))
camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'PERSP'
camera.data.lens = 39
camera.data.dof.use_dof = True
camera.data.dof.focus_distance = (Vector((-.35, 0, 2.5)) - camera.location).length
camera.data.dof.aperture_fstop = 7.1
scene.camera = camera
scene.render.engine = 'CYCLES'
scene.cycles.samples = options.samples
# This laptop's denoiser exhausts available memory. Converge the actual render
# with more samples instead of relying on a failed denoising pass.
scene.cycles.use_denoising = False
scene.cycles.adaptive_threshold = .008
try:
    preferences = bpy.context.preferences.addons['cycles'].preferences
    preferences.compute_device_type = 'CUDA'
    preferences.get_devices()
    found_gpu = False
    for device in preferences.devices:
        device.use = device.type == 'CUDA'
        found_gpu = found_gpu or device.use
    if found_gpu:
        scene.cycles.device = 'GPU'
except Exception:
    scene.cycles.device = 'CPU'
scene.render.resolution_x = options.size
scene.render.resolution_y = round(options.size * .75)
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGB'
scene.render.image_settings.color_depth = '8'
scene.render.film_transparent = False
scene.view_settings.view_transform = 'AgX'
scene.view_settings.look = 'AgX - Medium High Contrast'
scene.view_settings.exposure = .05
scene.render.filepath = str(options.output / 'leonidas-garden-blender-v1.png')
scene['authoring'] = 'Original procedural Blender geometry and materials, authored for Leo Investing.'
scene['story'] = 'garden-v1 / The Unfinished Garden'
scene['visual_contract'] = 'Moonlight, candlelight, aubergine stone, brass, walnut, unfinished garden study; existing Leonidas portraits remain separate.'
scene['motion'] = 'Runtime slow camera drift, with pause, reduced-motion and lifecycle guards.'
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(options.output / 'leonidas-garden-v1.blend'))
bpy.ops.render.render(write_still=True)
png = Path(scene.render.filepath)
png_bytes = png.read_bytes()
provenance = ('Source\x00Original Blender 4.5 scene, build_garden.py; '
              'procedural geometry and materials for Leo Investing. '
              'Moonlit observatory courtyard and unfinished garden study. '
              'No third-party or AI-generated assets.').encode('latin-1')
chunk = b'tEXt' + provenance
png.write_bytes(png_bytes[:33] + struct.pack('>I', len(provenance)) + chunk +
                struct.pack('>I', zlib.crc32(chunk) & 0xffffffff) + png_bytes[33:])
(options.output / 'provenance.json').write_text(json.dumps({
    'asset': 'leonidas-garden-blender-v1.png',
    'source': 'leonidas-garden-v1.blend',
    'generator': 'build_garden.py',
    'renderer': bpy.app.version_string,
    'render_engine': 'Cycles',
    'samples': options.samples,
    'dimensions': [scene.render.resolution_x, scene.render.resolution_y],
    'third_party_assets': [],
    'description': scene['visual_contract'],
}, indent=2) + '\n', encoding='utf-8')
print('LEO_GARDEN_RENDER_COMPLETE', scene.render.filepath, flush=True)
