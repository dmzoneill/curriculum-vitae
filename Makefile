.PHONY: all

all: push

SHELL := /bin/bash
CWD := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
version := $(shell grep 'version=.*' version | awk -F'=' '{print $$2}')
next := $(shell echo ${version} | awk -F. '/[0-9]+\./{$$NF++;print}' OFS=.)
jar_files := "jackson-annotations-2.14.2.jar:jackson-core-2.14.1.jar:jackson-databind-2.14.1.jar:jackson-dataformat-yaml-2.14.2.jar"
nonlint_target := $(shell echo $(MAKECMDGOALS) | awk -F'-' '{print $$1}')

export cv_file := $(CWD)/input/cv.yaml
export template_file := $(CWD)/input/template.html
export output_file := $(CWD)/out/$(MAKECMDGOALS).html

markup-lint:
	{ \
		cd css; \
		curl -o .stylelintrc.json https://raw.githubusercontent.com/dmzoneill/dmzoneill/main/.github/linters/.stylelintrc.json; \
		npm install --save-dev stylelint stylelint-config-standard; \
		npx stylelint --fix *.css; \
		rm .stylelintrc.json; \n
	}

	{ \
		cd input; \
		npm install --save-dev htmlhint; \
		npx htmlhint *.html; \
	}

	{ \
		cd input; \
		npm install --save-dev yamllint; \
		npx yamllint *.yaml; \
	}

csharp:
	{ \
		cd $(CWD)/src/$@/; \
		mdtool build cv.csproj; \
		mono --debug ./bin/Debug/cv.exe; \
	}

go-lint:
	{ \
		cd $(CWD)/src/${nonlint_target}/; \
		golangci-lint run --fix cv.go; \
	}

go:
	{ \
		go env -w GOBIN=$(CWD)/src/$@; \
		cd $(CWD)/src/$@; \
		go mod init main; \
		go get gopkg.in/yaml.v2; \
		go get github.com/gookit/goutil/dump; \
		go run cv.go; \
	}

cpp-lint:
	{ \
		cd $(CWD)/src/${nonlint_target}/; \
		clang-format -i cv.cpp;\ 
	}

cpp:
	{ \
		sudo apt install libyaml-cpp*; \
		cd $(CWD)/src/$@/; \
		g++ -g -w -O3 -std=c++17 cv.cpp -lboost_regex -lyaml-cpp -o main; \
		./main; \
	}

java:	
	{ \
		cd $(CWD)/src/$@/; \
	 	javac -cp ${jar_files} -s . cv.java YamlMap.java; \
		java -cp ".:${jar_files}" cv; \
	}

perl:	
	{ \
		cd $(CWD)/src/$@/; \
		perl cv.pl; \
	}

javascript-lint:
	{ \
		cd $(CWD)/src/${nonlint_target}/; \
		npm install standard --save-dev
		npx standard --fix; \
	}
	

javascript:
	{ \
		cd $(CWD)/src/$@/; \
		node cv.js; \
	}

ruby-lint:
	{ \
		cd $(CWD)/src/${nonlint_target}/; \
		ruby cv.rb; \
	}

ruby:
	{ \
		cd $(CWD)/src/$@/; \
		rubocop cv.rb -A; \
	}

php-lint:
	{
		cd $(CWD)/src/${nonlint_target}/; \	
		curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar; \	
		curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar; \	
		- php phpcs.phar cv.php; \	
		- php phpcbf.phar cv.php; \	
	}


php:
	{ \
		cd $(CWD)/src/$@/; \
		php cv.php; \
	}	

python-lint:
	{ \
		cd $(CWD)/src/${nonlint_target}/; \
		black cv.py; \
	} 

python:
	{ \
		cd $(CWD)/src/$@/; \
		python3 cv.py; \
	}		

bump:
	sed "s/$(version)/$(next)/" -i version

version: bump
	git add -A
	git commit -a -m "Bump to $(next)"

push: version
	git pull --rebase
	git push -u origin main:main -f
