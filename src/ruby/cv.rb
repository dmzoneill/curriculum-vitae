#!/usr/bin/env ruby

require "yaml"

$cv_details = ENV["cv_file"]
$template = ENV["template_file"]
$out_html = ENV["output_file"]

$template_html = File.read($template)
$cv_yaml = YAML.load(File.read($cv_details))

def section_replace_scalars(section, replacements)
  result = ""

  if replacements.instance_of?(String) and section.include? "{list_item}"
    return section.gsub("{list_item}", replacements + "\n")
  elsif section.include? "{list_item}"
    details = ""
    replacements.each { |x|
      copy = section
      copy = copy.gsub("{list_item}", x.strip + "\n")
      details += copy
    }
    return details
  else
    matches = section.scan(/\{(.*?)\}/i)
    matches.each { |x|
      section = section.gsub("{" + x[0] + "}", replacements[x[0]].strip + "\n")
    }
    return section
  end
  return result
end

def references
  match = $template_html.scan(/<references>(.*?)<\/references>/ms)

  replacement = ""
  $cv_yaml["references"].each { |x|
    replacement += section_replace_scalars(match[0][0], x)
  }

  $template_html = $template_html.gsub(/<references>(.*?)<\/references>/ms, replacement)
end

def pages
  for count in 0..$cv_yaml["pages"].length - 1
    x = (count + 1).to_s
    match = $template_html.scan(/<page#{x}>(.*?)<\/page#{x}>/ms)

    page = $cv_yaml["pages"][count]
    jobs = page["jobs"]

    replacement = ""
    jobs.each { |job|
      job_section = match[0][0]
      role_match = job_section.scan(/<roles>(.*?)<\/roles>/ms)

      roles_replacement = ""
      job["roles"].each { |role|
        role_section = role_match[0][0]
        details_match = job_section.scan(/<details>(.*?)<\/details>/m)

        details_replacement = ""
        role["details"].each { |detail|
          detail_copy = section_replace_scalars(details_match[0][0], detail)
          details_replacement += detail_copy
        }
        role_section = role_section.gsub(/<details>(.*?)<\/details>/ms, details_replacement)
        role_section = section_replace_scalars(role_section, role)
        roles_replacement += role_section
      }

      job_section = job_section.gsub(/<roles>(.*?)<\/roles>/ms, roles_replacement)
      job_section = section_replace_scalars(job_section, job)
      replacement += job_section
    }

    $template_html = $template_html.gsub(/<page#{x}>(.*?)<\/page#{x}>/ms, replacement)
  end
end

def roles
  $template_html = $template_html.gsub(/{current-role}/ms, $cv_yaml["roles"][0])

  match = $template_html.scan(/<previous-roles>(.*?)<\/previous-roles>/ms)
  rows = ""
  for count in 1..$cv_yaml["roles"].length - 1
    if count == 0
      next
    end

    row = match[0][0]
    row = section_replace_scalars(row, $cv_yaml["roles"][count])
    rows += row
  end

  $template_html = $template_html.gsub(/<previous-roles>(.*?)<\/previous-roles>/ms, rows)
end

def replace
  references()
  pages()
  roles()

  $cv_yaml.each { |x, value|
    if value.instance_of?(String)
      replacement = value
      if replacement.include? "\\n"
        replacement = replacement.gsub("\\n", "<br/>")
      end
      $template_html = $template_html.gsub("{" + x + "}", value)
    else
      match_instance = $template_html.scan(/<#{x}>(.*?)<\/#{x}>/ms)

      if match_instance.instance_of?(Array) == false
        next
      end

      if match_instance.length == 0
        next
      end

      list_replacement = ""
      $cv_yaml[x].each { |y|
        copy = match_instance[0][0]
        if y.instance_of?(String) == false
          if y.include? "list"
            match = copy.scan(/<children>(.*?)<\/children>/ms)
            sublist = section_replace_scalars(match[0][0], y["list"])
            copy = copy.gsub(/<children>(.*?)<\/children>/ms, sublist)
            copy = section_replace_scalars(copy, y["item"])
          else
            copy = copy.gsub(/{list_item}.*?<ul.*?<\/ul>/ms, y["item"])
          end
          list_replacement += copy
        elsif y.instance_of?(String)
          copy = section_replace_scalars(copy, y)
          list_replacement += copy
        end
      }

      $template_html = $template_html.gsub(/<#{x}>(.*?)<\/#{x}>/ms, list_replacement)
    end
  }
end

replace()
File.write($out_html, $template_html)
