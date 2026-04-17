//go:build !unix

package web

func runningAsRoot() bool {
	return false
}
