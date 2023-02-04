#!/usr/bin/env ruby
# frozen_string_literal: true

# dmz.oneill@gmail.com

require 'yaml'

# rubocop:disable Metrics/MethodLength, Metrics/AbcSize
def section_replace_scalars(section, replacements)
  if replacements.instance_of?(String) && section.include?('{list_item}')
    section.gsub('{list_item}', "#{replacements}\n")
  elsif section.include? '{list_item}'
    details = ''
    replacements.each do |x|
      copy = section
      copy = copy.gsub('{list_item}', "#{x.strip}\n")
      details += copy
    end
    details
  else
    matches = section.scan(/\{(.*?)\}/i)
    matches.each do |x|
      section = section.gsub("{#{x[0]}}", "#{replacements[x[0]].strip}\n")
    end
    section
  end
end

# rubocop:enable Metrics/MethodLength, Metrics/AbcSize

def references(template_html, cv_yaml)
  match = template_html.scan(%r{<references>(.*?)</references>}ms)

  replacement = ''
  cv_yaml['references'].each do |x|
    replacement += section_replace_scalars(match[0][0], x)
  end

  template_html.gsub(%r{<references>(.*?)</references>}ms, replacement)
end

# rubocop:disable Metrics/MethodLength, Metrics/BlockLength, Metrics/AbcSize
def pages(template_html, cv_yaml)
  (0..cv_yaml['pages'].length - 1).each do |count|
    x = (count + 1).to_s
    match = template_html.scan(%r{<page#{x}>(.*?)</page#{x}>}ms)

    page = cv_yaml['pages'][count]
    jobs = page['jobs']

    replacement = ''
    jobs.each do |job|
      job_section = match[0][0]
      role_match = job_section.scan(%r{<roles>(.*?)</roles>}ms)

      roles_replacement = ''
      job['roles'].each do |role|
        role_section = role_match[0][0]
        details_match = job_section.scan(%r{<details>(.*?)</details>}m)

        details_replacement = ''
        role['details'].each do |detail|
          detail_copy = section_replace_scalars(details_match[0][0], detail)
          details_replacement += detail_copy
        end
        role_section = role_section.gsub(%r{<details>(.*?)</details>}ms, details_replacement)
        role_section = section_replace_scalars(role_section, role)
        roles_replacement += role_section
      end

      job_section = job_section.gsub(%r{<roles>(.*?)</roles>}ms, roles_replacement)
      job_section = section_replace_scalars(job_section, job)
      replacement += job_section
    end

    template_html = template_html.gsub(%r{<page#{x}>(.*?)</page#{x}>}ms, replacement)
  end
  template_html
end

# rubocop:enable Metrics/MethodLength, Metrics/BlockLength, Metrics/AbcSize

def roles(template_html, cv_yaml)
  template_html = template_html.gsub(/{current-role}/ms, cv_yaml['roles'][0])

  match = template_html.scan(%r{<previous-roles>(.*?)</previous-roles>}ms)
  rows = ''
  (1..cv_yaml['roles'].length - 1).each do |count|
    next if count.zero?

    row = match[0][0]
    row = section_replace_scalars(row, cv_yaml['roles'][count])
    rows += row
  end

  template_html.gsub(%r{<previous-roles>(.*?)</previous-roles>}ms, rows)
end

# rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength, Metrics/BlockLength, Metrics/AbcSize
def replace_one(template_html, cv_yaml)
  cv_yaml.each do |x, value|
    if value.instance_of?(String)
      replacement = value.gsub('\\n', '<br/>') if value.include? '\\n'
      template_html = template_html.gsub("{#{x}}", replacement)
    else
      match_instance = template_html.scan(%r{<#{x}>(.*?)</#{x}>}ms)

      next if match_instance.instance_of?(Array) == false

      next if match_instance.empty?

      list_replacement = ''
      cv_yaml[x].each do |y|
        copy = match_instance[0][0]
        if y.instance_of?(String) == false
          if y.include? 'list'
            match = copy.scan(%r{<children>(.*?)</children>}ms)
            sublist = section_replace_scalars(match[0][0], y['list'])
            copy = copy.gsub(%r{<children>(.*?)</children>}ms, sublist)
            copy = section_replace_scalars(copy, y['item'])
          else
            copy = copy.gsub(%r{{list_item}.*?<ul.*?</ul>}ms, y['item'])
          end
          list_replacement += copy
        elsif y.instance_of?(String)
          copy = section_replace_scalars(copy, y)
          list_replacement += copy
        end
      end

      template_html = template_html.gsub(%r{<#{x}>(.*?)</#{x}>}ms, list_replacement)
    end
  end
end

# rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength, Metrics/BlockLength, Metrics/AbcSize

def replace
  cv_details = ENV['cv_file']
  template = ENV['template_file']
  out_html = ENV['output_file']

  template_html = File.read(template)
  cv_yaml = YAML.safe_load(File.read(cv_details))

  template_html = references(template_html, cv_yaml)
  template_html = pages(template_html, cv_yaml)
  template_html = roles(template_html, cv_yaml)

  File.write(out_html, template_html)
end

replace
