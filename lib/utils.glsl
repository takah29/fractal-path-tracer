#define EPS 0.0001
#define INF 1e20
#define PI 3.14159265

const vec3 RED = vec3(1.0, 0.0, 0.0);
const vec3 GREEN = vec3(0.0, 1.0, 0.0);
const vec3 BLUE = vec3(0.0, 0.0, 1.0);
const vec3 CYAN = vec3(0.0, 1.0, 1.0);
const vec3 MAGENTA = vec3(1.0, 0.0, 1.0);
const vec3 YELLOW = vec3(1.0, 1.0, 0.0);
const vec3 WHITE = vec3(1.0, 1.0, 1.0);
const vec3 GRAY = vec3(0.5, 0.5, 0.5);
const vec3 BLACK = vec3(0.0, 0.0, 0.0);

struct Camera {
    vec3 pos;
    vec3 dir;
    vec3 right;
    vec3 top;
    float angle;
};

struct Ray {
    vec3 o;
    vec3 d;
};

struct Material {
    vec4 color_param;  // vec3: color, float: param
    int type;          // 0: diffuse, 1: reflection, 2: refrection, 3: emission
};

struct HitPoint {
    float t;
    int mtl_id;  // -1:background
};

// random
float hash1(inout float seed) { return fract(sin(seed += 0.1) * 43758.5453123); }
vec2 hash2(inout float seed) { return fract(sin(vec2(seed += 0.1, seed += 0.1)) * vec2(43758.5453123, 22578.1459123)); }
vec3 hash3(inout float seed) {
    return fract(sin(vec3(seed += 0.1, seed += 0.1, seed += 0.1)) * vec3(43758.5453123, 22578.1459123, 19642.3490423));
}

// sampling
vec3 cos_weighted_random_hemisphere_direction(const vec3 n, inout float seed) {
    vec2 r = hash2(seed);

    vec3 uu = normalize(cross(n, vec3(0.0, 1.0, 1.0)));
    vec3 vv = cross(uu, n);

    float ra = sqrt(r.y);
    float rx = ra * cos(6.2831 * r.x);
    float ry = ra * sin(6.2831 * r.x);
    float rz = sqrt(1.0 - r.y);
    vec3 rr = vec3(rx * uu + ry * vv + rz * n);

    return normalize(rr);
}

vec3 random_sphere_direction(inout float seed) {
    vec2 h = hash2(seed) * vec2(2., 6.28318530718) - vec2(1, 0);
    float phi = h.y;
    return vec3(sqrt(1. - h.x * h.x) * vec2(sin(phi), cos(phi)), h.x);
}

vec3 sample_lens(in Camera camera, in float seed, in float dof_size) {
    vec2 r = hash2(seed);
    return camera.pos + (camera.right * r.r * cos(2. * PI * r.t) + camera.top * r.r * sin(2. * PI * r.t)) * dof_size;
}

vec3 get_brdf_ray(in vec3 n, const in vec3 rd, const in Material m, inout bool specular_bounce, inout float seed) {
    specular_bounce = false;

    if (m.type == 1) {  // reflaction
        vec3 ref;
        if (hash1(seed) < m.color_param.w) {
            specular_bounce = true;
            ref = reflect(rd, n);
        } else {
            ref = cos_weighted_random_hemisphere_direction(n, seed);
        }
        return ref;
    } else if (m.type == 2) {  // refraction
        specular_bounce = true;

        float n1, n2, ndotr = dot(rd, n);

        if (ndotr > 0.) {
            n1 = 1.0;
            n2 = m.color_param.w;
            n = -n;
        } else {
            n1 = m.color_param.w;
            n2 = 1.0;
        }

        float r0 = (n1 - n2) / (n1 + n2);
        r0 *= r0;
        float fresnel = r0 + (1. - r0) * pow(1.0 - abs(ndotr), 5.);

        vec3 ref = refract(rd, n, n2 / n1);
        if (ref == vec3(0) || hash1(seed) < fresnel) {
            ref = reflect(rd, n);
        }

        return ref;
    } else {  // diffuse
        return cos_weighted_random_hemisphere_direction(n, seed);
    }
}

void look_at_origin(inout Camera camera, in vec3 pos) {
    camera.pos = pos;
    camera.dir = -normalize(camera.pos);
    vec3 up = vec3(0.0, 1.0, 0.0);
    camera.right = normalize(cross(camera.dir, up));
    camera.top = normalize(cross(camera.right, camera.dir));
}

Ray get_ray(in Camera camera, in vec2 coord) {
    float fov = camera.angle * 0.5 * PI / 180.0;
    float sin_fov = sin(fov);
    vec3 dir = normalize(camera.dir * cos(fov) + camera.right * coord.x * sin_fov + camera.top * coord.y * sin_fov);
    return Ray(camera.pos, dir);
}
