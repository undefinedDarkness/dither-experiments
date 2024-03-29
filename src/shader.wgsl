@group(0) @binding(0) var input : texture_2d<f32>;
@group(0) @binding(1) var result: texture_storage_2d<rgba8unorm, write>;
@group(0) @binding(2) var palette: texture_2d<f32>;

@group(0) @binding(3) var lutW: texture_storage_3d<rgba8unorm, write>;

@group(0) @binding(4) var lut: texture_3d<f32>;
@group(0) @binding(5) var lutSampler: sampler;

fn invert(in: vec4f) -> vec4f {
    return vec4f(1.0, 1.0, 1.0, 2.0) - in;
}

fn invertLumen(in: vec4f) -> vec4f {
    return vec4f(1.0) - vec4f(dot(in.xyz, vec3f(0, 0.5, 0.5)), dot(in.xyz, vec3f(0.5, 0, 0.5)), dot(in.xyz, vec3f(0.5, 0.5, 0)), 1.0);
}

fn grayscale(in: vec4f) -> f32 {
    return dot(in.xyz, vec3f(0.299, 0.587, 0.114));
}

fn sobel(my: vec2u) -> vec4f {
    // TODO: Move the grayscaling to a different shader
    let a = mat3x3f(
        grayscale(textureLoad(input, my - vec2u(1, 1), 0)), // 1x1
        grayscale(textureLoad(input, my - vec2u(1, 0), 0)),
        grayscale(textureLoad(input, my + vec2u(0, 1) - vec2u(1, 0), 0)),

        grayscale(textureLoad(input, my - vec2u(0, 1), 0)),
        grayscale(textureLoad(input, my + vec2u(0, 0), 0)),
        grayscale(textureLoad(input, my + vec2u(0, 1), 0)),

        grayscale(textureLoad(input, my + vec2u(1, 1), 0)),
        grayscale(textureLoad(input, my + vec2u(1, 0), 0)),
        grayscale(textureLoad(input, my + vec2u(1, 1), 0))
    );

    let s1 = mat3x3f(
        1, 2, 1,
        0, 0, 0,
        -1, -2, -1
    );

    let s2 = mat3x3f(
        1, 0, -1,
        2, 0, -2,
        1, 0, -1
    );

    var g1: f32 = 0;
    var g2: f32 = 0;
    for (var x = 0; x < 3; x+=1) {
        for (var y = 0; y < 3; y+=1) {
            g1 += a[y][x] * s1[y][x];
            g2 += a[y][x] * s2[y][x];
        }
    }

    return vec4f(vec3f(abs(g1) + abs(g2)), 1.0);
}

// TODO: maybe add a bigger matrix
const half4x4 = mat4x4f(0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5);
const bayer4x4 = mat4x4f(
    0, 12.0/16.0, 3.0/16.0, 15.0/16.0,
    8.0/16.0, 4.0/16.0, 11.0/16.0, 7.0/16.0,
    2.0/16.0, 14.0/16.0, 1.0/16.0, 13.0/16.0,
    10.0/16.0, 6.0/16.0, 9.0/16.0, 5.0/16.0
) - half4x4;

fn bayer(p: vec4f, my: vec2u) -> vec4f {
    let b = bayer4x4[my.y % 4][my.x % 4];
    return p + vec4f(b, b, b, 1);
}

fn nearestNeighbourColourSearch(p: vec3f) -> vec3f {
    let ps = textureDimensions(palette).x;
    var minDist = 999.0;
    var minCol: vec3f = vec3f(0);
    for (var i: u32 = 0; i < ps; i++) {
        let col = textureLoad(palette, vec2u(i, 0), 0).xyz;
        let dist = distance(col, p);
        if (dist < minDist) {
            minDist = dist;
            minCol = col;
        }
    }
    return minCol;
}

fn blueNoise(pos: vec2u) -> f32 {
    let blDimensions = textureDimensions(palette).xy;
    let uv = pos % blDimensions;
    return textureLoad(palette, uv, 0).x;
}

@compute @workgroup_size(1, 1)
fn colourPass(@builtin(global_invocation_id) global_id : vec3u, @builtin(num_workgroups) n_w: vec3u) {
    var p = textureLoad(input, global_id.xy, 0);
    p = vec4f(nearestNeighbourColourSearch(p.xyz), p.w);
    textureStore(result, global_id.xy, p);
}

@compute @workgroup_size(1, 1)
fn lumaPass(@builtin(global_invocation_id) global_id : vec3u, @builtin(num_workgroups) n_w: vec3u) {
    var p = textureLoad(input, global_id.xy, 0);
    p = vec4f(invertLumen(p).xyz, 1);
    textureStore(result, global_id.xy, p);
}

@compute @workgroup_size(1, 1)
fn grayscalePass(@builtin(global_invocation_id) global_id : vec3u, @builtin(num_workgroups) n_w: vec3u) {
    var p = textureLoad(input, global_id.xy, 0);
    p = vec4f(vec3f(grayscale(p)), 1);
    textureStore(result, global_id.xy, p);
}

@compute @workgroup_size(1, 1)
fn ditherPass(@builtin(global_invocation_id) global_id : vec3u, @builtin(num_workgroups) n_w: vec3u) {
    var p = textureLoad(input, global_id.xy, 0);
    p = bayer(p, global_id.xy);
    textureStore(result, global_id.xy, p);
}

@compute @workgroup_size(1, 1)
fn noiseDither(@builtin(global_invocation_id) global_id : vec3u, @builtin(num_workgroups) n_w: vec3u) {
    let nn = blueNoise(global_id.xy);
    var px = textureLoad(input, global_id.xy, 0);
    px = vec4f(step(vec3f(nn), px.xyz), 1);
    textureStore(result, global_id.xy, px);
}


@compute @workgroup_size(1, 1)
fn glut(@builtin(global_invocation_id) pos : vec3u, @builtin(num_workgroups) size: vec3u) {
    var cube_col = vec3f(pos.xyz) / vec3f(textureDimensions(lutW).xyz);
    cube_col = nearestNeighbourColourSearch(cube_col);
    textureStore(lutW, pos.xyz, vec4f(cube_col, 1.0));
}

@compute @workgroup_size(1, 1)
fn slut(@builtin(global_invocation_id) global_id : vec3u, @builtin(num_workgroups) size: vec3u) {
    var px = textureLoad(input, global_id.xy, 0);
    var px2 = textureSampleLevel(lut, lutSampler, px.xyz, 0);
    textureStore(result, global_id.xy, px2);
}