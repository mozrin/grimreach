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

func TestSitesAndRoutesStayWalkableAroundSolidStructures(t *testing.T) {
	if siteKind(0, 0) != "ruin" || siteKind(-1, -1) != "camp" || siteKind(0, -1) != "shrine" {
		t.Fatal("starting destinations must have stable distinct types")
	}
	if !blockedPosition(-28, -25) {
		t.Fatal("camp tent must block movement")
	}
	if !blockedPosition(24, -24) {
		t.Fatal("shrine obelisk must block movement")
	}
	if blockedPosition(0, -10) {
		t.Fatal("starting route should remain walkable")
	}
	if !onRoute(168, 24) || !onRoute(24, -120) {
		t.Fatal("the distant route network must continue across regions")
	}
}

func TestMineralVeinsHaveStableSolidFootprints(t *testing.T) {
	x, z, exists := veinCenter(0, 0)
	if !exists || x != 8 || z != 4 {
		t.Fatal("the opening mineral vein moved")
	}
	if !blockedPosition(x, z) {
		t.Fatal("mineral vein should block walking through its crystal")
	}
	if !inVeinClearing(x+1, z) {
		t.Fatal("ordinary clutter should clear around a mineral vein")
	}
}
