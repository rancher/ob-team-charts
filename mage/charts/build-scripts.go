package charts

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"runtime"
	"strings"

	"github.com/magefile/mage/mg"
	"github.com/magefile/mage/sh"
	log "github.com/sirupsen/logrus"
)

const (
	buildScriptsRepo          = "https://github.com/rancher/charts-build-scripts.git"
	defaultBuildScriptsTarget = "v1.4.2"
)

const (
	chartScriptsBaseDir       = "./bin"
	chartsBuildScriptsBinPath = chartScriptsBaseDir + "/charts-build-scripts"
)

type Chart mg.Namespace

func (Chart) PullBuildScripts() error {
	needsFetch, err := checkNeedsFetch()
	if !needsFetch && err == nil {
		log.Info("No update fetch needed for `charts-build-scripts`")
		return nil
	}

	log.Infof("Downloading charts-build-scripts version %s@%s", buildScriptsRepo, defaultBuildScriptsTarget)

	err = prepareLocalBinDir()
	if err != nil {
		return err
	}

	runningOs := runtime.GOOS
	runningArch := runtime.GOARCH
	binaryName := fmt.Sprintf("charts-build-scripts_%s_%s", runningOs, runningArch)
	if runningOs == "windows" {
		binaryName += ".exe"
	}

	requestUrl := fmt.Sprintf(
		"%s/releases/download/%s/%s",
		strings.TrimSuffix(buildScriptsRepo, ".git"),
		defaultBuildScriptsTarget,
		binaryName,
	)

	err = fetchUpdate(requestUrl)
	if err != nil {
		return err
	}

	log.Infof("%s => %s", binaryName, chartsBuildScriptsBinPath)

	err = sh.RunV(chartsBuildScriptsBinPath, "--version")
	if err != nil {
		return err
	}

	return nil
}

func checkNeedsFetch() (bool, error) {
	stat, err := os.Stat(chartsBuildScriptsBinPath)
	if err != nil {
		return true, err
	}

	if stat.Size() == 0 {
		return true, nil
	}

	currentVersionString, err := sh.Output(chartsBuildScriptsBinPath, "--version")
	if err != nil {
		return false, err
	}
	currentVersion := "v" + strings.Split(currentVersionString, " ")[2]
	log.Infof("Current version: %s, Expected version: %s", currentVersion, defaultBuildScriptsTarget)
	if currentVersion != defaultBuildScriptsTarget {
		return true, nil
	}

	return false, err
}

func prepareLocalBinDir() error {
	err := os.RemoveAll("./bin")
	if err != nil {
		return err
	}

	err = os.Mkdir("./bin", 0755)
	if err != nil {
		return err
	}

	return nil
}

func fetchUpdate(requestUrl string) error {
	resp, err := http.Get(requestUrl)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	// Check if the request was successful
	if resp.StatusCode != http.StatusOK {
		fmt.Println("HTTP error:", resp.StatusCode, resp.Status)
		return fmt.Errorf("TODO this is a bad error")
	}

	body, err := io.ReadAll(resp.Body)
	err = os.WriteFile(chartsBuildScriptsBinPath, body, 0755)
	if err != nil {
		return err
	}

	return nil
}
