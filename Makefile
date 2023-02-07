.PHONY: all

all: push

SHELL := /bin/bash
CWD := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
version := $(shell grep 'version=.*' version | awk -F'=' '{print $$2}')
next := $(shell echo ${version} | awk -F. '/[0-9]+\./{$$NF++;print}' OFS=.)
jar_files := "jackson-annotations-2.14.2.jar:jackson-core-2.14.1.jar:jackson-databind-2.14.1.jar:jackson-dataformat-yaml-2.14.2.jar"

export cv_file := $(CWD)/input/cv.yaml
export template_file := $(CWD)/input/template.html
export output_file := $(CWD)/out/$(MAKECMDGOALS).html

go:
	{ \
		go env -w GOBIN=$(CWD)/src/$@; \
		cd $(CWD)/src/$@; \
		go mod init main; \
		go get gopkg.in/yaml.v2; \
		go get github.com/gookit/goutil/dump; \
		go run cv.go; \
	}

cpp:
	{ \
		sudo apt install libyaml-cpp*; \
		cd $(CWD)/src/$@/; \
		g++ -g -w -O3 -std=c++17 cv.cpp -lboost_regex -lyaml-cpp -o main; \
		./main
	}

java:	
	{ \
		cd $(CWD)/src/$@/; \
	 	javac -cp ${jar_files} -s . cv.java YamlMap.java; \
		java -cp ".:${jar_files}" cv; \
	}

perl:
	perl "$(CWD)/src/$@/cv.pl" 

javascript:
	node "$(CWD)/src/$@/cv.js" 

ruby:
	ruby "$(CWD)/src/$@/cv.rb" 

php:
	php "$(CWD)/src/$@/cv.php" 

python:
	python3 "$(CWD)/src/$@/cv.py"

bump:
	sed "s/$(version)/$(next)/" -i version

version: bump
	git add -A
	git commit -a -m "Bump to $(next)"

push: version
	git pull --rebase
	git push -u origin main:main -f

lint: version
	curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar
	curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar
	npm install --save-dev stylelint stylelint-config-standard
	curl -o .stylelintrc.json https://raw.githubusercontent.com/dmzoneill/dmzoneill/main/.github/linters/.stylelintrc.json
	npx standard --fix
	rubocop src/ruby/cv.rb -A
	black src/python/cv.py
	npx stylelint --fix "**/*.css"
	npx htmlhint "**/*.html"
	golangci-lint run --fix src/go/cv.go
	rm .stylelintrc.json
	- php phpcs.phar src/php/cv.php
	- php phpcbf.phar src/php/cv.php
