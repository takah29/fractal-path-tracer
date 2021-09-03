#include "utils.glsl"

// Sphere
struct Sphere {
    vec3 center;
    float radius;
};

float intersect(in Sphere sphere, in Ray ray) {
    vec3 oc = ray.o - sphere.center;
    float b = dot(oc, ray.d);
    float c = dot(oc, oc) - sphere.radius * sphere.radius;
    float h = b * b - c;
    if (h < 0.0) return -1.0;

    float s = sqrt(h);
    float t1 = -b - s;
    float t2 = -b + s;

    return t1 < 0.0 ? t2 : t1;
}

vec3 get_normal(in Sphere sphere, in vec3 p) { return normalize(p - sphere.center); }

void update_hp(in Sphere sphere, in Ray ray, in float t, in int color_id, inout HitPoint hp, inout vec3 normal) {
    if (t > EPS && t < hp.t) {
        hp = HitPoint(t, color_id);
        normal = get_normal(sphere, ray.o + t * ray.d);
    }
}

vec3 sample_light(in Sphere point_light, inout float seed) {
    vec3 n = random_sphere_direction(seed) * point_light.radius;
    return point_light.center + n;
}

// Plane
struct Plane {
    vec3 normal;
    float h;
};

float intersect(in Plane plane, in Ray ray) { return (plane.h - dot(plane.normal, ray.o)) / dot(plane.normal, ray.d); }

vec3 get_normal(in Plane plane) { return plane.normal; }

void update_hp(in Plane plane, in float t, in int color_id, inout HitPoint hp, inout vec3 normal) {
    if (t > EPS && t < hp.t) {
        hp = HitPoint(t, color_id);
        normal = get_normal(plane);
    }
}

// Torus (Ray marching)
struct Torus {
    vec3 center;
    float radius_a;
    float radius_b;
};
float distance_func(in Torus torus, in vec3 p) {
    vec2 q = vec2(length(p.xz - torus.center.xz) - torus.radius_a, p.y - torus.center.y);
    return length(q) - torus.radius_b;
}
float intersect(in Torus torus, in Ray ray, in int n_iter) {
    float d = 0.0;
    float t = 0.0;
    vec3 pos = ray.o;

    // marching loop
    int s;
    for (s = 0; s < n_iter; s++) {
        d = distance_func(torus, pos);
        t += d;
        pos = ray.o + t * ray.d;

        // hit check
        if (abs(d) < 0.0001) {
            break;
        }
    }

    return t;
}
vec3 get_normal(in Torus torus, in vec3 p) {
    const float ep = 0.001;
    vec2 e = vec2(1.0, -1.0) * 0.5773;
    return normalize(e.xyy * distance_func(torus, p + e.xyy * ep) + e.yyx * distance_func(torus, p + e.yyx * ep) +
                     e.yxy * distance_func(torus, p + e.yxy * ep) + e.xxx * distance_func(torus, p + e.xxx * ep));
}
void update_hp(in Torus torus, in Ray ray, in float t, in int color_id, inout HitPoint hp, inout vec3 normal) {
    if (t > EPS && t < hp.t) {
        hp = HitPoint(t, color_id);
        normal = get_normal(torus, ray.o + t * ray.d);
    }
}

// MandelBox
struct MandelBox {
    float scale;
    float min_radius;
    float fixed_radius;
    int iterations;
};
float distance_estimate(in MandelBox mb, in vec3 p) {
    vec3 z = p;
    float dr = 1.0;
    for (int i = 0; i < mb.iterations; i++) {
        // Box Fold
        float folding_limit = 1.0;
        z = clamp(z, -folding_limit, folding_limit) * 2.0 - z;

        // Sphere Fold
        float m2 = mb.min_radius * mb.min_radius;
        float f2 = mb.fixed_radius * mb.fixed_radius;
        float r2 = dot(z, z);
        if (r2 < m2) {
            float temp = (f2 / m2);
            z *= temp;
            dr *= temp;
        } else if (r2 < f2) {
            float temp = (f2 / r2);
            z *= temp;
            dr *= temp;
        }

        z = mb.scale * z + p;
        dr = dr * abs(mb.scale) + 1.0;
    }
    float r = length(z);
    return r / abs(dr);
}

