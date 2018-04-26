// Package main formats iRods retrieved data to match the mpistat format
package main

import (
	"bufio"
	"bytes"
	"encoding/base64"
	"flag"
	"fmt"
	"log"
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
	b64path   string
	sizeBytes string
	group     string
	ctime     string
}

var (
	buf    bytes.Buffer
	logger = log.New(&buf, "logger: ", log.Lshortfile|log.Ldate|log.Ltime)
)

func main() {
	var infile, outfile, groupsfile string

	flag.StringVar(&infile, "f", "/tmp/iRodsData.txt", "file stats from iRods")
	flag.StringVar(&groupsfile, "g", "/tmp/groups.txt", "group names and ids from getent groups")
	flag.StringVar(&outfile, "o", "/tmp/iRodsFormatted.txt", "name of output file")

	flag.Parse()

	logger.Print("Start file processing")

	e := FormatFile(infile, outfile, groupsfile, "???", []string{"/humgen/projects", "/humgen/teams"})
	if e != nil {
		logger.Print(e)
	}
	logger.Print("End file processing")
	fmt.Print(&buf)
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
// only report on collections starting with one of the prefixes
func FormatFile(infilename, outfilename, groupsfile, delimiter string, prefixes []string) (err error) {

	groupsMap, err := mapProjectsToGroups(groupsfile)
	if err != nil {
		err = fmt.Errorf(err.Error()+" %s ", groupsfile)
		logger.Print(err)
		return
	}

	// open files for input and output
	infile, err := os.Open(infilename)
	if err != nil {
		err = fmt.Errorf(err.Error()+" %s ", infilename)
		logger.Print(err)
		return
	}
	defer infile.Close()
	outfile, err := os.Create(outfilename)
	if err != nil {
		err = fmt.Errorf(err.Error()+" %s ", outfilename)
		logger.Print(err)
		return
	}
	defer outfile.Close()

	// read line
	scanner := bufio.NewScanner(infile)

	lineNo := 0
	lineOut := 0
	for scanner.Scan() {
		line := scanner.Text()
		if err = scanner.Err(); err != nil {
			return
		}
		lineNo++
		if lineNo == 1 {
			logger.Println(line)
			continue
		}
		reportFile := false
		for i := range prefixes {

			if strings.HasPrefix(line, prefixes[i]) {
				reportFile = true
			}
		}
		if !reportFile {
			continue
		}
		nextLine, err := processLine(line, delimiter, groupsMap)
		if err != nil {
			return err
		}

		outfile.WriteString(nextLine + "\n")
		lineOut++
	}
	logger.Print("Number of lines read ", lineNo)
	logger.Print("Number of lines written ", lineOut)

	return
}

// the project is in the collection name after /projects or /teams. If /projects not found return 'hgi'
// and the group will be set to hgi
func getProjectTeamFromCollection(collection string) (project string) {

	parts := strings.Split(collection, "/")
	project = "hgi"
	for i := range parts {
		if (parts[i] == "projects") && (i < len(parts)-1) {
			project = parts[i+1]
			break
		} else if (parts[i] == "teams") && (i < len(parts)-1) {
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

	codedPath := base64.StdEncoding.EncodeToString([]byte(path))

	lout := outLine{}
	unused := ""

	lout.b64path = codedPath
	lout.sizeBytes = l.size
	lout.ctime = l.create

	g := getProjectTeamFromCollection(l.collection)
	lout.group = "xx"
	if val, ok := groupsMap[g]; ok {
		lout.group = val
	}

	sep := "\t"
	nextLine = lout.b64path + sep
	nextLine = nextLine + lout.sizeBytes + sep
	nextLine = nextLine + unused + sep
	nextLine = nextLine + lout.group + sep
	nextLine = nextLine + unused + sep
	nextLine = nextLine + unused + sep
	nextLine = nextLine + lout.ctime + sep
	nextLine = nextLine + unused + sep
	nextLine = nextLine + unused + sep
	nextLine = nextLine + unused + sep
	nextLine = nextLine + unused + sep

	return
}

// set up a map from group name to group number using getent group output
// project name is group name (ie projects have groups)
func mapProjectsToGroups(groupsfile string) (groups map[string]string, err error) {
	groups = make(map[string]string)
	infile, err := os.Open(groupsfile)
	if err != nil {
		err = fmt.Errorf(err.Error()+" %s ", groupsfile)
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
