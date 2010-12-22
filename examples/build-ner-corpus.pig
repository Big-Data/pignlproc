-- Query incoming link popularity - local mode

-- Register the project jar to use the custom loaders and UDFs
REGISTER $PIGNLPROC_JAR

-- Parse the wikipedia dump and extract text and links data
parsed =
  LOAD '$WIKIPEDIA'
  USING pignlproc.storage.ParsingWikipediaLoader('en')
  AS (title, wikiuri, text, redirect, links, headers, paragraphs);

-- Load wikipedia, instance types and redirects from dbpedia dumps
wikipedia_links =
  LOAD '$DBPEDIA/wikipedia_links_en.nt'
  USING pignlproc.storage.UriUriNTriplesLoader(
    'http://xmlns.com/foaf/0.1/primaryTopic')
  AS (wikiuri: chararray, dburi: chararray);

instance_types =
  LOAD '$DBPEDIA/instance_types_en.nt'
  USING pignlproc.storage.UriUriNTriplesLoader(
    'http://www.w3.org/1999/02/22-rdf-syntax-ns#type')
  AS (dburi: chararray, type: chararray);

instance_types_no_thing =
  FILTER instance_types BY type NEQ 'http://www.w3.org/2002/07/owl#Thing';

redirects =
  LOAD '$DBPEDIA/redirects_en.nt'
  USING pignlproc.storage.UriUriNTriplesLoader(
    'http://dbpedia.org/property/redirect')
  AS (redirected_from: chararray, redirerected_to: chararray);

-- Extract the sentence contexts of the links respecting the paragraph
-- boundaries
sentences =
  FOREACH parsed
  GENERATE title, flatten(pignlproc.evaluation.SentencesWithLink(
    text, links, paragraphs));

-- Perform successive joins to find the type of the linkTarget
joined1 = JOIN wikipedia_links BY wikiuri, sentences BY linkTarget;
joined2 = JOIN instance_types_no_thing BY dburi, joined1 BY dburi;
-- TODO: handle the redirects properly with a left outer join and a conditional
-- expression

distincted = DISTINCT joined2;

result = FOREACH distincted GENERATE type, linkTarget, title, sentenceOrder,
  linkBegin, linkEnd, sentence;

ordered = ORDER result BY type ASC, title ASC, sentenceOrder ASC;

STORE ordered INTO '$OUTPUT' USING PigStorage();
