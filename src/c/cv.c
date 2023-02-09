// Copyright (c) 2023 DAvid O Neill. All rights reserved.
// Licensed under the Apache2 license
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_LEN 500

char *section_replace_scalars(char *section, char *replacements)
{
    char *res = (char *)malloc(MAX_LEN);
    memset(res, 0, MAX_LEN);

    if (strstr(section, "{list_item}") != NULL)
    {
        if (strstr(replacements, "\n") != NULL)
        {
            sprintf(res, "%s", replacements);
        }
        else
        {
            sprintf(res, "%s\n", replacements);
        }
    }
    else
    {
        char *start = strstr(section, "{");
        char *end = strstr(section, "}");

        int count = 0;
        while (start != NULL && end != NULL)
        {
            char *temp = (char *)malloc(MAX_LEN);
            memset(temp, 0, MAX_LEN);

            int len = end - start - 1;
            strncpy(temp, start + 1, len);
            temp[len] = '\0';

            char *replacement = (char *)malloc(MAX_LEN);
            memset(replacement, 0, MAX_LEN);

            sprintf(replacement, "%s\n", replacements);

            char *replace_start = strstr(replacements, temp);
            if (replace_start != NULL)
            {
                replace_start += strlen(temp) + 2;

                char *replace_end = strstr(replace_start, "\n");
                int replace_len = replace_end - replace_start;

                char *final_replacement = (char *)malloc(replace_len + 1);
                memset(final_replacement, 0, replace_len + 1);

                strncpy(final_replacement, replace_start, replace_len);

                sprintf(res, "%s", final_replacement);
                free(final_replacement);
            }

            free(temp);
            free(replacement);

            start = strstr(end, "{");
            end = strstr(start, "}");
            count++;
        }
    }

    return res;
}




void replace() {
    char *cv_details = getenv("cv_file");
    char *template = getenv("template_file");
    char *out_html = getenv("output_file");

    char template_html[1000];
    char cv_yaml[1000];

    FILE *template_file = fopen(template, "r");
    fread(template_html, 1, sizeof(template_html), template_file);
    fclose(template_file);

    FILE *cv_details_file = fopen(cv_details, "r");
    fread(cv_yaml, 1, sizeof(cv_yaml), cv_details_file);
    fclose(cv_details_file);

    // The functionality of the references, pages, and roles functions
    // would need to be implemented separately in C

    FILE *out_html_file = fopen(out_html, "w");
    fwrite(template_html, 1, strlen(template_html), out_html_file);
    fclose(out_html_file);
}

int main(int argc, char *argv[]) {
    replace();
    return 0;
}