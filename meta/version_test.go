// Copyright 2026 The Helix Authors. SPDX-License-Identifier: Apache-2.0

package meta

import (
	"os"
	"regexp"
	"strings"
	"sync"
	"testing"
)

var semver = regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+$`)

func TestVersionIsSemantic(t *testing.T) {
	if !semver.MatchString(Version) {
		t.Fatalf("Version %q is not MAJOR.MINOR.PATCH", Version)
	}
}

func TestVersionMatchesVersionFile(t *testing.T) {
	raw, err := os.ReadFile("../VERSION")
	if err != nil {
		t.Fatalf("reading VERSION: %v", err)
	}
	if got, want := Version, strings.TrimSpace(string(raw)); got != want {
		t.Fatalf("meta.Version = %q, VERSION file = %q; bump both together", got, want)
	}
}

func TestBuildInfo(t *testing.T) {
	info := GetBuildInfo()
	if info.Version != Version {
		t.Errorf("BuildInfo.Version = %q, want %q", info.Version, Version)
	}
	if info.GoVersion == "" || info.OS == "" || info.Arch == "" {
		t.Errorf("BuildInfo has empty fields: %+v", info)
	}
}

// Run under `go test -race` in CI: concurrent readers must not race.
func TestBuildInfoConcurrent(t *testing.T) {
	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < 1000; j++ {
				if GetBuildInfo().Version != Version {
					t.Error("inconsistent version")
					return
				}
			}
		}()
	}
	wg.Wait()
}
