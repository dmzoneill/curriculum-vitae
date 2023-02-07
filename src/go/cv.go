package main

import (
	"fmt"
	"os"
	"reflect"
	"regexp"
	"strings"

	"strconv"

	"github.com/gookit/goutil/dump"
	"gopkg.in/yaml.v2"
)

func check(e error) {
	if e != nil {
		panic(e)
	}
}

func replaceScalars(template_html string, key interface{}, replacement interface{}) string {
	copy := template_html
	typ := reflect.TypeOf(replacement).Kind()
	if strings.Contains(template_html, "{list_item}") {
		if typ == reflect.Int || typ == reflect.String {
			copy = strings.Replace(copy, "{list_item}", fmt.Sprintf("%s", replacement), -1)
		} else {
			details := ""
			replacements := replacement.([]interface{})
			for _, val := range replacements {
				dupe := copy
				dupe = strings.Replace(copy, "{list_item}", val.(string), -1)
				details += dupe
			}
			copy = details
		}
	} else {
		r, _ := regexp.Compile("(?sm)\\{(.*?)\\}")
		matches := r.FindAllStringSubmatch(copy, -1)
		replacements := replacement.(map[interface{}]interface{})
		for i := 0; i < len(matches); i++ {
			copy = strings.Replace(copy, matches[i][0], replacements[matches[i][1]].(string)+"\n", -1)
		}
	}
	return copy
}

func references(template_html string, m map[string]interface{}) string {
	r, _ := regexp.Compile("(?sm)<references>(.*?)</references>")
	match := r.FindAllStringSubmatch(template_html, -1)[0][1]

	replacement := ""
	copy := ""

	for sk, sv := range m["references"].([]interface{}) {
		copy = match
		copy = replaceScalars(copy, sk, sv)
		replacement += copy
	}

	return r.ReplaceAllString(template_html, replacement)
}

func roles(template_html string, m map[string]interface{}) string {
	current_role := fmt.Sprintf("%s", m["roles"].([]interface{})[0])
	template_html = strings.Replace(template_html, "{current-role}", current_role, -1)
	r, _ := regexp.Compile("(?sm)<previous-roles>(.*?)</previous-roles>")
	match := r.FindAllStringSubmatch(template_html, -1)[0][1]

	rows := ""
	count := 0

	for sk, sv := range m["roles"].([]interface{}) {
		if count == 0 {
			count += 1
			continue
		}

		row := match
		row = replaceScalars(row, sk, sv)
		rows += row
	}

	return r.ReplaceAllString(template_html, rows)
}

func replace_details(html string, details interface{}) string {
	detailsRegex, _ := regexp.Compile("(?sm)<details>(.*?)</details>")
	match := detailsRegex.FindAllStringSubmatch(html, -1)[0][1]
	replacements := ""

	for index, details := range details.([]interface{}) {
		replacements += replaceScalars(match, index, details.(string))
	}

	return detailsRegex.ReplaceAllString(html, replacements)
}

func replace_roles(html string, roles []interface{}) string {
	roleRegex, _ := regexp.Compile("(?sm)<roles>(.*?)</roles>")
	roleMatch := roleRegex.FindAllStringSubmatch(html, -1)[0][1]
	replacements := ""

	for index, vrole := range roles {
		copy := roleMatch
		details := vrole.(map[interface{}]interface{})["details"]
		copy = replace_details(copy, details)
		copy = replaceScalars(copy, index, vrole)
		replacements += copy
	}

	replacements = roleRegex.ReplaceAllString(html, replacements)
	return replacements
}

func replace_jobs(html string, jobs []interface{}) string {
	replacements := ""

	for job_count := 0; job_count < len(jobs); job_count += 1 {
		copy := html
		job := jobs[job_count].(map[interface{}]interface{})
		roles := job["roles"].([]interface{})
		copy = replace_roles(copy, roles)
		copy = replaceScalars(copy, job_count, job)
		replacements += copy
	}
	return replacements
}

func replace_pages(html string, m map[string]interface{}) string {
	count := 0
	for _, page := range m["pages"].([]interface{}) {
		pageNum := strconv.Itoa(count + 1)
		pageRegex, _ := regexp.Compile("(?sm)<page" + pageNum + ">(.*?)</page" + pageNum + ">")
		pageMatch := pageRegex.FindAllStringSubmatch(html, -1)[0][1]
		page := page.(map[interface{}]interface{})
		jobs := page["jobs"].([]interface{})
		html = pageRegex.ReplaceAllString(html, replace_jobs(pageMatch, jobs))
		count += 1
	}
	return html
}

func main() {
	m := make(map[string]interface{})

	cv_yaml, cv_file_err := os.ReadFile(os.Getenv("cv_file"))
	check(cv_file_err)

	template_html_bytes, template_file_err := os.ReadFile(os.Getenv("template_file"))
	check(template_file_err)

	//nolint
	yaml_error := yaml.Unmarshal([]byte(cv_yaml), &m)
	check(yaml_error)

	template_html := string(template_html_bytes)
	template_html = references(template_html, m)
	template_html = roles(template_html, m)
	template_html = replace_pages(template_html, m)

	for kitem, vitem := range m {
		if reflect.TypeOf(vitem).Kind() == reflect.String {
			template_html = strings.Replace(template_html, "{"+kitem+"}", vitem.(string), -1)
		} else if reflect.TypeOf(vitem).Kind() == reflect.Slice {
			customRegex, _ := regexp.Compile("(?sm)<" + kitem + ">(.*?)</" + kitem + ">")
			tagmatch := customRegex.FindAllStringSubmatch(template_html, -1)

			if len(tagmatch) == 0 {
				continue
			}
			match := tagmatch[0][1]
			replacements := ""
			// dump.P(match)

			for _, v := range vitem.([]interface{}) {
				copy := match
				if reflect.TypeOf(v).Kind() != reflect.String {
					cast := v.(map[interface{}]interface{})
					_, ok := cast["list"]
					if ok {
						childrenRegex, _ := regexp.Compile("(?sm)<children>(.*?)</children>")
						childmatch := childrenRegex.FindAllStringSubmatch(copy, -1)[0][1]
						childmatch = replaceScalars(childmatch, nil, cast["list"].(interface{}))
						childmatch = childrenRegex.ReplaceAllString(copy, childmatch)
						childmatch = strings.Replace(childmatch, "{list_item}", cast["item"].(string), -1)
						copy = childmatch
					} else {
						listItemRegex, _ := regexp.Compile("(?sm)\\{list_item}.*?<ul.*?</ul>")
						copy = listItemRegex.ReplaceAllString(copy, cast["item"].(string))
					}
					replacements += copy
				} else if reflect.TypeOf(v).Kind() == reflect.String {
					copy = replaceScalars(copy, 0, v)
					replacements += copy
				}
			}

			template_html = customRegex.ReplaceAllString(template_html, replacements)
		}
	}

	dump.P(template_html)

	output_file := []byte(template_html)
	err := os.WriteFile(os.Getenv("output_file"), output_file, 0644)
	check(err)
}
