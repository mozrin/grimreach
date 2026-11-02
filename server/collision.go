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
			if regionX%7 != 0 || regionZ%7 != 0 {
				continue
			}
			originX := float64(regionX)*48 + 19
			originZ := float64(regionZ)*48 + 19
			for _, wall := range [][4]float64{
				{-5, -5, 1, 1}, {5, -5, 1, 1}, {0, -5, 11, 1},
				{-5, 5, 1, 1}, {5, 5, 1, 1},
			} {
				if math.Abs(x-(originX+wall[0])) < wall[2]/2+playerRadius &&
					math.Abs(z-(originZ+wall[1])) < wall[3]/2+playerRadius {
					return true
				}
			}
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
