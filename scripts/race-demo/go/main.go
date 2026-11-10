// Copyright 2026 The Helix Authors. SPDX-License-Identifier: Apache-2.0

//go:build racedemo

// Command race-demo is DELIBERATELY BROKEN: two goroutines increment a shared
// int without synchronization. The racedemo build tag keeps it out of
// `go build ./...`, `go vet ./...` and `go test ./...`; only
// scripts/verify-sanitizers-catch-races.sh builds it, to prove that the Go race
// detector is wired up correctly.
package main

import (
	"fmt"
	"sync"
)

func main() {
	counter := 0
	var wg sync.WaitGroup
	for g := 0; g < 2; g++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := 0; i < 100000; i++ {
				counter++ // data race
			}
		}()
	}
	wg.Wait()
	fmt.Printf("counter=%d (expected 200000 if there were no race)\n", counter)
}
