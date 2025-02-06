//go:build mage

package main

import (
	"os"

	//mage:import
	"github.com/rancher/ob-team-charts/mage/charts"

	"github.com/magefile/mage/sh"
	log "github.com/sirupsen/logrus"
)

func init() {
	// Output to stdout instead of the default stderr
	// Can be any io.Writer, see below for File example
	log.SetOutput(os.Stdout)

	// Only log the warning severity or above.
	log.SetLevel(log.InfoLevel)
}

var Aliases = map[string]interface{}{
	"pull-scripts": charts.Chart.PullBuildScripts,
}

// Runs go mod download and then installs the binary.
func Build() error {
	if err := sh.Run("go", "mod", "download"); err != nil {
		return err
	}
	return sh.Run("go", "install", "./...")
}