float intersect(in MandelBox mb, in Ray ray, in int n_iter) {
    float d = 0.0;
    float t = 0.0;
    vec3 pos = ray.o;

    // marching loop
    int s;
    for (s = 0; s < n_iter; s++) {
        d = distance_estimate(mb, pos);
        t += d;
        pos = ray.o + t * ray.d;

        // hit check
        if (abs(d) < t * 0.001) {
            return t;
        }
    }

    return INF;
}
vec3 get_normal(in MandelBox mb, in vec3 p) {
    const float ep = 0.001;
    vec2 e = vec2(1.0, -1.0) * 0.5773;
    return normalize(e.xyy * distance_estimate(mb, p + e.xyy * ep) + e.yyx * distance_estimate(mb, p + e.yyx * ep) +
                     e.yxy * distance_estimate(mb, p + e.yxy * ep) + e.xxx * distance_estimate(mb, p + e.xxx * ep));
}
void update_hp(in MandelBox mb, in Ray ray, in float t, in int color_id, inout HitPoint hp, inout vec3 normal) {
    if (t > EPS && t < hp.t) {
        hp = HitPoint(t, color_id);
        normal = get_normal(mb, ray.o + t * ray.d);
    }
}

// Mandelbulb
struct Mandelbulb {
    float power;
    int iterations;
};
float distance_estimate(in Mandelbulb mb, in vec3 p, out vec4 res_color) {
    vec3 w = p;
    float m = dot(w, w);

    vec4 trap = vec4(abs(w), m);
    float dz = 1.0;

    for (int i = 0; i < mb.iterations; i++) {
        // trigonometric version

        // dz = 8*z^7*dz
        dz = 8.0 * pow(m, 3.5) * dz + 1.0;
        // dz = 8.0*pow(sqrt(m),7.0)*dz + 1.0;

        // z = z^8+z
        float r = length(w);
        float b = mb.power * acos(w.y / r);
        float a = mb.power * atan(w.x, w.z);
        w = p + pow(r, 8.0) * vec3(sin(b) * sin(a), cos(b), sin(b) * cos(a));

        trap = min(trap, vec4(abs(w), m));

        m = dot(w, w);
        if (m > 256.0) break;
    }

    res_color = vec4(m, trap.yzw);

    // distance estimation (through the Hubbard-Douady potential)
    return 0.25 * log(m) * sqrt(m) / dz;
}
vec3 trap_to_color(in vec4 trap, in vec3 lowcol, in vec3 middlecol, in vec3 highcol) {
    vec3 color = vec3(0.01);
    color = mix(color, lowcol, clamp(trap.y, 0.0, 1.0));
    color = mix(color, middlecol, clamp(trap.z * trap.z, 0.0, 1.0));
    color = mix(color, highcol, clamp(pow(trap.w, 6.0), 0.0, 1.0));
    color *= 5.0;
    return color;
}
float intersect(in Mandelbulb mb, in Ray ray, in int n_iter, inout vec4 res_color) {
    float d = 0.0;
    float t = 0.0;
    vec3 pos = ray.o;

    // marching loop
    int s;
    for (s = 0; s < n_iter; s++) {
        d = distance_estimate(mb, pos, res_color);
        t += d;
        pos = ray.o + t * ray.d;

        // hit check
        if (abs(d) < t * 0.0005) {
            return t;
        }
    }

    return INF;
}
vec3 get_normal(in Mandelbulb mb, in vec3 p) {
    const float ep = 0.001;
    vec2 e = vec2(1.0, -1.0) * 0.5773;
    vec4 dummy_res_color;
    return normalize(e.xyy * distance_estimate(mb, p + e.xyy * ep, dummy_res_color) +
                     e.yyx * distance_estimate(mb, p + e.yyx * ep, dummy_res_color) +
                     e.yxy * distance_estimate(mb, p + e.yxy * ep, dummy_res_color) +
                     e.xxx * distance_estimate(mb, p + e.xxx * ep, dummy_res_color));
}
void update_hp(in Mandelbulb mb, in Ray ray, in float t, in int color_id, inout HitPoint hp, inout vec3 normal) {
    if (t > EPS && t < hp.t) {
        hp = HitPoint(t, color_id);
        normal = get_normal(mb, ray.o + t * ray.d);
    }
}
