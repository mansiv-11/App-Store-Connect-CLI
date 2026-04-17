//go:build unix

package web

import "os"

func runningAsRoot() bool {
	return os.Geteuid() == 0
}
