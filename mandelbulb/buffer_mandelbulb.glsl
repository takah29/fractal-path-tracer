#iChannel0 "self"
#include "../lib/object.glsl"

#iUniform float dist = 1.0 in{0.5, 3.0 }
#iUniform float focal_length = 0.5 in{0.001, 5.0 }
#iUniform float dof_size = 0.005 in{0.001, 0.5 }
#iUniform float light_emission = 1.0 in{0.001, 5. }

// scene parameters
const int SAMPLES = 1;
const int MAX_DEPTH = 5;

// material
const Material LIGHT_MTL = Material(vec4(vec3(20.0, 15.0, 10.0), 1.0), 0);
const Material WHITE_MTL = Material(vec4(WHITE, 0.0), 1);
const Material RED_MTL = Material(vec4(RED * 0.7 + 0.1, 0.0), 1);
const Material GREEN_MTL = Material(vec4(GREEN * 0.7 + 0.1, 0.0), 1);
const Material BLUE_MTL = Material(vec4(BLUE * 0.7 + 0.3, 0.0), 1);
const Material REFLECTION_MTL = Material(vec4(CYAN * 0.5 + 0.2, 0.5), 2);
const Material CC = Material(vec4(0.0), 1);
Material[7] materials = Material[7](LIGHT_MTL, WHITE_MTL, RED_MTL, GREEN_MTL, BLUE_MTL, REFLECTION_MTL, CC);

// scene
const Plane b_plane = Plane(vec3(0.0, 1.0, 0.0), -5.0);
const Plane d_plane = Plane(vec3(0.0, 0.0, 1.0), -5.0);
const Plane f_plane = Plane(vec3(0.0, 0.0, -1.0), -10.0);
const Plane l_plane = Plane(vec3(1.0, 0.0, 0.0), -5.0);
const Plane r_plane = Plane(vec3(-1.0, 0.0, 0.0), -5.0);
const Plane t_plane = Plane(vec3(0.0, -1.0, 0.0), -5.0);
const Plane[6] planes = Plane[](b_plane, d_plane, f_plane, l_plane, r_plane, t_plane);
const int[6] p_mtl_ids = int[](1, 4, 1, 2, 3, 1);

Sphere light_sphere = Sphere(vec3(0.0, 4.0, 0.0), 1.0);
Mandelbulb mb = Mandelbulb(8.0, 12);

// Mandelbulb color definition
const vec3 lowcol = vec3(0.1, 0.2, 0.4);
const vec3 middlecol = vec3(0.1, 0.1, 0.3);
const vec3 highcol = vec3(0.3, 0.05, 0.02);
Material mb_mtl = Material(vec4(0.0), 1);

HitPoint intersect_scene(in Ray ray, inout vec3 normal) {
    HitPoint hp = HitPoint(INF, -1);
    float t;

    for (int i = 0; i < planes.length(); i++) {
        t = intersect(planes[i], ray);
        update_hp(planes[i], t, p_mtl_ids[i], hp, normal);
    }

    vec4 res_color;
    t = intersect(mb, ray, 256, res_color);
    vec3 col = trap_to_color(res_color, lowcol, middlecol, highcol);
    mb_mtl.color_param = vec4(col, 0.0);
    materials[6] = mb_mtl;
    update_hp(mb, ray, t, 6, hp, normal);

    t = intersect(light_sphere, ray);
    update_hp(light_sphere, ray, t, 0, hp, normal);

    return hp;
}

bool intersect_shadow(in Ray ray, in float dist) {
    float t;

    vec4 dummy_res_color;
    t = intersect(mb, ray, 128, dummy_res_color);
    if (t > EPS && t < dist) return true;

    return false;
}

vec3 path_trace(in Ray ray, inout float seed) {
    vec3 tcol = vec3(0.);
    vec3 fcol = vec3(1.);
    bool specular_bounce = true;

    for (int depth = 0; depth < MAX_DEPTH; depth++) {
        vec3 normal;
        HitPoint hp = intersect_scene(ray, normal);

        // background
        if (hp.mtl_id == -1) {
            return tcol;
        }

        // light
        if (materials[hp.mtl_id].type == 0) {  // emission
            if (specular_bounce) tcol += fcol * materials[hp.mtl_id].color_param.rgb * light_emission;
            return tcol;
        }

        // indirect
        ray.o = ray.o + hp.t * ray.d;
        ray.d = get_brdf_ray(normal, ray.d, materials[hp.mtl_id], specular_bounce, seed);

        if (!specular_bounce || dot(ray.d, normal) < 0.) {
            fcol *= materials[hp.mtl_id].color_param.rgb;
        }

        // direct light sampling
        vec3 ld = sample_light(light_sphere, seed) - ray.o;
        vec3 nld = normalize(ld);
        bool is_shadow = intersect_shadow(Ray(ray.o, nld), length(ld));
        if (!specular_bounce && depth < (MAX_DEPTH - 1) && !is_shadow) {
            float tmp = light_sphere.radius * light_sphere.radius /
                        dot(light_sphere.center - ray.o, light_sphere.center - ray.o);
            float cos_a_max = sqrt(1. - clamp(tmp, 0., 1.));
            float weight = 2. * (1. - cos_a_max);

            tcol += (fcol * materials[0].color_param.rgb * light_emission) * (weight * clamp(dot(nld, normal), 0., 1.));
        }
    }
    return tcol;
}

vec3 render(in vec2 p, in Camera camera, in float seed) {
    vec3 color = vec3(0.0);
    for (int a = 0; a < SAMPLES; a++) {
        Ray ray = get_ray(camera, p);

        // depth of field
        vec3 fp = ray.o + ray.d * focal_length;
        ray.o = sample_lens(camera, seed, dof_size);
        ray.d = normalize(fp - ray.o);

        color += path_trace(ray, seed);
        seed = mod(seed * 1.1234567893490423, 13.);
    }

    color /= float(SAMPLES);
    return color;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord.xy / iResolution.xy;

    vec2 p = -1.0 + 2.0 * (fragCoord.xy) / iResolution.xy;
    p.x *= iResolution.x / iResolution.y;

    // noise
    float seed = p.x + p.y * 3.43121412313 + fract(1.12345314312 * iTime);

    vec2 mouse = (iMouse.xy / iResolution.xy) * 6.0 - 3.0;
    vec3 c_pos = vec3(-mouse, dist);
    vec3 dir = vec3(0.0, 0.0, -1.0);
    vec3 right = vec3(1.0, 0.0, 0.0);
    vec3 top = vec3(0.0, 1.0, 0.0);

    Camera camera = Camera(c_pos, dir, right, top, 50.0);
    look_at_origin(camera, c_pos);

    vec3 color = render(p, camera, seed);
    color = pow(clamp(color, 0.0, 1.0), vec3(0.45));

    bool is_init = iMouseButton.x != 0.0;
    if (is_init) {
        fragColor = vec4(color, 1);
    } else {
        fragColor = vec4(color, 1) + texelFetch(iChannel0, ivec2(fragCoord), 0);
    }
}