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
#define ITER 64
float intersect(in Torus torus, in Ray ray) {
    float d = 0.0;
    float t = 0.0;
    vec3 pos = ray.o;

    // marching loop
    int s;
    for (s = 0; s < ITER; s++) {
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
