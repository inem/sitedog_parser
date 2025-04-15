.PHONY: test

test:
	bundle exec rake test

install:
	bundle install

build:
	bundle exec rake build

release:
	bundle exec rake release

console:
	bundle exec bin/console

analyze:
	bin/analyze_dictionary test/fixtures/multiple.yaml

publish:
	bundle exec gem push `ls -t pkg/sitedog_parser-*.gem | head -1`

up:
	bundle exec rake bump:patch

up!:
	bundle exec rake bump:minor

up!!:
	bundle exec rake bump:major

