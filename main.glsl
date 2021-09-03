#include "lib/object.glsl"

#iUniform int SAMPLES = 12 in{2, 200 }
#iUniform float speed = 4.0 in{0.0, 50.0 }
#iUniform float focal_length = 9.5 in{1.0, 20.0 }
#iUniform float dof_size = 0.5 in{0.0, 2.0 }
#iUniform float amount_of_light = 1.0 in{0.0, 10. }

// scene parameters
const int MAX_DEPTH = 4;
const float MOTIONBLURFPS = 12.;

// material
const Material LIGHT_MTL = Material(vec4(vec3(20.0, 15.0, 10.0), 1.0), 0);
const Material WHITE_MTL = Material(vec4(GRAY, 0.0), 1);
const Material RED_MTL = Material(vec4(RED * 0.7 + 0.1, 0.0), 1);
const Material GREEN_MTL = Material(vec4(GREEN * 0.7 + 0.1, 0.0), 1);
const Material BLUE_MTL = Material(vec4(BLUE * 0.7 + 0.1, 0.0), 1);
const Material REFLECTION_MTL = Material(vec4(CYAN, 0.3), 2);
const Material REFRACTION_MTL = Material(vec4(vec3(0.1, 0.0, 0.8), 1.5), 3);
Material[7] materials = Material[](LIGHT_MTL, WHITE_MTL, RED_MTL, GREEN_MTL, BLUE_MTL, REFLECTION_MTL, REFRACTION_MTL);

// scene
const Plane b_plane = Plane(vec3(0.0, 1.0, 0.0), -3.0);
const Plane d_plane = Plane(vec3(0.0, 0.0, 1.0), -5.0);
const Plane l_plane = Plane(vec3(1.0, 0.0, 0.0), -3.0);
const Plane t_plane = Plane(vec3(0.0, -1.0, 0.0), -3.0);
const Plane r_plane = Plane(vec3(-1.0, 0.0, 0.0), -3.0);
const Plane[5] planes = Plane[](b_plane, d_plane, l_plane, t_plane, r_plane);
const int[5] p_mtl_ids = int[](1, 1, 2, 1, 3);

const Sphere l_sphere = Sphere(vec3(-1.0, -2.0, -1.0), 1.0);
const Sphere r_sphere = Sphere(vec3(1.5, -2.0, 0.0), 1.0);
const Sphere[2] spheres = Sphere[](l_sphere, r_sphere);
const int[2] s_mtl_ids = int[](6, 5);

Sphere light_sphere = Sphere(vec3(0.0), 0.5);
Torus torus = Torus(vec3(0.0, -1.0, 2.), 1.5, 0.5);

void set_light_pos(float time) {
    float t = time * speed;
    light_sphere.center = vec3(2. * sin(t), 2. * sin(t * 0.9), 3. * cos(t * 0.7));
}

HitPoint intersect_scene(in Ray ray, inout vec3 normal) {
    HitPoint hp = HitPoint(INF, -1);
    float t;

    for (int i = 0; i < planes.length(); i++) {
        t = intersect(planes[i], ray);
        update_hp(planes[i], t, p_mtl_ids[i], hp, normal);
    }
    for (int i = 0; i < spheres.length(); i++) {
        t = intersect(spheres[i], ray);
        update_hp(spheres[i], ray, t, s_mtl_ids[i], hp, normal);
    }

    t = intersect(light_sphere, ray);
    update_hp(r_sphere, ray, t, 0, hp, normal);

    // t = intersect(torus, ray);
    // update_hp(torus, ray, t, 1, hp, normal);

    return hp;
}

bool intersect_shadow(in Ray ray, in float dist) {
    float t;

    t = intersect(l_sphere, ray);
    if (t > EPS && t < dist) return true;
    t = intersect(r_sphere, ray);
    if (t > EPS && t < dist) return true;
    // t = intersect(torus, ray);
    // if (t > EPS && t < dist) return true;

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
            if (specular_bounce) tcol += fcol * materials[hp.mtl_id].color_param.rgb * amount_of_light;
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

            tcol +=
                (fcol * materials[0].color_param.rgb * amount_of_light) * (weight * clamp(dot(nld, normal), 0., 1.));
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

        // motion blur
        set_light_pos(iTime + hash1(seed) / MOTIONBLURFPS);

        color += path_trace(ray, seed);
        seed = mod(seed * 1.1234567893490423, 13.);
    }

    color /= float(SAMPLES);
    return color;
}

//-----------------------------------------------------
// main
//-----------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 q = fragCoord.xy / iResolution.xy;

    vec2 p = -1.0 + 2.0 * (fragCoord.xy) / iResolution.xy;
    p.x *= iResolution.x / iResolution.y;

    // noise
    float seed = p.x + p.y * 3.43121412313 + fract(1.12345314312 * iTime);

    vec2 mouse = (iMouse.xy / iResolution.xy) * 6.0 - 3.0;
    vec3 c_pos = vec3(-mouse, 8.0);
    vec3 dir = vec3(0.0, 0.0, -1.0);
    vec3 right = vec3(1.0, 0.0, 0.0);
    vec3 top = vec3(0.0, 1.0, 0.0);

    Camera camera = Camera(c_pos, dir, right, top, 50.0);
    look_at_origin(camera, c_pos);

    vec3 color = render(p, camera, seed);
    color = pow(clamp(color, 0.0, 1.0), vec3(0.45));

    fragColor = vec4(color, 1.0);
}