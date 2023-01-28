.PHONY: all

all: push

SHELL := /bin/bash
CWD := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
version := $(shell grep 'version=.*' version | awk -F'=' '{print $$2}')
next := $(shell echo ${version} | awk -F. '/[0-9]+\./{$$NF++;print}' OFS=.)
	
php:
	export cv_file="$(CWD)/input/cv.yaml" && \
	export template_file="$(CWD)/input/template.html" && \
	export output_file="$(CWD)/$@.html" && \
	php "$(CWD)/src/$@/cv.php" 

python:
	export cv_file="$(CWD)/input/cv.yaml" && \
	export template_file="$(CWD)/input/template.html" && \
	export output_file="$(CWD)/$@.html" && \
	python3 $(CWD)/src/$@/cv.py

lint:
	npx standard --fix $(CWD)/input/javascript/*

bump: lint
	sed "s/$(version)/$(next)/" -i version

version: bump
	git add -A
	git commit -a -m "Bump to $(next)"

push: version
	git pull --rebase
	git push -u origin main:main -f
