package iRodsReport

import (
	"fmt"
	"os"
	"testing"
	"time"
)

func TestFormatFile(t *testing.T) {
	f1, _ := os.Create("/tmp/a.txt")
	defer f1.Close()
	f1.WriteString("aaaaa/project/xx/vv>>bbbb>>cccc>>dddd\n")
	f1.WriteString("aaaaax>>bbbbx>>ccccx>>ddddx\n")
	e := FormatFile("/tmp/a.txt", "/tmp/b.txt", "/home/sjc/groups.txt", ">>")
	if e != nil {
		t.Errorf(e.Error())
	}

	start := time.Now()
	e = FormatFile("/home/sjc/test.txt", "/tmp/extra.txt", "/home/sjc/groups.txt", "???")
	if e != nil {
		t.Errorf(e.Error())
	}
	fmt.Println(time.Since(start))
}

func TestMapProjectsToGroups(t *testing.T) {
	m, e := mapProjectsToGroups("/home/sjc/groups.txt")
	if e != nil {
		t.Errorf(e.Error())
	}
	fmt.Println(m["ddd"])
	fmt.Println(m["hgi"])

	if m["hgi"] != "1313" {
		t.Errorf("bad group id for hgi, should be 1313")
	}
	if m["root"] != "0" {
		t.Errorf("bad group id for root, should be 0")
	}
}
