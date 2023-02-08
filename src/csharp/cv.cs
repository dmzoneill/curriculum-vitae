using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using YamlDotNet.RepresentationModel;
using System.Text.RegularExpressions;

namespace cv
{
    class Cv
    {
        private YamlMappingNode rootNode;
        private string html_template;
        private string yaml_cv;
        private string html_out_file;

        public Cv()
        {
            this.loadValues();

            this.replace_references();
            this.replace_roles();
            this.replace_pages();

            foreach (var entry in rootNode.Children)
            {
                if (entry.Value.NodeType == YamlNodeType.Sequence)
                {
                    var pattern =
                        @"<"
                        + ((YamlScalarNode)entry.Key).Value
                        + ">(.*?)</"
                        + ((YamlScalarNode)entry.Key).Value
                        + ">";

                    var m = Regex.Match(
                        this.html_template,
                        pattern,
                        RegexOptions.Multiline | RegexOptions.Singleline
                    );

                    var replacement = this.replace_sequence(
                        m.Groups[1].ToString(),
                        (YamlSequenceNode)entry.Value
                    );

                    this.html_template = Regex.Replace(
                        this.html_template,
                        pattern,
                        replacement,
                        RegexOptions.Multiline | RegexOptions.Singleline
                    );
                }
            }

            foreach (var entry in rootNode.Children)
            {
                if (entry.Value.NodeType == YamlNodeType.Scalar)
                {
                    this.html_template = this.replace_scalar(
                        this.html_template,
                        (YamlScalarNode)entry.Key,
                        (YamlScalarNode)entry.Value
                    );
                }
            }

            File.WriteAllText(this.html_out_file, this.html_template);
        }

        private void loadValues()
        {
            try
            {
                string template_file = Environment.GetEnvironmentVariable("template_file");
                this.html_template = File.ReadAllText(template_file);

                this.html_out_file = Environment.GetEnvironmentVariable("output_file");

                string cv_file = Environment.GetEnvironmentVariable("cv_file");
                this.yaml_cv = File.ReadAllText(cv_file);
                var input = new StringReader(this.yaml_cv);
                var yaml = new YamlStream();
                yaml.Load(input);

                this.rootNode = (YamlMappingNode)yaml.Documents[0].RootNode;
            }
            catch (Exception e)
            {
                Console.WriteLine("Exception caught: {0}", e);
            }
        }

        private string replace_scalar(
            string html,
            YamlScalarNode key_node,
            YamlScalarNode value_node
        )
        {
            try
            {
                if (html.IndexOf("{" + key_node.Value + "}", StringComparison.Ordinal) > -1)
                {
                    html = Regex.Replace(html, "\\{" + key_node.Value + "\\}", value_node.Value);
                }
                else if (html.IndexOf("{list_item}", StringComparison.Ordinal) > -1)
                {
                    html = html.Replace("{list_item}", value_node.Value);
                }
                else
                {
                    // not sure
                }
            }
            catch (Exception e)
            {
                Console.WriteLine("Exception caught: {0}", e);
            }

            return html;
        }

        private string replace_scalars(string html, YamlMappingNode node)
        {
            try
            {
                if (html.IndexOf("<children>", StringComparison.Ordinal) > -1 )
                {
                    string copy = html;
                    var pattern = @"<children>(.*?)</children>";
                    var m = Regex.Match(
                        copy,
                        pattern,
                        RegexOptions.Multiline | RegexOptions.Singleline
                    );

                    var header = node.Children[0];
                    var header_title = (YamlScalarNode)header.Value;

                    if (node.Children.Count > 1)
                    {
                        var items = node.Children[1];
                        var subitems = (YamlSequenceNode)items.Value;

                        if (m.Success)
                        {
                            var sublist = "";

                            foreach (var childentry in subitems)
                            {
                                string replaceitem = m.Groups[1].ToString();
                                sublist += replaceitem.Replace("{list_item}", ((YamlScalarNode)childentry).ToString());
                            }

                            copy = Regex.Replace(
                                copy,
                                pattern,
                                sublist,
                                RegexOptions.Multiline | RegexOptions.Singleline
                            );
                        }
                    }
                    else
                    {
                        copy = Regex.Replace(
                            copy,
                            @"<ul.*?</ul>",
                            "",
                            RegexOptions.Multiline | RegexOptions.Singleline
                        );
                    }

                    copy = copy.Replace("{list_item}", header_title.ToString());
                    copy = Regex.Replace(
                        copy,
                        pattern,
                        "",
                        RegexOptions.Multiline | RegexOptions.Singleline
                    );

                    return copy;
                }

                if (html.IndexOf("{list_item}", StringComparison.Ordinal) > -1)
                {
                    string replacement = "";

                    foreach (var entry in node.Children)
                    {
                        string copy = html;
                        string val = "";

                        if (entry.Value.NodeType == YamlNodeType.Sequence)
                        {
                            val = replace_sequence(html, (YamlSequenceNode)entry.Value);
                        }
                        else
                        {
                            val = ((YamlScalarNode)entry.Value).Value;
                        }

                        copy = Regex.Replace(copy, "\\{list_item\\}", val, RegexOptions.Multiline | RegexOptions.Singleline);
                        replacement += copy;
                    }

                    html = replacement;
                }
                else
                {
                    foreach (var entry in node.Children)
                    {
                        var key = ((YamlScalarNode)entry.Key).Value;
                        string val = "";
                        if (entry.Value.NodeType == YamlNodeType.Sequence)
                        {
                            val = replace_sequence(html, (YamlSequenceNode)entry.Value);
                        }
                        else
                        {
                            val = ((YamlScalarNode)entry.Value).Value;
                        }
                        html = Regex.Replace(html, "\\{" + key + "\\}", val);
                    }
                }
            }
            catch (Exception e)
            {
                Console.WriteLine("Exception caught: {0}", e);
            }

            return html;
        }

