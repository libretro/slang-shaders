/* Filename: filter.h

   Copyright (C) 2023 W. M. Martinez

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>. */ 

float bicubic(const float x, const float B, const float C)
{
	float dx = abs(x);

	if (dx < 1.0) {
		float P1 = 2.0 - 3.0 / 2.0 * B - C;
		float P2 = -3.0 + 2.0 * B + C;
		float P3 = 1.0 - 1.0 / 3.0 * B;

		return P1 * cb(dx) + P2 * sq(dx) + P3;
	} else if ((dx >= 1.0) && (dx < 2.0)) {
		float P1 = -1.0 / 6.0 * B - C;
		float P2 = B + 5.0 * C;
		float P3 = -2.0 * B - 8.0 * C;
		float P4 = 4.0 / 3.0 * B + 4.0 * C;

		return P1 * cb(dx) + P2 * sq(dx) + P3 * dx + P4;
	} else
		return 0.0;
}

vec4 bicubic4(const float x, const float B, const float C)
{
	return vec4(bicubic(x - 2.0, B, C),
	            bicubic(x - 1.0, B, C),
	            bicubic(x, B, C),
	            bicubic(x + 1.0, B, C));
}