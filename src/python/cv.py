#!/usr/bin/env python3

import os
import re
import yaml

cv_details = os.getenv("cv_file")
template = os.getenv("template_file")
out_html = os.getenv("output_file")

template_html = open(template, "r").read()
cv_yaml = open(cv_details, "r").read()
cv_yaml = yaml.safe_load(cv_yaml)


def section_replace_scalars(section, replacements):
    if "{list_item}" in section:
        if type(replacements) == str:
            section = section.replace("{list_item}", replacements + "\n")
        else:
            details = ""
            for X in replacements:
                copy = section
                copy = copy.replace("{list_item}", X.strip() + "\n")
                details += copy
            section = details
    else:
        matches = re.findall("{(.*?)}", section, re.M | re.S)
        for X in matches:
            section = re.sub(
                "{" + X + "}",
                replacements[X].strip() + "\n",
                section,
                flags=re.I | re.M | re.S,
            )
    return section


def references():
    global template_html
    match = re.search("<references>(.*?)</references>", template_html, re.M | re.S)
    match = match.group(1).strip()

    replacement = ""
    for ref in cv_yaml["references"]:
        replacement += section_replace_scalars(match, ref)

    template_html = re.sub(
        "<references>(.*?)</references>",
        replacement,
        template_html,
        flags=re.I | re.M | re.S,
    )


def pages():
    global template_html

    for count, value in enumerate(cv_yaml["pages"]):
        X = str(count + 1)
        match = re.search(
            "<page" + X + ">(.*?)</page" + X + ">", template_html, re.M | re.S
        )
        match = match.group(1).strip()

        page = cv_yaml["pages"][count]
        jobs = page["jobs"]

        replacement = ""
        for job in jobs:
            job_section = match
            role_match = re.search("<roles>(.*?)</roles>", job_section, re.M | re.S)
            role_match = role_match.group(1).strip()

            roles_replacement = ""
            for role in job["roles"]:
                role_section = role_match

                details_match = re.search(
                    "<details>(.*?)</details>", role_section, re.M | re.S
                )
                details_match = details_match.group(1).strip()

                details_replacement = ""
                for detail in role["details"]:
                    detail_copy = section_replace_scalars(details_match, detail)
                    details_replacement += detail_copy

                role_section = re.sub(
                    "<details>(.*?)</details>",
                    details_replacement,
                    role_section,
                    flags=re.I | re.M | re.S,
                )

                role_section = section_replace_scalars(role_section, role)

                roles_replacement += role_section

            job_section = re.sub(
                "<roles>(.*?)</roles>",
                roles_replacement,
                job_section,
                flags=re.I | re.M | re.S,
            )

            job_section = section_replace_scalars(job_section, job)

            replacement += job_section

        template_html = re.sub(
            "<page" + X + ">(.*?)</page" + X + ">",
            replacement,
            template_html,
            flags=re.I | re.M | re.S,
        )


def roles():
    global template_html

    template_html = re.sub(
        "{current-role}",
        cv_yaml["roles"][0],
        template_html,
        flags=re.I | re.M | re.S,
    )

    match = re.search(
        "<previous-roles>(.*?)</previous-roles>", template_html, re.M | re.S
    )
    match = match.group(1).strip()

    rows = ""
    for count, value in enumerate(cv_yaml["roles"]):
        if count == 0:
            continue

        row = match
        row = section_replace_scalars(row, value)
        rows += row

    template_html = re.sub(
        "<previous-roles>(.*?)</previous-roles>",
        rows,
        template_html,
        flags=re.I | re.M | re.S,
    )


def replace():
    global template_html

    references()
    pages()
    roles()

    for X in cv_yaml.keys():
        if type(cv_yaml[X]) == str:
            replacement = cv_yaml[X]
            if "\\n" in replacement:
                replacement = replacement.replace("\\n", "<br/>")
            template_html = template_html.replace("{" + X + "}", cv_yaml[X])

        elif type(cv_yaml[X]) == list:
            match = re.search(
                "<" + X + ">(.*?)</" + X + ">", template_html, re.M | re.S
            )

            if match == None:
                continue

            match_instance = match.group(1).strip()

            list_replacement = ""
            for y in cv_yaml[X]:
                copy = match_instance
                if type(y) == dict:
                    if "list" in y:
                        match = re.search(
                            "<children>(.*?)</children>", copy, re.M | re.S
                        )
                        match = match.group(1).strip()
                        sublist = section_replace_scalars(match, y["list"])
                        copy = re.sub(
                            "<children>(.*?)</children>",
                            sublist,
                            copy,
                            flags=re.I | re.M | re.S,
                        )
                        copy = section_replace_scalars(copy, y["item"])
                    else:
                        copy = re.sub(
                            "{list_item}.*?<ul.*?<\/ul>",
                            y["item"],
                            copy,
                            flags=re.I | re.M | re.S,
                        )
                    list_replacement += copy

                elif type(y) == str:
                    copy = section_replace_scalars(copy, y)
                    list_replacement += copy

            template_html = re.sub(
                "<" + X + ">(.*?)<\/" + X + ">",
                list_replacement,
                template_html,
                flags=re.I | re.M | re.S,
            )


replace()

open(out_html, "w").write(template_html)
