package main

import "testing"

func TestBlockedPositionMatchesSolidLandmarks(t *testing.T) {
	if blockedPosition(0, 0) {
		t.Fatal("spawn must remain walkable")
	}
	if !blockedPosition(19, 14) {
		t.Fatal("ruin wall must block movement")
	}
	if !blockedPosition(8193, 0) {
		t.Fatal("world boundary must block movement")
	}
	if blockedPosition(19, 19) {
		t.Fatal("ruin courtyard must be walkable")
	}
	var foundTree bool
	for x := int64(2); x < 25; x++ {
		for z := int64(2); z < 25; z++ {
			limit := int64(7) + placementHash(floorDiv(x, 24), floorDiv(z, 24), 7)%9
			if placementHash(x, z, 11)%100 < limit {
				if !blockedPosition(float64(x)*4+2, float64(z)*4+2) {
					t.Fatal("tree trunk must block movement")
				}
				foundTree = true
				break
			}
		}
		if foundTree {
			break
		}
	}
	if !foundTree {
		t.Fatal("fixture did not find a tree")
	}
}

func TestFloorDivMatchesNegativeWorldCells(t *testing.T) {
	if floorDiv(-1, 24) != -1 || floorDiv(-24, 24) != -1 || floorDiv(-25, 24) != -2 {
		t.Fatal("negative biome cells must round toward minus infinity")
	}
}
