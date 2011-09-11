COFFEE=coffee
NPM=npm

BUILT_JS=lib/absvalue.js lib/ctags.js lib/dom.js lib/infer.js
OPTIMIST=node_modules/optimist/index.js

all:	bin/jsctagsmm

bin/jsctagsmm:	bin/jsctagsmm.coffee lib/parse-js.js $(BUILT_JS) $(OPTIMIST)
	echo "#!/usr/local/bin/node" > $@ && $(COFFEE) -p $< >> $@ && \
		chmod a+x $@ || rm $@

%.js:	%.coffee
	$(COFFEE) -p $< > $@ || rm $@

$(OPTIMIST):
	$(NPM) install optimist

.PHONY:	clean distclean

clean:
	rm -f bin/jsctagsmm $(BUILT_JS)

distclean:
	rm -rf bin/jsctagsmm $(BUILT_JS) node_modules

