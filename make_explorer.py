#!/usr/bin/env python
import numpy
import os
import math
import string
import json
import pandas
import scipy
import scipy.spatial
import tqdm
import networkx
import random
import sklearn.linear_model
import psycopg2
import configparser
import sqlalchemy
import umap
import seaborn

import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--database-config",
                    help="Config file with details of the database connection to use",
                    default="db.conf")
parser.add_argument("--output",
                    required=True,
                    help="The directory to put it into")

parser.add_argument("--progress",
                    action="store_true",
                    help="Show a progress bar")
args = parser.parse_args()

config = configparser.ConfigParser()
config.read(args.database_config)
dbname = config['database']['dbname']
user = config['database']['user']
password = config['database']['password']
host = config['database']['host']
port = config['database']['port']
conn = psycopg2.connect(f'dbname={dbname} user={user} password={password} host={host} port={port}')
read_cursor = conn.cursor()
stats_cursor = conn.cursor()
engine = sqlalchemy.create_engine(
    f"postgresql+psycopg2://{user}:{password}@{host}:5432/{dbname}")

language_names = pandas.read_sql("select * from wikidata_iso639_codes", engine)
language_name_lookup = language_names.set_index('iso_639_3_code').language_name.to_dict()
language_orthography = pandas.read_sql("select * from language_orthography", engine)
orthography_lookup = language_orthography.set_index('iso_639_3_code').best_tokenisation_method.to_dict()

