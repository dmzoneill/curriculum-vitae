<?php

/**
 * PHP version 7
 * 
 * @category cv generator
 * @package  Template_Class
 * @author   Author <dmz.oneill@gmail.com>
 * @license  Apache2 license
 * @link     fio.ie
 * @file
 * Generate cv.php
 */

$cv_details = getenv("cv_file");
$template = getenv("template_file");
$out_html = getenv("output_file");

$template_html = file_get_contents($template);
$cv_yaml = file_get_contents($cv_details);
$cv_yaml = yaml_parse($cv_yaml);

/**
 * Re-usable function to replace strings or arrays of strings
 */
function section_replace_scalars($section, $replacements)
{
    if (stristr($section, "{list_item}")) {
        if (gettype($replacements) == "string") {
            $section = str_replace("{list_item}", $replacements . "\n", $section);
        } else {
            $details = "";
            foreach ($replacements as $X) {
                $copy = $section;
                $copy = str_replace("{list_item}", trim($X) . "\n", $copy);
                $details .= $copy;
            }
            $section = $details;
        }
    } else {
        preg_match_all("/\{(.*?)\}/", $section, $matches, PREG_OFFSET_CAPTURE);
        foreach ($matches[1] as $key => $value) {
            $section = str_replace("{" . $value[0] . "}", trim($replacements[$value[0]]) . "\n", $section);
        }
    }
    return $section;
}

/**
 * Replace references
 */
function references()
{
    global $template_html, $cv_yaml;
    preg_match("/<references>(.*?)<\/references>/ms", $template_html, $match);

    $replacement = "";
    foreach ($cv_yaml["references"] as $ref) {
        $replacement .= section_replace_scalars($match[1], $ref);
    }

    $template_html = preg_replace("/<references>(.*?)<\/references>/ms", $replacement, $template_html);
}

/**
 * Replace pages
 */
function pages()
{
    global $template_html, $cv_yaml;

    for ($count = 0; $count < count($cv_yaml["pages"]); $count++) {
        $X = strval($count + 1);
        preg_match("/<page" . $X . ">(.*?)<\/page" . $X . ">/ms", $template_html, $match);

        $page = $cv_yaml["pages"][$count];
        $jobs = $page["jobs"];

        $replacement = "";
        foreach ($jobs as $job) {
            $job_section = $match[1];

            preg_match("/<roles>(.*?)<\/roles>/ms", $job_section, $role_match);

            $roles_replacement = "";
            foreach ($job["roles"] as $role) {
                $role_section = $role_match[1];
                preg_match("/<details>(.*?)<\/details>/ms", $role_section, $details_match);

                $details_replacement = "";
                foreach ($role["details"] as $detail) {
                    $detail_copy = section_replace_scalars($details_match[1], $detail);
                    $details_replacement .= $detail_copy;
                }
                $role_section = preg_replace("/<details>(.*?)<\/details>/ms", $details_replacement, $role_section);
                $role_section = section_replace_scalars($role_section, $role);
                $roles_replacement .= $role_section;
            }

            $job_section = preg_replace("/<roles>(.*?)<\/roles>/ms", $roles_replacement, $job_section);
            $job_section = section_replace_scalars($job_section, $job);
            $replacement .= $job_section;
        }

        $template_html = preg_replace("/<page" . $X . ">(.*?)<\/page" . $X . ">/ms", $replacement, $template_html);
    }
}

/**
 * Replace roles
 */
function roles()
{
    global $template_html, $cv_yaml;

    $template_html = preg_replace("/{current-role}/ms", $cv_yaml["roles"][0], $template_html);

    preg_match("/<previous-roles>(.*?)<\/previous-roles>/ms", $template_html, $match);

    $rows = "";
    for ($count = 0; $count < count($cv_yaml["roles"]); $count++) {
        if ($count == 0) {
            continue;
        }

        $row = $match[1];
        $row = section_replace_scalars($row, $cv_yaml["roles"][$count]);
        $rows .= $row;
    }

    $template_html = preg_replace("/<previous-roles>(.*?)<\/previous-roles>/ms", $rows, $template_html);
}

/**
 * Replace remaining items
 */
function replace()
{
    global $template_html, $cv_yaml;

    references();
    pages();
    roles();

    foreach ($cv_yaml as $X => $value) {
        if (gettype($cv_yaml[$X]) == "string") {
            $replacement = $cv_yaml[$X];
            if (strstr($replacement, "\\n")) {
                $replacement = str_replace("\\n", "<br/>", $replacement);
            }
            $template_html = str_replace("{" . $X . "}", $cv_yaml[$X], $template_html);
        } else if (gettype($cv_yaml[$X]) == "array") {

            preg_match("/<" . $X . ">(.*?)<\/" . $X . ">/ms", $template_html, $match_instance);

            if (gettype($match_instance) != "array") {
                continue;
            }

            if (count($match_instance) == 0) {
                continue;
            }

            $list_replacement = "";
            foreach ($cv_yaml[$X] as $y) {
                $copy = $match_instance[1];
                if (gettype($y) == "array") {
                    if (isset($y["list"])) {
                        preg_match("/<children>(.*?)<\/children>/ms", $copy, $match);
                        $sublist = section_replace_scalars($match[1], $y["list"]);
                        $copy = preg_replace("/<children>(.*?)<\/children>/ms", $sublist, $copy);
                        $copy = section_replace_scalars($copy, $y["item"]);
                    } else {
                        $copy = preg_replace("/{list_item}.*?<ul.*?<\/ul>/ms", $y["item"], $copy);
                    }
                    $list_replacement .= $copy;
                } else if (gettype($y) == "string") {
                    $copy = section_replace_scalars($copy, $y);
                    $list_replacement .= $copy;
                }
            }

            $template_html = preg_replace("/<" . $X . ">(.*?)<\/" . $X . ">/ms", $list_replacement, $template_html);
        }
    }
}

replace();

file_put_contents($out_html, $template_html);