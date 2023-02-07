// Copyright (c) 2023 David O Neill. All rights reserved.
// Licensed under the Apache2 license
// clang-format off
#include <yaml-cpp/yaml.h>

#include <cstdlib>
#include <exception>
#include <fstream>
#include <iostream>
#include <string>
#include <boost/regex.hpp>
// clang-format on

std::string replaceYamlNode(std::string html, YAML::Node replacement) {
  try {
    std::string copy = html;

    for (YAML::const_iterator it = replacement.begin(); it != replacement.end();
         ++it) {
      boost::regex expr{"\\{" + it->first.as<std::string>() + "\\}"};
      copy = boost::regex_replace(copy, expr,
                                  it->second.as<std::string>().c_str());
    }

    return copy;
  } catch (std::exception &e) {
    std::cerr << e.what() << std::endl;
    return std::string("error");
  }
}

std::string replaceLineItem(std::string html, std::string replacement) {
  try {
    std::string copy = html;
    boost::regex list_item_regex{"\\{list_item}"};
    return boost::regex_replace(copy, list_item_regex, replacement.c_str());
  } catch (std::exception &e) {
    std::cerr << e.what() << std::endl;
    return std::string("error");
  }
}

std::string replaceScalars(std::string html, YAML::Node node) {
  try {
    std::string copy = html;
    std::string key;
    std::string val;

    for (YAML::const_iterator it = node.begin(); it != node.end(); ++it) {
      key = "\\{" + it->first.as<std::string>() + "\\}";

      switch (it->second.Type()) {
      case YAML::NodeType::Scalar:
        val = it->second.as<std::string>();
        copy =
            boost::regex_replace(copy, boost::regex{key.c_str()}, val.c_str());
        break;
      }
    }

    return copy;
  } catch (std::exception &e) {
    std::cerr << e.what() << std::endl;
    return std::string("error");
  }
}

std::string replaceSequences(std::string html, YAML::Node node) {
  try {
    std::string copy = html;
    std::string key;
    std::string regexkey;
    std::string replacement;
    boost::smatch match;

    for (YAML::const_iterator it = node.begin(); it != node.end(); ++it) {
      replacement = "";
      key = it->first.as<std::string>();
      regexkey = "<" + key + ">(.*?)</" + key + ">";
      boost::regex sequence_regex{regexkey};

      if (node[key].Type() != YAML::NodeType::Sequence) {
        continue;
      }

      if (boost::regex_search(copy, match, sequence_regex) == false) {
        continue;
      }

      if (key.compare("interests-oss") == 0) {
        YAML::Node item = node["interests-oss"];
        // for (auto item_it = item.begin(); item_it != item.end(); ++item_it) {
        //   auto key = item_it->first;
        //   cout << key["item"] << "\n" << std::flush;
        //   auto value = item_it->second;
        //   cout << key.Type() << "\n" << std::flush;
        //   cout << value.Type() << "\n" << std::flush;
        //   cout << key.as<std::string>() << "\n" << std::flush;
        //   cout << value.as<std::string>() << "\n" << std::flush;
        // }
        continue;
      }

      YAML::Node items = node[key];
      for (auto seq = items.begin(); seq != items.end(); ++seq) {
        replacement += replaceLineItem(match[1], seq->as<std::string>());
      }

      copy = boost::regex_replace(copy, sequence_regex, replacement.c_str());
    }

    return copy;
  } catch (std::exception &e) {
    std::cerr << e.what() << std::endl;
    return std::string("error");
  }
}

std::string references(std::string html, YAML::Node node) {
  try {
    std::string copy = html;
    boost::smatch match;

    boost::regex references_regex{"<references>(.*?)</references>"};

    if (boost::regex_search(copy, match, references_regex) == false) {
      std::cout << "No references match\n";
      return std::string("error");
    }

    std::string replacement;

    YAML::Node references = node["references"];
    for (YAML::iterator it = references.begin(); it != references.end(); ++it) {
      const YAML::Node &reference = *it;
      replacement += replaceYamlNode(match[1], reference);
    }

    return boost::regex_replace(copy, references_regex, replacement.c_str());
  } catch (std::exception &e) {
    std::cerr << e.what() << std::endl;
    return std::string("error");
  }
}

