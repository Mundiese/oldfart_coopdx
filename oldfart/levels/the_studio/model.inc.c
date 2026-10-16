Vtx the_studio_dl_Cube_001_mesh_layer_1_vtx_0[14] = {
	{{ {-5000, -2000, 5000}, 0, {368, 1008}, {255, 255, 255, 255} }},
	{{ {-5000, 2000, -5000}, 0, {624, 752}, {255, 255, 255, 255} }},
	{{ {-5000, 2000, 5000}, 0, {624, 1008}, {255, 255, 255, 255} }},
	{{ {-5000, -2000, -5000}, 0, {368, 752}, {255, 255, 255, 255} }},
	{{ {5000, 2000, -5000}, 0, {624, 496}, {255, 255, 255, 255} }},
	{{ {5000, -2000, -5000}, 0, {368, 496}, {255, 255, 255, 255} }},
	{{ {5000, 2000, 5000}, 0, {624, 240}, {255, 255, 255, 255} }},
	{{ {5000, -2000, 5000}, 0, {368, 240}, {255, 255, 255, 255} }},
	{{ {-5000, -2000, -5000}, 0, {112, 496}, {255, 255, 255, 255} }},
	{{ {-5000, -2000, 5000}, 0, {112, 240}, {255, 255, 255, 255} }},
	{{ {-5000, 2000, 5000}, 0, {624, -16}, {255, 255, 255, 255} }},
	{{ {-5000, -2000, 5000}, 0, {368, -16}, {255, 255, 255, 255} }},
	{{ {-5000, 2000, 5000}, 0, {880, 240}, {255, 255, 255, 255} }},
	{{ {-5000, 2000, -5000}, 0, {880, 496}, {255, 255, 255, 255} }},
};

Gfx the_studio_dl_Cube_001_mesh_layer_1_tri_0[] = {
	gsSPVertex(the_studio_dl_Cube_001_mesh_layer_1_vtx_0 + 0, 14, 0),
	gsSP1Triangle(0, 1, 2, 0),
	gsSP1Triangle(0, 3, 1, 0),
	gsSP1Triangle(3, 4, 1, 0),
	gsSP1Triangle(3, 5, 4, 0),
	gsSP1Triangle(5, 6, 4, 0),
	gsSP1Triangle(5, 7, 6, 0),
	gsSP1Triangle(8, 7, 5, 0),
	gsSP1Triangle(8, 9, 7, 0),
	gsSP1Triangle(7, 10, 6, 0),
	gsSP1Triangle(7, 11, 10, 0),
	gsSP1Triangle(4, 6, 12, 0),
	gsSP1Triangle(4, 12, 13, 0),
	gsSPEndDisplayList(),
};

Vtx the_studio_dl_Cube_002_mesh_layer_1_vtx_0[14] = {
	{{ {-6673, -2669, 6673}, 0, {368, 1008}, {255, 255, 255, 255} }},
	{{ {-6673, 2669, -6673}, 0, {624, 752}, {255, 255, 255, 255} }},
	{{ {-6673, 2669, 6673}, 0, {624, 1008}, {255, 255, 255, 255} }},
	{{ {-6673, -2669, -6673}, 0, {368, 752}, {255, 255, 255, 255} }},
	{{ {6673, 2669, -6673}, 0, {624, 496}, {255, 255, 255, 255} }},
	{{ {6673, -2669, -6673}, 0, {368, 496}, {255, 255, 255, 255} }},
	{{ {6673, 2669, 6673}, 0, {624, 240}, {255, 255, 255, 255} }},
	{{ {6673, -2669, 6673}, 0, {368, 240}, {255, 255, 255, 255} }},
	{{ {-6673, -2669, -6673}, 0, {112, 496}, {255, 255, 255, 255} }},
	{{ {-6673, -2669, 6673}, 0, {112, 240}, {255, 255, 255, 255} }},
	{{ {-6673, 2669, 6673}, 0, {624, -16}, {255, 255, 255, 255} }},
	{{ {-6673, -2669, 6673}, 0, {368, -16}, {255, 255, 255, 255} }},
	{{ {-6673, 2669, 6673}, 0, {880, 240}, {255, 255, 255, 255} }},
	{{ {-6673, 2669, -6673}, 0, {880, 496}, {255, 255, 255, 255} }},
};

Gfx the_studio_dl_Cube_002_mesh_layer_1_tri_0[] = {
	gsSPVertex(the_studio_dl_Cube_002_mesh_layer_1_vtx_0 + 0, 14, 0),
	gsSP1Triangle(0, 1, 2, 0),
	gsSP1Triangle(0, 3, 1, 0),
	gsSP1Triangle(3, 4, 1, 0),
	gsSP1Triangle(3, 5, 4, 0),
	gsSP1Triangle(5, 6, 4, 0),
	gsSP1Triangle(5, 7, 6, 0),
	gsSP1Triangle(8, 7, 5, 0),
	gsSP1Triangle(8, 9, 7, 0),
	gsSP1Triangle(7, 10, 6, 0),
	gsSP1Triangle(7, 11, 10, 0),
	gsSP1Triangle(4, 6, 12, 0),
	gsSP1Triangle(4, 12, 13, 0),
	gsSPEndDisplayList(),
};

Gfx mat_the_studio_dl_f3dlite_material_003[] = {
	gsSPClearGeometryMode(G_LIGHTING),
	gsDPPipeSync(),
	gsDPSetCombineLERP(0, 0, 0, SHADE, 0, 0, 0, ENVIRONMENT, 0, 0, 0, SHADE, 0, 0, 0, ENVIRONMENT),
	gsDPSetAlphaDither(G_AD_NOISE),
	gsSPTexture(65535, 65535, 0, 0, 1),
	gsSPEndDisplayList(),
};

Gfx mat_revert_the_studio_dl_f3dlite_material_003[] = {
	gsSPSetGeometryMode(G_LIGHTING),
	gsDPPipeSync(),
	gsDPSetAlphaDither(G_AD_DISABLE),
	gsSPEndDisplayList(),
};

Gfx the_studio_dl_Cube_001_mesh_layer_1[] = {
	gsSPDisplayList(mat_the_studio_dl_f3dlite_material_003),
	gsSPDisplayList(the_studio_dl_Cube_001_mesh_layer_1_tri_0),
	gsSPDisplayList(mat_revert_the_studio_dl_f3dlite_material_003),
	gsSPEndDisplayList(),
};

Gfx the_studio_dl_Cube_002_mesh_layer_1_with_revert[] = {
	gsSPDisplayList(mat_the_studio_dl_f3dlite_material_003),
	gsSPDisplayList(the_studio_dl_Cube_002_mesh_layer_1_tri_0),
	gsSPDisplayList(mat_revert_the_studio_dl_f3dlite_material_003),
	gsDPPipeSync(),
	gsSPSetGeometryMode(G_LIGHTING),
	gsSPClearGeometryMode(G_TEXTURE_GEN),
	gsDPSetCombineLERP(0, 0, 0, SHADE, 0, 0, 0, ENVIRONMENT, 0, 0, 0, SHADE, 0, 0, 0, ENVIRONMENT),
	gsSPTexture(65535, 65535, 0, 0, 0),
	gsDPSetEnvColor(255, 255, 255, 255),
	gsDPSetAlphaCompare(G_AC_NONE),
	gsSPEndDisplayList(),
};

