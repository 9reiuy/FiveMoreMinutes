uniform bool waitress_inks = false;

float authored_enemy_ink(vec3 rgb, ivec2 atlas_pixel) {
	ivec2 cell = ivec2(atlas_pixel.x % 32, atlas_pixel.y % 32);
	bool head_cell = atlas_pixel.x >= 32 && atlas_pixel.x < 64;
	bool skin = rgb.r > 0.52 && rgb.r - rgb.g > 0.06 && rgb.b >= rgb.g * 0.88;
	bool pale_detail = min(rgb.r, min(rgb.g, rgb.b)) > 0.69;
	bool hair_accessory = false;
	bool hair_stroke = false;
	bool tie = false;
	if (waitress_inks) {
		hair_accessory = head_cell && cell.y >= 11 && cell.y <= 14
			&& distance(rgb, vec3(116.0, 157.0, 164.0) / 255.0) < 0.01;
		hair_stroke = head_cell && (
			(cell.y == 8 && cell.x >= 19 && cell.x <= 21)
			|| cell == ivec2(22, 9) || cell == ivec2(23, 10)
			|| cell == ivec2(25, 21) || cell == ivec2(26, 22));
	} else {
		hair_accessory = head_cell && cell.y < 12
			&& distance(rgb, vec3(164.0, 145.0, 116.0) / 255.0) < 0.01;
		hair_stroke = head_cell && (
			(cell.y == 4 && cell.x >= 19 && cell.x <= 21)
			|| cell == ivec2(22, 5) || cell == ivec2(23, 6)
			|| cell == ivec2(25, 10) || cell == ivec2(26, 11));
		tie = ((head_cell && cell.y >= 22) || (atlas_pixel.x >= 64 && atlas_pixel.x < 96))
			&& distance(rgb, vec3(113.0, 129.0, 155.0) / 255.0) < 0.01;
	}
	return (skin || pale_detail || hair_accessory || tie || (hair_stroke && rgb.g > 0.12)) ? 1.0 : 0.0;
}
