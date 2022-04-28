TMP=tmp
CONFIG_DIR=config
MAPPINGS_DIR=mappings
BOOMER_INPUT=boomer_input
BOOMER_OUTPUT=boomer_output
#####################
## Mappings #########
#####################
dirs: $(TMP) $(MAPPINGS_DIR) $(BOOMER_INPUT) $(BOOMER_OUTPUT)
	mkdir -p $@ 

ALL_MAPPINGS=$(MAPPINGS_DIR)/mondo_exactmatch_icd10cm.sssom.tsv $(MAPPINGS_DIR)/mondo_exactmatch_omim.sssom.tsv $(MAPPINGS_DIR)/mondo_exactmatch_orphanet.sssom.tsv # $(MAPPINGS_DIR)/mondo.sssom.tsv 

$(MAPPINGS_DIR)/mondo_exactmatch_icd10cm.sssom.tsv: | $(MAPPINGS_DIR)/
	wget https://raw.githubusercontent.com/monarch-initiative/mondo/master/src/ontology/mappings/mondo_exactmatch_icd10cm.sssom.tsv -O $@

$(MAPPINGS_DIR)/mondo_exactmatch_omim.sssom.tsv: | $(MAPPINGS_DIR)/
	wget https://raw.githubusercontent.com/monarch-initiative/mondo/master/src/ontology/mappings/mondo_exactmatch_omim.sssom.tsv -O $@

$(MAPPINGS_DIR)/mondo_exactmatch_orphanet.sssom.tsv: | $(MAPPINGS_DIR)/
	wget https://raw.githubusercontent.com/monarch-initiative/mondo/master/src/ontology/mappings/mondo_exactmatch_orphanet.sssom.tsv -O $@

# $(MAPPINGS_DIR)/mondo.sssom.tsv: | $(MAPPINGS_DIR)/
# 	wget https://raw.githubusercontent.com/monarch-initiative/mondo/master/src/ontology/mappings/mondo.sssom.tsv -O $@

mappings: $(ALL_MAPPINGS)

ONTOLOGIES = mondo-ingest ordo omim icd10cm
GET_ONTS=$(patsubst %, $(TMP)/%.owl, $(ONTOLOGIES))

$(TMP)/%.owl:
	wget https://github.com/monarch-initiative/mondo-ingest/releases/download/v2022-04-26/$*.owl -O $@

$(TMP)/combo.owl: $(GET_ONTS)
	robot merge $(addprefix -i , $^) --output $@

all: dirs $(TMP)/combo.owl gen-boomer-input $(BOOMER_INPUT)/combined.ptable.tsv boomer pngs

# $(BOOMER_INPUT)/combo.sssom.tsv: $(ALL_MAPPINGS)
# 	sssom merge $^ --reconcile False -o $@

$(BOOMER_INPUT)/combined.ptable.tsv: $(BOOMER_INPUT)/combined.sssom.tsv
	sssom ptable $< -o $@

gen-boomer-input:
	python -m scripts.gen_boomer_input run -c registry.yaml -s $(MAPPINGS_DIR) -t $(BOOMER_INPUT)

boomer:
	boomer --ptable $(BOOMER_INPUT)/combined.ptable.tsv\
		   --ontology $(TMP)/combo.owl \
		   --prefixes $(BOOMER_INPUT)/prefix.yaml \
		   --output boomer_output \
		   --window-count 1000 \
		   --runs 1
		#    $(addprefix --restrict-output-to-prefixes=, $(ONTOLOGY_PREFIXES))

	find boomer_output -name "*.json" -type 'f' -size -500c -delete

.PHONY: sssom
sssom:
	python3 -m pip install --upgrade pip setuptools && python3 -m pip install --upgrade --force-reinstall git+https://github.com/mapping-commons/sssom-py.git@parse-subclassOf

EXCLUDE_JSON= singletons.json
JSONS=$(wildcard boomer_output/*.json)
PNGS=$(patsubst %.json, %.png, $(JSONS))

%.dot: %.json
	og2dot.js -s $(CONFIG_DIR)/boomer-style.json $< >$@ 
%.png: %.dot
	dot $< -Tpng -Grankdir=BT >$@

pngs: $(PNGS)