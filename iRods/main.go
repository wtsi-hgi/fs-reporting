// Package iRodsReport formats iRods retrieved data to match the mpistat format
package iRodsReport

import (
	"bufio"
	"encoding/base64"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

type inLine struct {
	filename   string
	collection string
	create     string
	size       string
}

type outLine struct {
	b64path        string
	sizeBytes      string
	user           string
	group          string
	atime          string
	mtime          string
	ctime          string
	protectionmode string
	a              string
	b              string
	c              string
}

func main() {

}

// FormatFile takes an input file with four strings per line separated by a delimiter
// The data for each file (data object) is filename, collection name, create date (unix), size (bytes)
// iRods query is
//iquest -z humgen --no-page "%s???%s???%s???%s" "SELECT COLL_NAME,DATA_NAME,min(DATA_CREATE_TIME),sum(DATA_SIZE)"
// the size is all replicates of that file summed;
// and writes an output file with format required for the report processing
//  and produce a tab separated file with non * rows as zeros
//   filepath (base64 encoded) *
//   size (bytes) *
//   user (uid) *
//   group (gid) *
//   atime (epoch)
//   mtime (epoch)
//   ctime (epoch) *
//   protection mode
//   inode ID
//   number of hardlinks
//   device ID
func FormatFile(infilename, outfilename, groupsfile, delimiter string) (err error) {

	groupsMap, err := mapProjectsToGroups(groupsfile)
	if err != nil {
		return
	}

	// open files for input and output
	infile, err := os.Open(infilename)
	if err != nil {
		return
	}
	defer infile.Close()
	outfile, err := os.Create(outfilename)
	if err != nil {
		return
	}
	defer outfile.Close()

	// read line
	scanner := bufio.NewScanner(infile)

	lineNo := 0
	for scanner.Scan() {
		line := scanner.Text()
		if err = scanner.Err(); err != nil {
			return
		}
		lineNo++
		if lineNo == 1 {
			fmt.Println(line)
			continue
		}
		nextLine, err := processLine(line, delimiter, groupsMap)
		if err != nil {
			return err
		}
		outfile.WriteString(nextLine + "\n")
	}

	return
}

// the project is in the collection name after /projects. If /projects not found return 'hgi'
// and the group will be set to hgi
func getProjectFromCollection(collection string) (project string) {

	parts := strings.Split(collection, "/")
	project = "hgi"
	for i := range parts {
		if (parts[i] == "projects") && (i < len(parts)-1) {
			project = parts[i+1]
			break
		}
	}
	return
}

func processLine(line string, delimiter string, groupsMap map[string]string) (nextLine string, err error) {
	// process line
	parts := strings.Split(line, delimiter)
	if len(parts) < 4 {
		err = fmt.Errorf("Incorrect format for input line %s", line)
		return
	}
	l := inLine{collection: parts[0], filename: parts[1], create: parts[2], size: parts[3]}

	path := filepath.Join(l.collection, l.filename)
	fmt.Println(path)
	codedPath := base64.StdEncoding.EncodeToString([]byte(path))
	fmt.Println(codedPath)

	lout := outLine{}
	lout.a = "0"
	lout.b = "0"
	lout.c = "0"
	lout.atime = "0"
	lout.protectionmode = "f"

	lout.b64path = codedPath
	lout.sizeBytes = l.size
	lout.ctime = l.create
	lout.user = "user"
	g := getProjectFromCollection(l.collection)
	lout.group = "xx"
	if val, ok := groupsMap[g]; ok {
		lout.group = val
	}

	sep := "\t"
	nextLine = lout.b64path + sep
	nextLine = nextLine + lout.sizeBytes + sep
	nextLine = nextLine + lout.user + sep
	nextLine = nextLine + lout.group + sep
	nextLine = nextLine + lout.atime + sep
	nextLine = nextLine + lout.mtime + sep
	nextLine = nextLine + lout.ctime + sep
	nextLine = nextLine + lout.protectionmode + sep
	nextLine = nextLine + lout.a + sep
	nextLine = nextLine + lout.b + sep
	nextLine = nextLine + lout.c + sep

	return
}

// set up a map from group name to group number using getent group output
// project name is group name (ie projects have groups)
func mapProjectsToGroups(groupsfile string) (groups map[string]string, err error) {
	groups = make(map[string]string)
	infile, err := os.Open(groupsfile)
	if err != nil {
		return
	}
	defer infile.Close()
	// file format is project group, *, number, list of members : separated
	scanner := bufio.NewScanner(infile)
	for scanner.Scan() {
		row := scanner.Text()
		if err = scanner.Err(); err != nil {
			return
		}

		parts := strings.Split(row, ":")
		if len(parts) > 2 {
			groups[parts[0]] = parts[2]
		}
	}

	return

}
