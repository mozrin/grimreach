package main

import "math"

const worldSeed int64 = 76341
const playerRadius = 0.38

func placementHash(x, z, salt int64) int64 {
	value := (x * 73856093) ^ (z * 19349663) ^ (salt * 83492791) ^ worldSeed
	if value < 0 {
		return -value
	}
	return value
}

func blockedPosition(x, z float64) bool {
	if math.Abs(x) > worldLimit || math.Abs(z) > worldLimit {
		return true
	}
	gridX := int64(math.Floor(x / 4))
	gridZ := int64(math.Floor(z / 4))
	for cellZ := gridZ - 1; cellZ <= gridZ+1; cellZ++ {
		for cellX := gridX - 1; cellX <= gridX+1; cellX++ {
			centerX := float64(cellX)*4 + 2
			centerZ := float64(cellZ)*4 + 2
			if math.Hypot(centerX, centerZ) < 7 {
				continue
			}
			if onRoute(centerX, centerZ) || inSiteClearing(centerX, centerZ) {
				continue
			}
			treeLimit := int64(7) + placementHash(floorDiv(cellX, 24), floorDiv(cellZ, 24), 7)%9
			choice := placementHash(cellX, cellZ, 11) % 100
			radius := 0.0
			if choice < treeLimit {
				radius = 0.55
			} else if choice < treeLimit+7 {
				radius = 0.9
			}
			if radius > 0 && math.Hypot(x-centerX, z-centerZ) < radius+playerRadius {
				return true
			}
		}
	}
	chunkX := int64(math.Floor(x / 48))
	chunkZ := int64(math.Floor(z / 48))
	for regionZ := chunkZ - 1; regionZ <= chunkZ+1; regionZ++ {
		for regionX := chunkX - 1; regionX <= chunkX+1; regionX++ {
			kind := siteKind(regionX, regionZ)
			if kind == "" {
				continue
			}
			originX, originZ := siteCenter(regionX, regionZ, kind)
			switch kind {
			case "ruin":
				for _, wall := range [][4]float64{
					{-5, -5, 1, 1}, {5, -5, 1, 1}, {0, -5, 11, 1},
					{-5, 5, 1, 1}, {5, 5, 1, 1},
				} {
					if math.Abs(x-(originX+wall[0])) < wall[2]/2+playerRadius &&
						math.Abs(z-(originZ+wall[1])) < wall[3]/2+playerRadius {
						return true
					}
				}
			case "camp":
				for _, obstacle := range [][3]float64{{-4, -1, 2}, {4, -1, 2}, {0, 0, 0.7}} {
					if math.Hypot(x-(originX+obstacle[0]), z-(originZ+obstacle[1])) < obstacle[2]+playerRadius {
						return true
					}
				}
			case "shrine":
				if math.Hypot(x-originX, z-originZ) < 1+playerRadius {
					return true
				}
				for _, pillar := range [][2]float64{{-4, -4}, {4, -4}, {-4, 4}, {4, 4}} {
					if math.Hypot(x-(originX+pillar[0]), z-(originZ+pillar[1])) < 0.6+playerRadius {
						return true
					}
				}
			}
		}
	}
	return false
}

func siteKind(chunkX, chunkZ int64) string {
	if chunkX == 0 && chunkZ == 0 || chunkX%7 == 0 && chunkZ%7 == 0 {
		return "ruin"
	}
	if chunkX == -1 && chunkZ == -1 {
		return "camp"
	}
	if chunkX == 0 && chunkZ == -1 {
		return "shrine"
	}
	if placementHash(chunkX, chunkZ, 47)%3 != 0 {
		return ""
	}
	return [...]string{"ruin", "camp", "shrine"}[placementHash(chunkX, chunkZ, 53)%3]
}

func siteCenter(chunkX, chunkZ int64, kind string) (float64, float64) {
	offset := 24.0
	if kind == "ruin" {
		offset = 19
	}
	return float64(chunkX)*48 + offset, float64(chunkZ)*48 + offset
}

func inSiteClearing(x, z float64) bool {
	chunkX := int64(math.Floor(x / 48))
	chunkZ := int64(math.Floor(z / 48))
	kind := siteKind(chunkX, chunkZ)
	if kind == "" {
		return false
	}
	centerX, centerZ := siteCenter(chunkX, chunkZ, kind)
	return math.Hypot(x-centerX, z-centerZ) < 9
}

func onRoute(x, z float64) bool {
	if math.Abs(math.Remainder(x-24, 144)) < 3.5 || math.Abs(math.Remainder(z-24, 144)) < 3.5 {
		return true
	}
	for _, destination := range [][2]float64{{19, 19}, {-24, -24}, {24, -24}} {
		lengthSquared := destination[0]*destination[0] + destination[1]*destination[1]
		portion := math.Max(0, math.Min(1, (x*destination[0]+z*destination[1])/lengthSquared))
		if math.Hypot(x-portion*destination[0], z-portion*destination[1]) < 3 {
			return true
		}
	}
	return false
}

func floorDiv(value, divisor int64) int64 {
	quotient := value / divisor
	if value%divisor < 0 {
		quotient--
	}
	return quotient
}