        private string replace_sequence(string html, YamlSequenceNode sequence)
        {
            var replacement = "";
            try
            {
                foreach (var X in sequence)
                {
                    if (X.NodeType == YamlNodeType.Mapping)
                    {                        
                        YamlMappingNode item = (YamlMappingNode)X;
                        replacement += this.replace_scalars(html, item);
                    }
                    else if (X.NodeType == YamlNodeType.Scalar)
                    {
                        replacement += this.replace_scalar(
                            html,
                            (YamlScalarNode)X,
                            (YamlScalarNode)X
                        );
                    }
                }
            }
            catch (Exception e)
            {
                Console.WriteLine("Exception caught: {0}", e);
            }
            return replacement;
        }

        private void replace_roles()
        {
            try
            {
                YamlNode outnode = null;
                YamlSequenceNode roles = null;

                this.rootNode.Children.TryGetValue("roles", out outnode);
                roles = (YamlSequenceNode)outnode;

                this.html_template = this.html_template.Replace(
                    "{current-role}",
                    ((YamlScalarNode)roles[0]).Value
                );

                var pattern = @"<previous-roles>(.*?)</previous-roles>";
                var m = Regex.Match(
                    this.html_template,
                    pattern,
                    RegexOptions.Multiline | RegexOptions.Singleline
                );

                if (!m.Success)
                    return;

                roles.Children.RemoveAt(0);

                var replacement = this.replace_sequence(m.Groups[1].ToString(), roles);

                this.html_template = Regex.Replace(
                    this.html_template,
                    pattern,
                    replacement,
                    RegexOptions.Multiline | RegexOptions.Singleline
                );
            }
            catch (Exception e)
            {
                Console.WriteLine("Exception caught: {0}", e);
            }
        }

        private void replace_pages()
        {
            YamlNode outpages = null;
            YamlSequenceNode pages = null;
            this.rootNode.Children.TryGetValue("pages", out outpages);
            pages = (YamlSequenceNode)outpages;
            var count = 0;

            foreach (var page in pages.Children)
            {
                var X = (count + 1).ToString();

                var page_pattern = @"<page" + X + ">(.*?)</page" + X + ">";
                var m_page = Regex.Match(
                    this.html_template,
                    page_pattern,
                    RegexOptions.Multiline | RegexOptions.Singleline
                );

                if (!m_page.Success)
                    return;

                var jobs = (YamlSequenceNode)((YamlMappingNode)page)["jobs"];

                var replacement = "";

                foreach (var job in jobs.Children)
                {
                    var job_section = m_page.Groups[1].ToString();
                    var job_pattern = @"<roles>(.*?)</roles>";
                    var m_job = Regex.Match(
                        job_section,
                        job_pattern,
                        RegexOptions.Multiline | RegexOptions.Singleline
                    );

                    var roles_replacement = "";
                    var roles = (YamlSequenceNode)((YamlMappingNode)job)["roles"];

                    foreach (var role in roles.Children)
                    {
                        var role_section = m_job.Groups[1].ToString();
                        var role_pattern = @"<details>(.*?)</details>";
                        var m_role = Regex.Match(
                            role_section,
                            role_pattern,
                            RegexOptions.Multiline | RegexOptions.Singleline
                        );
                        var details = (YamlSequenceNode)((YamlMappingNode)role)["details"];

                        var details_replacement = "";
                        foreach (var detail in details.Children)
                        {
                            var detail_copy = this.replace_scalar(
                                m_role.Groups[1].ToString(),
                                (YamlScalarNode)detail,
                                (YamlScalarNode)detail
                            );
                            details_replacement += detail_copy;
                        }

                        role_section = Regex.Replace(
                            role_section,
                            role_pattern,
                            details_replacement,
                            RegexOptions.Multiline | RegexOptions.Singleline
                        );

                        role_section = this.replace_scalars(role_section, (YamlMappingNode)role);

                        roles_replacement += role_section;
                    }

                    job_section = Regex.Replace(
                        job_section,
                        job_pattern,
                        roles_replacement,
                        RegexOptions.Multiline | RegexOptions.Singleline
                    );

                    job_section = this.replace_scalars(job_section, (YamlMappingNode)job);

                    replacement += job_section;
                }

                this.html_template = Regex.Replace(
                    this.html_template,
                    page_pattern,
                    replacement,
                    RegexOptions.Multiline | RegexOptions.Singleline
                );

                count += 1;
            }
        }

        private void replace_references()
        {
            try
            {
                var pattern = @"<references>(.*?)</references>";
                var m = Regex.Match(
                    this.html_template,
                    pattern,
                    RegexOptions.Multiline | RegexOptions.Singleline
                );
                YamlNode outnode = null;
                YamlSequenceNode references = null;

                if (!m.Success)
                    return;

                this.rootNode.Children.TryGetValue("references", out outnode);
                references = (YamlSequenceNode)outnode;

                var replacement = this.replace_sequence(m.Groups[1].ToString(), references);
                this.html_template = Regex.Replace(
                    this.html_template,
                    pattern,
                    replacement,
                    RegexOptions.Multiline | RegexOptions.Singleline
                );
            }
            catch (Exception e)
            {
                Console.WriteLine("Exception caught: {0}", e);
            }
        }

        public static void Main(string[] args)
        {
            var x = new Cv();
        }
    }
}
