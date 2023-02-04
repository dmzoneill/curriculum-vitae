const fs = require('fs')
const yaml = require('js-yaml')

const cvDetails = process.env.cv_file
const template = process.env.template_file
const outHtml = process.env.output_file
let templateHtml = template

let cvYaml = null

function sectionReplaceScalars (section, replacements) {
  if (section.includes('{list_item}')) {
    if (typeof replacements === 'string') {
      section = section.replace('{list_item}', replacements + '\n')
    } else {
      let details = ''
      replacements.forEach((x) => {
        let copy = section
        copy = copy.replace('{list_item}', x.trim() + '\n')
        details += copy
      })
      section = details
    }
  } else {
    const matches = [...section.matchAll(/\{(.*?)\}/g)]
    matches.forEach((x) => {
      section = section.replace(x[0], replacements[x[1]].trim() + '\n')
    })
  }
  return section
}

function references () {
  const match = templateHtml.match(/<references>(.*?)<\/references>/ms)

  let replacement = ''
  cvYaml.references.forEach((ref) => {
    replacement += sectionReplaceScalars(match[1], ref)
  })

  templateHtml = templateHtml.replace(/<references>(.*?)<\/references>/ms, replacement)
}

function roles () {
  templateHtml = templateHtml.replace(/\{current-role\}/ms, cvYaml.roles[0])

  const match = templateHtml.match(/<previous-roles>(.*?)<\/previous-roles>/ms)

  let rows = ''
  for (let count = 0; count < cvYaml.roles.length; count++) {
    if (count === 0) {
      continue
    }

    let row = match[0]
    row = sectionReplaceScalars(row, cvYaml.roles[count])
    rows += row
  }

  templateHtml = templateHtml.replace(/<previous-roles>(.*?)<\/previous-roles>/ms, rows)
}

function pages () {
  for (let count = 0; count < cvYaml.pages.length; count++) {
    const X = (count + 1).toString()
    const match = templateHtml.match(new RegExp('<page' + X + '>(.*?)</page' + X + '>', 'ms'))

    const page = cvYaml.pages[count]
    const jobs = page.jobs

    let replacement = ''
    jobs.forEach((job) => {
      let jobSection = match[1]
      const roleMatch = jobSection.match(/<roles>(.*?)<\/roles>/ms)
      let rolesReplacement = ''

      job.roles.forEach((role) => {
        let roleSection = roleMatch[1]
        const detailsMatch = roleSection.match(/<details>(.*?)<\/details>/ms)
        let detailsReplacement = ''

        role.details.forEach((detail) => {
          detailsReplacement += sectionReplaceScalars(detailsMatch[1], detail)
        })

        roleSection = roleSection.replace(/<details>(.*?)<\/details>/ms, detailsReplacement)
        roleSection = sectionReplaceScalars(roleSection, role)
        rolesReplacement += roleSection
      })

      jobSection = jobSection.replace(/<roles>(.*?)<\/roles>/ms, rolesReplacement)
      jobSection = sectionReplaceScalars(jobSection, job)
      replacement += jobSection
    })

    templateHtml = templateHtml.replace(new RegExp('<page' + X + '>(.*?)</page' + X + '>', 'ms'), replacement)
  }
}

function replace () {
  references()
  pages()
  roles()

  Object.keys(cvYaml).forEach((X) => {
    if (typeof cvYaml[X] === 'string') {
      let replacement = cvYaml[X]
      if (replacement.includes('\\n')) {
        replacement = replacement.replaceAll('\\n', '<br/>')
      }
      templateHtml = templateHtml.replaceAll('{' + X + '}', replacement)
    } else if (Array.isArray(cvYaml[X])) {
      const matchInstance = templateHtml.match(new RegExp('<' + X + '>(.*?)</' + X + '>', 'ms'))

      if (Array.isArray(matchInstance) === false) {
        return
      }

      if (matchInstance.length === 0) {
        return
      }

      let listReplacement = ''
      cvYaml[X].forEach((y) => {
        let copy = matchInstance[1]
        if (typeof y !== 'string') {
          if ('list' in y) {
            const match = copy.match(/<children>(.*?)<\/children>/ms)
            const sublist = sectionReplaceScalars(match[1], y.list)
            copy = copy.replace(/<children>(.*?)<\/children>/ms, sublist)
            copy = sectionReplaceScalars(copy, y.item)
          } else {
            copy = copy.replace(/\{list_item\}.*?<ul.*?<\/ul>/ms, y.item)
          }
          listReplacement += copy
        } else if (typeof y === 'string') {
          copy = sectionReplaceScalars(copy, y)
          listReplacement += copy
        }
      })

      templateHtml = templateHtml.replace(new RegExp('<' + X + '>(.*?)</' + X + '>', 'ms'), listReplacement)
    }
  })

  fs.writeFile(outHtml, templateHtml, err => {
    if (err) {
      console.error(err)
    }
  })
}

function loadCvYaml () {
  fs.readFile(cvDetails, 'utf8', (err, data) => {
    if (err) {
      console.error(err)
      return
    }
    cvYaml = data
    cvYaml = yaml.load(data)
    replace()
  })
}

function load () {
  fs.readFile(template, 'utf8', (err, data) => {
    if (err) {
      console.error(err)
      return
    }
    templateHtml = data
    loadCvYaml()
  })
}

load()