std::string roles(std::string html, YAML::Node node) {
  try {
    std::string copy = html;
    boost::regex current_role{"\\{current-role}"};

    copy = boost::regex_replace(copy, current_role,
                                node["roles"][0].as<std::string>());

    boost::regex previous_roles_regex{"<previous-roles>(.*?)</previous-roles>"};

    boost::smatch match;

    if (boost::regex_search(copy, match, previous_roles_regex) == false) {
      std::cout << "No previous roles match\n";
      return std::string("error");
    }

    std::string replacement;

    YAML::Node roles = node["roles"];
    YAML::iterator it = roles.begin();
    ++it;
    for (it; it != roles.end(); ++it) {
      const YAML::Node &role = *it;
      replacement += replaceLineItem(match[1], role.as<std::string>());
    }

    return boost::regex_replace(copy, previous_roles_regex,
                                replacement.c_str());
  } catch (std::exception &e) {
    std::cerr << e.what() << std::endl;
    return std::string("error");
  }
}

std::string pages(std::string section, YAML::Node node) {
  try {
    std::string result = section;

    YAML::Node pages = node["pages"];

    for (int count = 0; count < pages.size(); count++) {
      std::string X = std::to_string(count + 1);

      boost::smatch match;

      boost::regex pages_regex{"<page" + X + ">(.*?)</page" + X + ">"};

      if (boost::regex_search(result, match, pages_regex) == false) {
        std::cout << "No page match\n";
        return std::string("error");
      }

      YAML::Node page = pages[count];
      YAML::Node jobs = page["jobs"];

      std::string replacement;

      for (YAML::iterator job_it = jobs.begin(); job_it != jobs.end();
           ++job_it) {
        YAML::Node job = *job_it;
        std::string jobSection = match[1];
        boost::smatch roleMatch;

        if (boost::regex_search(jobSection, roleMatch,
                                boost::regex{"<roles>(.*?)</roles>"}) ==
            false) {
          std::cout << "No roles match\n";
          return std::string("error");
        }

        std::string rolesReplacement;
        YAML::Node roles = job["roles"];

        for (YAML::iterator role_it = roles.begin(); role_it != roles.end();
             ++role_it) {
          YAML::Node role = *role_it;
          std::string roleSection = roleMatch[1];
          boost::smatch detailsMatch;

          if (boost::regex_search(jobSection, detailsMatch,
                                  boost::regex{"<details>(.*?)</details>"}) ==
              false) {
            std::cout << "No details match\n";
            return std::string("error");
          }

          std::string detailsReplacement;
          YAML::Node details = role["details"];

          for (YAML::iterator details_it = details.begin();
               details_it != details.end(); ++details_it) {
            YAML::Node detail = *details_it;
            detailsReplacement +=
                replaceLineItem(detailsMatch[1], detail.as<std::string>());
          }

          roleSection = boost::regex_replace(
              roleSection, boost::regex{"<details>(.*?)</details>"},
              detailsReplacement.c_str());
          roleSection = replaceScalars(roleSection, role);
          rolesReplacement += roleSection;
        }

        jobSection = boost::regex_replace(jobSection,
                                          boost::regex{"<roles>(.*?)</roles>"},
                                          rolesReplacement.c_str());
        jobSection = replaceScalars(jobSection, job);
        replacement += jobSection;
      }

      result = boost::regex_replace(
          result, boost::regex{"<page" + X + ">(.*?)</page" + X + ">"},
          replacement.c_str());
    }
    return result;
  } catch (std::exception &e) {
    std::cerr << e.what() << std::endl;
    return std::string("error");
  }
}

int replace() {
  try {
    std::string cv_file = std::string(std::getenv("cv_file"));
    std::string template_file = std::string(std::getenv("template_file"));
    std::string output_file = std::string(std::getenv("output_file"));

    YAML::Node cvYaml = YAML::LoadFile(cv_file);
    std::stringstream buffer;
    std::string templateHtml;

    std::ifstream t(template_file);
    buffer << t.rdbuf();
    templateHtml = buffer.str();

    templateHtml = references(templateHtml, cvYaml);
    templateHtml = roles(templateHtml, cvYaml);
    templateHtml = pages(templateHtml, cvYaml);
    templateHtml = replaceScalars(templateHtml, cvYaml);
    templateHtml = replaceSequences(templateHtml, cvYaml);

    std::ofstream out(output_file.c_str());
    out << templateHtml.c_str();
    out.close();

    return 0;
  } catch (std::exception &e) {
    std::cerr << e.what() << std::endl;
    return 1;
  }
}

int main() {
  try {
    return replace();
  } catch (std::exception &e) {
    std::cerr << e.what() << std::endl;
    return 1;
  }
}
