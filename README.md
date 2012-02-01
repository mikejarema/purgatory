# Purgatory

Purgatory is a ruby-based command line script to mine expiring domain names based on keyword, character length, word length, extension, geography (TODO), etc.


## Details

Purgatory pulls a list of expiring domains from pool.com, and uses a simple set of rules to filter out domains.  In aggregate these filter rules are quite powerful.  For example, its quite easy to lookup all .com domains consisting of one dictionary word.  Or to find all domains containing "deal" and being less than 8 characters.  And so on.

I've used it successfully to identify some solid domain names, and registered them at cost after the daily domain drop.


## Usage

Simple command line usage as follows.

All .com domains consisting of a single dictionary word:

``purgatory.rb -x com -w 1``

All .net domains less than or equal to 5 characters in length:

``purgatory.rb -x net -l *,5``

All domains which follow a consonant-vowel-vowel-consonant-vowel pattern ending in "o":

``purgatory.rb -f cvvcv -e o``

Etc.


## Parameter Reference

Run ``purgatory.rb --help`` for all parameters.


## Notes on Word Counting

Purgatory comes bundled with the [12dicts lemmatized wordlist](http://wordlist.sourceforge.net/12dicts-readme-r5.html).  This gives a broad set of base words, pluralizations, inflections, etc.  This dictionary is used for "word counting".

The algorithm attempts to count the minimum number of words making up a string by iterating over all possible segmentations of the string (eg. "ilike" -> "i,like", "il,ike", "ili,ke", "ilik,e"), recursing where a segmentation does not consist of a dictionary word, and each stage of recursion returning the minimum word length of a particular segment.


## Roadmap

* refactor into modular codebase
* specs
* geography-based lookups (eg. find all domains with a city/state/country name)
* heuristic to reduce word counting effort when the max number of words is known (eg. don't recurse past the second word when a max 2 words are permitted based on the filters)
* word counting should return the actual segmentation yielding the min number of words


# License

The MIT License - Copyright (c) 2012 [Mike Jarema](http://mikejarema.com)
