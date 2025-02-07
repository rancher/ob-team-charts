package scripts

import (
	"fmt"
	"github.com/magefile/mage/mg"
	"github.com/magefile/mage/sh"
	"os"
)

type Scripts mg.Namespace

func (Scripts) Rebase() error {
	return sh.RunV("./scripts/charts-build-scripts/rebase")
}

func (Scripts) Execute(target string) error {
	cwd, err := os.Getwd()
	if err != nil {
		return fmt.Errorf("error getting CWD: %s", err)
	}
	filePath := fmt.Sprintf("%s/scripts/%s", cwd, target)
	_, err = os.Stat(filePath)
	if err != nil {
		return fmt.Errorf("error checking if file exists: %s", err)
	}

	return sh.RunV(filePath)
}
