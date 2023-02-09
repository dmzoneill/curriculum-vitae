Imports System.IO
Imports System.Text.RegularExpressions
Imports YamlDotNet.Serialization

Module CV

    Public Function SectionReplaceScalars(section As String, replacements As Object) As String
        If TypeOf replacements Is String AndAlso section.Contains("{list_item}") Then
            Return section.Replace("{list_item}", replacements & vbCrLf)
        ElseIf section.Contains("{list_item}") Then
            Dim details As String = ""
            For Each x In replacements
                Dim copy As String = section
                copy = copy.Replace("{list_item}", x.Trim() & vbCrLf)
                details &= copy
            Next
            Return details
        Else
            Dim matches As MatchCollection = Regex.Matches(section, "\{(.*?)\}", RegexOptions.IgnoreCase)
            For Each x As Match In matches
                section = section.Replace("{" & x.Groups(1).Value & "}", replacements(x.Groups(1).Value).ToString().Trim() & vbCrLf)
            Next
            Return section
        End If
    End Function


    Public Function References(template_html As String, cv_yaml As Object) As String
        Dim match As MatchCollection = Regex.Matches(template_html, "<references>(.*?)</references>", RegexOptions.Singleline)

        Dim replacement As String = ""
        For Each x As Object In cv_yaml("references")
            replacement += Section_Replace_Scalars(match(0).Groups(1).Value, x)
        Next

        Return Regex.Replace(template_html, "<references>(.*?)</references>", replacement, RegexOptions.Singleline)
    End Function


    Public Function Pages(template_html As String, cv_yaml As Object) As String
        For count As Integer = 0 To cv_yaml("pages").Count - 1
            Dim x As String = (count + 1).ToString()
            Dim match As MatchCollection = Regex.Matches(template_html, "\<page" & x & "\>(.*?)\</page" & x & "\>", RegexOptions.Singleline Or RegexOptions.Multiline)

            Dim page As Object = cv_yaml("pages")(count)
            Dim jobs As Object = page("jobs")

            Dim replacement As String = ""
            For Each job As Object In jobs
            Dim job_section As String = match(0).Groups(1).Value
            Dim role_match As MatchCollection = Regex.Matches(job_section, "\<roles\>(.*?)\</roles\>", RegexOptions.Singleline Or RegexOptions.Multiline)

            Dim roles_replacement As String = ""
            For Each role As Object In job("roles")
                Dim role_section As String = role_match(0).Groups(1).Value
                Dim details_match As MatchCollection = Regex.Matches(role_section, "\<details\>(.*?)\</details\>", RegexOptions.Singleline Or RegexOptions.Multiline)

                Dim details_replacement As String = ""
                For Each detail As Object In role("details")
                Dim detail_copy As String = Section_replace_scalars(details_match(0).Groups(1).Value, detail)
                details_replacement &= detail_copy
                Next
                role_section = role_section.Replace(Regex.Match(role_section, "\<details\>(.*?)\</details\>", RegexOptions.Singleline Or RegexOptions.Multiline).Value, details_replacement)
                role_section = Section_replace_scalars(role_section, role)
                roles_replacement &= role_section
            Next

            job_section = job_section.Replace(Regex.Match(job_section, "\<roles\>(.*?)\</roles\>", RegexOptions.Singleline Or RegexOptions.Multiline).Value, roles_replacement)
            job_section = Section_replace_scalars(job_section, job)
            replacement &= job_section
            Next

            template_html = template_html.Replace(Regex.Match(template_html, "\<page" & x & "\>(.*?)\</page" & x & "\>", RegexOptions.Singleline Or RegexOptions.Multiline).Value, replacement)
        Next
        Return template_html
    End Function


    Public Sub ReplaceOne(ByRef templateHtml As String, cvYaml As Dictionary(Of String, Object))
        For Each item In cvYaml
            Dim x As String = item.Key
            Dim value As Object = item.Value

            If TypeOf value Is String Then
                Dim replacement As String = value
                If value.ToString().Contains("\n") Then
                    replacement = value.ToString().Replace("\n", "<br/>")
                End If
                templateHtml = templateHtml.Replace("{" & x & "}", replacement)
            Else
                Dim matchInstance As MatchCollection = Regex.Matches(templateHtml, "<" & x & ">(.*?)</" & x & ">", RegexOptions.Singleline)

                If Not TypeOf matchInstance Is MatchCollection Then
                    Continue For
                End If

                If matchInstance.Count = 0 Then
                    Continue For
                End If

                Dim listReplacement As String = ""
                For Each y In cvYaml(x)
                    Dim copy As String = matchInstance(0).Groups(1).Value

                    If Not TypeOf y Is String Then
                        If y.ContainsKey("list") Then
                            Dim subMatch As MatchCollection = Regex.Matches(copy, "<children>(.*?)</children>", RegexOptions.Singleline)
                            Dim sublist As String = sectionReplaceScalars(subMatch(0).Groups(1).Value, y("list"))
                            copy = Regex.Replace(copy, "<children>(.*?)</children>", sublist, RegexOptions.Singleline)
                            copy = sectionReplaceScalars(copy, y("item"))
                        Else
                            copy = Regex.Replace(copy, "{list_item}.*?<ul.*?</ul>", y("item"), RegexOptions.Singleline)
                        End If
                        listReplacement += copy
                    ElseIf TypeOf y Is String
                        copy = sectionReplaceScalars(copy, y.ToString())
                        listReplacement += copy
                    End If
                Next

                templateHtml = Regex.Replace(templateHtml, "<" & x & ">(.*?)</" & x & ">", listReplacement, RegexOptions.Singleline)
            End If
        Next
    End Sub

    Public Sub Replace()
        Dim cvDetails As String = Environment.GetEnvironmentVariable("cv_file")
        Dim template As String = Environment.GetEnvironmentVariable("template_file")
        Dim outHtml As String = Environment.GetEnvironmentVariable("output_file")

        Dim templateHtml As String = File.ReadAllText(template)
        Dim cvYaml As Object = Nothing

        Using sr As New StreamReader(cvDetails)
            cvYaml = Yaml.SafeLoad(sr)
        End Using

        templateHtml = references(templateHtml, cvYaml)
        templateHtml = pages(templateHtml, cvYaml)
        templateHtml = roles(templateHtml, cvYaml)

        File.WriteAllText(outHtml, templateHtml)
    End Sub

    Sub Main()
        Replace()
    End Sub

End Module