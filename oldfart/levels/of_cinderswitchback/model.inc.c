Lights1 of_cinderswitchback_dl_f3dlite_material_lights = gdSPDefLights1(
	0x7F, 0x7F, 0x7F,
	0xFF, 0xFF, 0xFF, 0x49, 0x49, 0x49);

Vtx of_cinderswitchback_dl_Death_Plane_mesh_layer_5_vtx_0[4] = {
	{{ {-17500, 0, 17500}, 0, {-16, 1008}, {0, 127, 0, 255} }},
	{{ {17500, 0, 17500}, 0, {1008, 1008}, {0, 127, 0, 255} }},
	{{ {17500, 0, -17500}, 0, {1008, -16}, {0, 127, 0, 255} }},
	{{ {-17500, 0, -17500}, 0, {-16, -16}, {0, 127, 0, 255} }},
};

Gfx of_cinderswitchback_dl_Death_Plane_mesh_layer_5_tri_0[] = {
	gsSPVertex(of_cinderswitchback_dl_Death_Plane_mesh_layer_5_vtx_0 + 0, 4, 0),
	gsSP1Triangle(0, 1, 2, 0),
	gsSP1Triangle(0, 2, 3, 0),
	gsSPEndDisplayList(),
};

Gfx mat_of_cinderswitchback_dl_f3dlite_material[] = {
	gsSPClearGeometryMode(G_CULL_BACK),
	gsSPSetLights1(of_cinderswitchback_dl_f3dlite_material_lights),
	gsDPPipeSync(),
	gsDPSetCombineLERP(0, 0, 0, SHADE, 0, 0, 0, 0, 0, 0, 0, SHADE, 0, 0, 0, 0),
	gsDPSetAlphaDither(G_AD_NOISE),
	gsSPTexture(65535, 65535, 0, 0, 1),
	gsSPEndDisplayList(),
};

Gfx mat_revert_of_cinderswitchback_dl_f3dlite_material[] = {
	gsSPSetGeometryMode(G_CULL_BACK),
	gsDPPipeSync(),
	gsDPSetAlphaDither(G_AD_DISABLE),
	gsSPEndDisplayList(),
};

Gfx of_cinderswitchback_dl_Death_Plane_mesh_layer_5_with_revert[] = {
	gsSPDisplayList(mat_of_cinderswitchback_dl_f3dlite_material),
	gsSPDisplayList(of_cinderswitchback_dl_Death_Plane_mesh_layer_5_tri_0),
	gsSPDisplayList(mat_revert_of_cinderswitchback_dl_f3dlite_material),
	gsDPPipeSync(),
	gsSPSetGeometryMode(G_LIGHTING),
	gsSPClearGeometryMode(G_TEXTURE_GEN),
	gsDPSetCombineLERP(0, 0, 0, SHADE, 0, 0, 0, ENVIRONMENT, 0, 0, 0, SHADE, 0, 0, 0, ENVIRONMENT),
	gsSPTexture(65535, 65535, 0, 0, 0),
	gsDPSetEnvColor(255, 255, 255, 255),
	gsDPSetAlphaCompare(G_AC_NONE),
	gsSPEndDisplayList(),
};

