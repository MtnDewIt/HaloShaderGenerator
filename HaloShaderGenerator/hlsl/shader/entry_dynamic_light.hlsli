﻿#ifndef _SHADER_TEMPLATE_DYNAMIC_LIGHT_HLSLI
#define _SHADER_TEMPLATE_DYNAMIC_LIGHT_HLSLI

#include "entry_albedo.hlsli"
#include "..\registers\shader.hlsli"
#include "..\helpers\input_output.hlsli"
#include "..\helpers\definition_helper.hlsli"
#include "..\helpers\color_processing.hlsli"
#include "..\helpers\lighting.hlsli"
#include "..\methods\material_model.hlsli"
#include "..\helpers\shadows.hlsli"


uniform sampler2D dynamic_light_gel_texture;

PS_OUTPUT_DEFAULT calculate_dynamic_light(
float2 position,
float2 texcoord,
float3 camera_dir,
float3 tangent,
float3 binormal,
float3 normal,
int light_index,
float depth_scale,
float depth_offset,
float2 shadowmap_texcoord,
bool is_cinematic)
{
	texcoord = calc_parallax_ps(texcoord, camera_dir, tangent, binormal, normal);
	float alpha = calc_alpha_test_ps(texcoord);
	
	float3 view_dir = normalize(camera_dir);
	float3 world_position = Camera_Position_PS - camera_dir;

	float shadow_coefficient;
	float3 diffuse;

	SimpleLight light = get_simple_light(light_index);
	
	float3 v_to_light = light.position.xyz - world_position;
	float light_distance_squared = dot(v_to_light, v_to_light);
	v_to_light = normalize(v_to_light);
	
	float attenuation = 1.0 / (light_distance_squared + light.position.w);
	float light_angle = dot(v_to_light, light.direction.xyz);

	float2 packed_light_values = float2(attenuation, light_angle);
	packed_light_values = max(0.0001, packed_light_values * light.unknown3.xy + light.unknown3.zw);
	float specular_power = pow(packed_light_values.y, light.color.w);

	float intensity = saturate(specular_power + light.direction.w) * saturate(packed_light_values.x);
	
	float2 shadowmap_texcoord_depth_adjusted = shadowmap_texcoord * (1.0 / depth_scale);
	
	float2 gel_texcoord = apply_xform2d(shadowmap_texcoord_depth_adjusted, p_dynamic_light_gel_xform);
	float4 gel_sample = tex2D(dynamic_light_gel_texture, gel_texcoord);
	
	float3 light_intensity = intensity * light.color.rgb * gel_sample.rgb;
	
	float4 albedo;
	float3 modified_normal;
	
	get_albedo_and_normal(actually_calc_albedo, position.xy, texcoord.xy, camera_dir, tangent.xyz, binormal.xyz, normal.xyz, albedo, modified_normal);
	float3 reflect_dir = 2 * dot(view_dir, modified_normal) * modified_normal - camera_dir;
	float v_dot_n = dot(v_to_light, modified_normal);
	float3 specular_contribution = specular_coefficient * analytical_specular_contribution;
	
	float c_albedo_blend;
	float c_roughness;
	float4 packed_parameters;
	float c_diffuse_coefficient, c_analytical_specular_coefficient, c_area_specular_coefficient;
	
	get_material_parameters_2(texcoord, packed_parameters, c_diffuse_coefficient, c_analytical_specular_coefficient, c_area_specular_coefficient);
	c_albedo_blend = packed_parameters.y;
	c_roughness = packed_parameters.w;
	
	float3 color = light_intensity * v_dot_n * albedo.rgb * c_diffuse_coefficient;

	specular_contribution *= specular_tint;
	
	[flatten]
	if (dot(specular_contribution, specular_contribution) > 0.0001)
	{
		float3 analytic_specular;
		float3 fresnel_f0 = albedo_blend_with_specular_tint.x > 0 ? fresnel_color : lerp(fresnel_color, albedo.rgb, c_albedo_blend);
		calc_material_analytic_specular(view_dir, modified_normal, reflect_dir, v_to_light, light_intensity, fresnel_f0, c_roughness, analytic_specular);
		color += analytic_specular * specular_contribution;
	}
	
	if (dynamic_light_shadowing)
	{
		if (is_cinematic)
			shadow_coefficient = shadows_percentage_closer_filtering_custom_4x4(shadowmap_texcoord_depth_adjusted, shadowmap_texture_size, depth_scale, depth_offset, color);
		else
			shadow_coefficient = shadows_percentage_closer_filtering_3x3(shadowmap_texcoord_depth_adjusted, shadowmap_texture_size, depth_scale, depth_offset, color);
	}
	else
	{
		shadow_coefficient = 1.0;
	}
	
	float4 result;
	if (blend_type_arg == k_blend_mode_additive)
	{
		result.a = 0.0;
	}
	else if (blend_type_arg == k_blend_mode_alpha_blend || blend_type_arg == k_blend_mode_pre_multiplied_alpha)
	{
		result.a = alpha * albedo.a;
	}
	else
	{
		result.a = alpha;
	}
	
	result.rgb = expose_color(color.rgb);
	result.rgb *= shadow_coefficient;
	
	return export_color(result);
}

PS_OUTPUT_DEFAULT shader_entry_dynamic_light(VS_OUTPUT_DYNAMIC_LIGHT input)
{
	return calculate_dynamic_light(input.position.xy, input.texcoord, input.camera_dir, input.tangent, input.binormal, input.normal, 0, input.shadowmap_texcoord.w, input.shadowmap_texcoord.z, input.shadowmap_texcoord.xy, false);
}

PS_OUTPUT_DEFAULT shader_entry_dynamic_light_cinematic(VS_OUTPUT_DYNAMIC_LIGHT input)
{
	return calculate_dynamic_light(input.position.xy, input.texcoord, input.camera_dir, input.tangent, input.binormal, input.normal, 0, input.shadowmap_texcoord.w, input.shadowmap_texcoord.z, input.shadowmap_texcoord.xy, true);
}

#endif