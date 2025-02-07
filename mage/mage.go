//go:build mage

package main

import (
	"os"

	//mage:import
	"github.com/rancher/ob-team-charts/mage/charts"

	//mage:import
	"github.com/rancher/ob-team-charts/mage/scripts"

	log "github.com/sirupsen/logrus"
)

var Aliases = map[string]interface{}{
	"pull-scripts": charts.Chart.PullBuildScripts,
	"prepare":      charts.Chart.Prepare,
	"patch":        charts.Chart.Patch,
	"clean":        charts.Chart.Clean,
	"clean-cache":  charts.Chart.CleanCache,
	"charts":       charts.Chart.Charts,
	"list":         charts.Chart.List,
	"index":        charts.Chart.Index,
	"unzip":        charts.Chart.Unzip,
	"zip":          charts.Chart.Zip,
	"standardize":  charts.Chart.Standardize,
	"template":     charts.Chart.Template,
	"call":         scripts.Scripts.Execute,
}

func init() {
	// Output to stdout instead of the default stderr
	// Can be any io.Writer, see below for File example
	log.SetOutput(os.Stdout)

	// Only log the warning severity or above.
	log.SetLevel(log.InfoLevel)
}
