.PHONY: all

all: push

SHELL := /bin/bash
CWD := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
version := $(shell grep 'version=.*' version | awk -F'=' '{print $$2}')
next := $(shell echo ${version} | awk -F. '/[0-9]+\./{$$NF++;print}' OFS=.)
jar_files := "jackson-annotations-2.14.2.jar:jackson-core-2.14.1.jar:jackson-databind-2.14.1.jar:jackson-dataformat-yaml-2.14.2.jar"

java:	
	export cv_file="$(CWD)/input/cv.yaml" && \
	export template_file="$(CWD)/input/template.html" && \
	export output_file="$(CWD)/out/$@.html" && \
	cd $(CWD)/src/$@/ && javac -cp ${jar_files} -s . cv.java YamlMap.java && cd - && \
	cd $(CWD)/src/$@/ && java -cp ".:${jar_files}" cv && cd -

ruby:
	export cv_file="$(CWD)/input/cv.yaml" && \
	export template_file="$(CWD)/input/template.html" && \
	export output_file="$(CWD)/out/$@.html" && \
	ruby "$(CWD)/src/$@/cv.rb" 

perl:
	export cv_file="$(CWD)/input/cv.yaml" && \
	export template_file="$(CWD)/input/template.html" && \
	export output_file="$(CWD)/out/$@.html" && \
	perl "$(CWD)/src/$@/cv.pl" 

php:
	export cv_file="$(CWD)/input/cv.yaml" && \
	export template_file="$(CWD)/input/template.html" && \
	export output_file="$(CWD)/out/$@.html" && \
	php "$(CWD)/src/$@/cv.php" 

python:
	export cv_file="$(CWD)/input/cv.yaml" && \
	export template_file="$(CWD)/input/template.html" && \
	export output_file="$(CWD)/out/$@.html" && \
	python3 $(CWD)/src/$@/cv.py

bump:
	sed "s/$(version)/$(next)/" -i version

version: bump
	git add -A
	git commit -a -m "Bump to $(next)"

push: version
	git pull --rebase
	git push -u origin main:main -f

lint: version
	npm install --save-dev stylelint stylelint-config-standard
	echo "{\"extends\": \"stylelint-config-standard\"}" > .stylelintrc.json
	npx standard --fix
	rubocop src/ruby/cv.rb -A
	black src/python/cv.py
	npx stylelint --fix "**/*.css"
	rm .stylelintrc.json
