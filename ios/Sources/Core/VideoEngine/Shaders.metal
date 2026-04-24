#include <metal_stdlib>
using namespace metal;

// Pass-through kernel. Used to verify the Metal → AVAssetWriter pipeline
// end-to-end when the generator has no real model yet.
kernel void ba6_identity_kernel(
    texture2d<float, access::sample> src [[ texture(0) ]],
    texture2d<float, access::write>  dst [[ texture(1) ]],
    uint2 gid [[ thread_position_in_grid ]]
) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) { return; }
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float2 uv = float2(gid) / float2(dst.get_width(), dst.get_height());
    float4 color = src.sample(s, uv);
    dst.write(color, gid);
}

// Starter stylize kernel — luma-aware posterize.
// Parameterised via `levels` buffer so the renderer can drive it from Swift.
kernel void ba6_posterize_kernel(
    texture2d<float, access::sample> src [[ texture(0) ]],
    texture2d<float, access::write>  dst [[ texture(1) ]],
    constant float& levels [[ buffer(0) ]],
    uint2 gid [[ thread_position_in_grid ]]
) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) { return; }
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float2 uv = float2(gid) / float2(dst.get_width(), dst.get_height());
    float4 c = src.sample(s, uv);
    c.rgb = floor(c.rgb * levels) / levels;
    dst.write(c, gid);
}

// Latent → RGB composite stub. A real diffusion pipeline hands the
// renderer a decoded latent tile per frame; this kernel is where we
// tone-map and write into the output texture.
kernel void ba6_latent_composite_kernel(
    texture2d<float, access::sample> latent [[ texture(0) ]],
    texture2d<float, access::write>  dst    [[ texture(1) ]],
    constant float& exposure [[ buffer(0) ]],
    uint2 gid [[ thread_position_in_grid ]]
) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) { return; }
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float2 uv = float2(gid) / float2(dst.get_width(), dst.get_height());
    float4 c = latent.sample(s, uv);
    c.rgb = 1.0 - exp(-c.rgb * exposure);       // Reinhard-ish tone map
    c.a = 1.0;
    dst.write(c, gid);
}
