﻿#ifndef _MATERIAL_MODEL_HLSLI
#define _MATERIAL_MODEL_HLSLI

#include "../shader_lighting/diffuse_only_lighting.hlsli"
#include "../shader_lighting/cook_torrance_lighting.hlsli"

#ifndef calc_lighting_ps
#define calc_lighting_ps calc_lighting_diffuse_only_ps
#endif

#ifndef calc_material_analytic_specular
#define calc_material_analytic_specular calc_material_analytic_specular_diffuse_only_ps
#endif

#ifndef calc_material_area_specular
#define calc_material_area_specular calc_material_area_specular_diffuse_only_ps
#endif

#endif
