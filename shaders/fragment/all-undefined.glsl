#version 430

// WARNING : This shader is only used to allow undefined behaviour
// It is a copy of shader `all.glsl'. You sould NEVER code into.


// FIXME : remove light structs from all.glsl
struct Material // Use vec3 instead of sampler2D to avoid expensive copy of data
{
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
    float shininess;
};

struct DirLight
{
    vec3 dir;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};

struct PointLight
{
    vec3 pos;

    float constant;
    float linear;
    float quadratic;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};

#define NB_DIR_LIGHTS 1
#define NB_POINT_LIGHTS 2



in vec4 interpolated_pos;
in vec3 interpolated_normal;
in vec4 interpolated_color;
in vec2 interpolated_tex_coords;
in mat3 TBN;

out vec4 output_color;

uniform DirLight dir_lights[NB_DIR_LIGHTS];
uniform PointLight point_lights[NB_POINT_LIGHTS];

uniform sampler2D texture_ambient1;
uniform sampler2D texture_diffuse1;
uniform sampler2D texture_specular1;
uniform sampler2D texture_normal1;

uniform float total_time;

uniform vec3 camera_pos;
uniform int mesh_id;
uniform int rand;

uniform int FXFrag;
uniform int factory_level_render;

#define PI = 3.1415926535;

const int UNDEFINED              = 1 << 0; // E
const int COMPUTE_LIGHT          = 1 << 1; // R
const int TEX_MOVE               = 1 << 2; // Y
const int TEX_MOVE_GLITCH        = 1 << 3; // U
const int COLORIZE               = 1 << 4; // I
const int TEX_RGB_SPLIT          = 1 << 5; // O
const int EDGE_ENHANCE           = 1 << 6; // P
const int TOONIFY                = 1 << 7; // G
const int HORRORIFY              = 1 << 8; // H
const int PIXELIZE               = 1 << 9; // J


float snoise(vec2 v);
float snoise(vec3 v);
float snoise(vec4 v);

vec3 tex_move_glitch(vec2 uv,
sampler2D light_texture,
float total_time,
int mesh_id, int rand,
int rate);

vec4 compute_lights(vec4 interpolated_pos, vec3 interpolated_normal,
vec3 camera_pos, vec4 color_org,
Material material,
DirLight dir_lights[NB_DIR_LIGHTS],
PointLight point_lights[NB_POINT_LIGHTS]);

vec4 colorize(vec4 interpolated_pos, vec3 normal,
float total_time,
int mesh_id, int rand,
vec4 color_org, int level);

vec3 tex_rgb_split(vec2 uv,
sampler2D light_texture,
float total_time,
int rand);

vec4 edge_enhance(vec2 uv,
sampler2D texture_diffuse1,
float total_time,
vec4 color_org, float edge_threshold, bool colorize);

vec4 toonify(vec4 color_org);

vec4 horrorify(vec2 uv,
sampler2D texture_diffuse1,
float total_time,
int mesh_id, int rand,
vec4 color_org, bool colorize);

vec3 pixelize(vec2 uv,
sampler2D light_texture,
float total_time);

vec2 uv;

vec4 apply_effects(vec4 output_color, int FX)
{
    if (bool(FX & TEX_MOVE))
    uv += 0.1 * total_time;

    Material material;
    if (bool(FX & TEX_MOVE_GLITCH))
    {
        material.ambient = tex_move_glitch(uv, texture_ambient1, total_time, mesh_id, rand, 1);
        material.diffuse = tex_move_glitch(uv, texture_diffuse1, total_time, mesh_id, rand, 1);
        material.specular = tex_move_glitch(uv, texture_specular1, total_time, mesh_id, rand, 1);
    }
    else if (bool(FX & TEX_RGB_SPLIT))
    {
        material.ambient = tex_rgb_split(uv, texture_ambient1, total_time, rand);
        material.diffuse = tex_rgb_split(uv, texture_diffuse1, total_time, rand);
        material.specular = tex_rgb_split(uv, texture_specular1, total_time, rand);
    }
    else if (bool(FX & PIXELIZE))
    {
        material.ambient = pixelize(uv, texture_ambient1, total_time);
        material.diffuse = pixelize(uv, texture_diffuse1, total_time);
        material.specular = pixelize(uv, texture_specular1, total_time);
    }
    else
    {
        material.ambient = vec3(texture(texture_ambient1, uv));
        material.diffuse = vec3(texture(texture_diffuse1, uv));
        material.specular = vec3(texture(texture_specular1, uv));
    }

    vec3 normal = interpolated_normal;
    normal = texture(texture_normal1, uv).rgb;
    normal = normalize(normal * 2.0 - 1.0);
    normal = normalize(TBN * normal);
    /* ------------------------------------------------------- */
    /* ------------------------------------------------------- */

    if (bool(FX & COMPUTE_LIGHT))
    {
        material.shininess = 20; //FIXME: get value from assimp

        output_color = compute_lights(interpolated_pos, interpolated_normal,
        camera_pos, output_color,
        material,
        dir_lights,
        point_lights);
    }


    if (bool(FX & COLORIZE))
    output_color = colorize(interpolated_pos, normal, total_time, mesh_id, rand, output_color, 3);

    if (bool(FX & EDGE_ENHANCE))
    output_color = edge_enhance(uv, texture_diffuse1, total_time, output_color, 0.55, true);

    if (bool(FX & TOONIFY))
    {
        output_color = toonify(output_color);
        output_color = edge_enhance(uv, texture_diffuse1, total_time, output_color, 0.35, false);
    }

    if (bool(FX & HORRORIFY))
    output_color = horrorify(uv, texture_diffuse1, total_time, mesh_id, rand, output_color, true);

    /* ------------------------------------------------------- */
    /* ------------------------------------------------------- */

    return output_color;
}

void main()
{
    uv = interpolated_tex_coords;

    /* ------------------------------------------------------- */
    /* ------------------------------------------------------- */

    int nb_loop = 1;
    int FX = FXFrag;

    if (factory_level_render != 0)
    nb_loop = 3;

    for (int i = 0; i < nb_loop; ++i)
    {
        if (factory_level_render == 1)
        FX = int(abs(cos(uv.y * i)) * (1 << 10));
        else if (factory_level_render == 2)
        FX = int(abs(cos(uv.x * i)) * (1 << 10));
        else if (factory_level_render == 3)
        FX = int(abs(cos(length(uv - 0.5) * i)) * (1 << 10));
        else if (factory_level_render == 4)
        FX = int(abs(cos(length(camera_pos / 200))) * (1 << 10));
        else if (factory_level_render == 5)
        FX = int(abs(cos(rand * i)) * (1 << 10));

        output_color = apply_effects(output_color, FX);
    }
}