def neighbours(language1, recursion=1, nearby_count=5, except_for=[]):
    #extra_constraint = (~distances.language2.isin(except_for))
    extra_constraint = ~distances.language2.isin([])
    one_step = distances[(distances.language1 == language1) &
                          extra_constraint &
                         (distances.language2 != language1)
                        ].nlargest(nearby_count, CORR_TO_USE).language2
    answer = [(language1, x, look_up_corr_score[(language1, x)]) for x in one_step]
    if recursion == 1:
        return answer
    known_so_far = set(one_step)
    known_so_far.update([language1])
    for n in one_step:
        answer += neighbours(n, recursion-1, nearby_count//2 if nearby_count > 3 else 2, except_for=known_so_far)
    return answer

import jinja2
html_page = jinja2.Template("""<!DOCTYPE html>
<html>
  <head>
    <title>{{official_name}}</title>
    <script type="text/javascript" src="https://d3js.org/d3.v4.min.js"></script>
    <script type="text/javascript">var JSON_FILE="{{json_file}}";</script>
    <link type="text/css" rel="stylesheet" href="force.css"/>
  </head>
  <body>
    <svg width="960" height="600"
    xmlns="http://www.w3.org/2000/svg"
    xmlns:xlink="http://www.w3.org/1999/xlink"></svg>
    <script type="text/javascript" src="force.js"></script>
  </body>
</html>
""")

os.makedirs(os.path.join(args.output, "dynamic_files"),
            exist_ok=True)

def array2color(arr):
    r = int(255 * arr[0])
    g = int(255 * arr[1])
    b = int(255 * arr[2])
    return "#%02x%02x%02x" % (r,g,b)

iterator = distances.language1.unique()

if args.progress:
    iterator = tqdm.tqdm(iterator)

for language in iterator:
    iterator.set_description(language)
    z = networkx.Graph()
    for (l1, l2, weight) in neighbours(language, recursion=3, nearby_count=8):
        z.add_edge(l1, l2, weight=10 ** weight, title=f"Highest correlation seen between {l1} and {l2} is {weight}")
        nodelist = z.nodes()
    nodesizes = [1000 if n == language else 200 for n in nodelist]
    centrality = pandas.Series(networkx.eigenvector_centrality(z, max_iter=5000))
    how_central = (centrality / centrality.max()).to_dict()
    nodecolors = numpy.array([(1.0,0.6,0.1) if n == language 
                              else 
                              (0.4, how_central[n], 0.8)
                               for n in nodelist])
    node_size_lookup = {n: s for (n,s) in zip(nodelist, nodesizes)}
    node_colour_lookup = {n: array2color(c) for (n,c) in zip(nodelist, nodecolors)}
    for n in z:
        z.nodes[n]["name"] = language_name_lookup.get(n,n)
        z.nodes[n]["color"] = node_colour_lookup[n]
        z.nodes[n]["size"] = node_size_lookup[n]
    with open(os.path.join(args.output, f"dynamic_files/{language}.json"), 'w') as f:
        json.dump(networkx.readwrite.json_graph.node_link_data(z), f, indent=4, sort_keys=True)


for language in distances.language1.unique():
    with open(os.path.join(args.output, f"dynamic_files/{language}.html"), 'w') as f:
        f.write(html_page.render({ "official_name": language,
                     "json_file": f'{language}.json'}))


index_template = jinja2.Template("""<!doctype html>
<html lang="en">
<HEAD>
<TITLE>Language Explorer</TITLE>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.1/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-F3w7mX95PdgyTmZZMECAngseQB83DfGTowi0iMjiWaeVhAn4FJkqJByhZMI3AhiU" crossorigin="anonymous">
<meta name="viewport" content="width=device-width, initial-scale=1">
</HEAD>
<BODY>
<div class="container">
    <header class="d-flex flex-wrap justify-content-center py-3 mb-4 border-bottom">
      <a href="/" class="d-flex align-items-center mb-3 mb-md-0 me-md-auto text-dark text-decoration-none">
        <svg class="bi me-2" width="40" height="32"><use xlink:href="#bootstrap"></use></svg>
        <span class="fs-4">LEAFTOP Language Explorer</span>
      </a>
    </header>
  </div>
<main class="bd-content order-1 py-5" id="content">
<h1 class="bd-title mt-0">What is this?</h1>
<p>
You are looking at the first draft of an idea Greg Baker had as he was creating the LEAFTOP dataset.
The LEAFTOP data set is an automatically extracted set of around 300 nouns that can be derived from bible
translations automatically. (The real number is actually higher than this, but this is all that Greg's code
can do at the moment.) For each extracted noun, it is possible to calculate a confidence score -- how
much more likely this word is to be a good translation than the next nearest possibility.
</p>
<p>
Taking that a bit further, we can then do a Spearman correlation on the confidence scores between two 
languages. Very similar languages will pose similar problems for translators (or be similarly easy on 
some words and concepts) so languages that are similar should have high Spearman correlation scores.
Languages that are highly dissimilar should have low Spearman correlation scores.
</p>
<p>
Since it is really boring just looking at correlation scores, Greg decided to make an interactive
explorer. Each language is connected to the 8 languages with which it has the highest correlation.
Those 8 are then connected to the 4 that they are most correlated with, and then each of those gets 2.
But since these aren't exclusive, a tight bundle of languages can occur with not many languages.
</p>
<h2>What can I do with it?</h2>
<p>
You can waste time while you are supposed to working on your linguistics PhD. You can try to
disprove the nostratic hypothesis by finding links between Quechuan and Russian. You can see if this
data matches up with your latest theory about connections between African languages. You can suggest
feature improvements to Greg (gregory.baker2 is the username, and the domain is <tt>hdr.mq.edu.au</tt>).
You can cite this as part of your research so that we can make this explorer respectable enough to become
something you give to your undergraduate students.
</p>
<h2>But this is obviously wrong! Everyone knows that language X and language Y aren't related</h2>
<p>
No doubt this will happen, particularly where language X is in a country that was first evangelised
by speakers of language Y because a data set of nouns from the bible is going to have a lot of loan
words from language Y for precisely the specific vocabulary that is in the bible that wasn't previously
in language X. This will skew X and Y together very strongly.
</p>
<p>
But the fun thing to observe is how often it is <i>right</i> even though this
program has not been trained on any data other than bible translations. There's no model here that
was given a family tree of Indo-European languages: it has just figured these relationships out itself.
</p>

<h2>I'm convinced. I want to play with it now</h2>
<p>
Pick a language from this list below. On the following page you can drag languages around or click on them.
Have fun!
</p>

<UL>
{% for language in languages %}
<LI> <a href="{{language.link}}">{{language.official_name}}</a> </LI>
{% endfor %}
</UL>
</main>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.1/dist/js/bootstrap.bundle.min.js" integrity="sha384-/bQdsTh/da6pkI1MST/rWKFNjaCP5gBSY4sEBT38Q/9RBh9AH40zEOg7Hlq2THRZ" crossorigin="anonymous"></script>

</BODY>
</HEAD>
</HTML>""")



language_list = pandas.DataFrame({'iso_code': s})

with open(os.path.join(args.output, "dynamic_files/index.html"), "w") as f:
    f.write(index_template.render({"languages": [ {'link': s + ".html", "official_name": language_name_lookup.get(s,s)} for 
                                s in distances.language1.unique()]
                      }))
