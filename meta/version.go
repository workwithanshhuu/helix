// Copyright 2026 The Helix Authors. SPDX-License-Identifier: Apache-2.0

// Package meta is the root of helix-meta, the Raft-replicated control plane.
//
// Day 1 only contains version information; it proves the Go toolchain, tests,
// the race detector and CI. Subpackages arrive later (see SPEC.md §2):
//
//	meta/raft   — Raft consensus (days 19–26)
//	meta/wal    — write-ahead log and snapshots (days 23–24)
//	meta/sm     — the deterministic metadata state machine (day 25)
//	meta/sim    — simulated network for tests (day 20)
//	meta/sched  — global scheduler (days 29–34)
//	meta/api    — gRPC services (day 27)
//	meta/cmd    — helix-meta and helixctl binaries (day 27)
package meta

import "runtime"

// Version is the semantic version of this build. It must equal the contents of
// the VERSION file at the repository root; TestVersionMatchesVersionFile
// enforces that, so bump both together.
const Version = "0.0.1"

// BuildInfo describes the Go build that is running.
type BuildInfo struct {
	Version   string // Semantic version, e.g. "0.0.1".
	GoVersion string // Toolchain, e.g. "go1.23.4".
	OS        string // runtime.GOOS, e.g. "linux".
	Arch      string // runtime.GOARCH, e.g. "arm64".
}

// GetBuildInfo returns information about the current build. It is safe to
// call from multiple goroutines.
func GetBuildInfo() BuildInfo {
	return BuildInfo{
		Version:   Version,
		GoVersion: runtime.Version(),
		OS:        runtime.GOOS,
		Arch:      runtime.GOARCH,
	}
}
