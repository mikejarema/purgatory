#!/usr/bin/ruby 

PURGATORY_VERSION = "0.1.4"

require 'rubygems'
require 'optparse'
require 'open-uri'
require 'csv'
require 'yaml'
require 'tempfile'
require 'ruby-debug'

$dictionary = {}
$lookup_cache = {}
Infinity = 1.0 / 0

def match?(row, options)
  full_domain = row[0]
  domain, ext = full_domain.split(/\./)
  date = row[1]
  type = row[2]
  match = true
  
  match = false if match && !options[:extension].empty? && !options[:extension].include?(ext)
  match = false if match && !options[:nums] && domain =~ /[0-9]/
  match = false if match && !options[:hyphens] && domain =~ /\-/
  match = false if match && options[:min_len] && domain.length < options[:min_len]
  match = false if match && options[:max_len] && domain.length > options[:max_len]
  match = false if match && options[:keyword] && !domain.include?(options[:keyword])
  match = false if match && options[:format] && domain !~ options[:format]
  match = false if match && options[:start] && domain !~ /^#{options[:start]}/
  match = false if match && options[:end] && domain !~ /#{options[:end]}$/
  match = false if match && options[:min_words] && options[:max_words] && !has_words(domain, options[:min_words], options[:max_words])
    
  match
end

def has_words(domain, min_words, max_words)
  num_words = min_num_words_from(domain.downcase, max_words)
  return num_words >= min_words && num_words <= max_words
end

def min_num_words_from(phrase, max_words = Infinity, recursion_depth = 1)
  if $dictionary.has_key?(phrase)
    return 1

  elsif $lookup_cache.has_key?(phrase)
    return $lookup_cache[phrase]
    
  elsif phrase.length <= 1
    return Infinity

  elsif recursion_depth < max_words
    num_words = Infinity
    
    (phrase.length - 2).downto(0) do |i|
      num_words_i = 
        min_num_words_from(phrase[0..i],    max_words, recursion_depth + 1) + 
        min_num_words_from(phrase[i+1..-1], max_words, recursion_depth + 1)
      num_words = num_words_i if num_words_i < num_words
    end
    
    $lookup_cache[phrase] = num_words if num_words < Infinity
    return num_words

  else
    return Infinity

  end
end

def load_dictionary(file, additional_words = nil)
  STDERR.print "Loading dictionary for word count restrictions..."
  
  # Load dictionary contents from file
  File.open(file).each do |line|
    line.gsub("->", "").gsub(/\[.*?\]/, "").split(/[ \t,]/).select{|i| i.chomp != ""}.each do |word|
      $dictionary[word.chomp] = true
    end
  end

  # Add additional words from the command line
  [additional_words].flatten.compact.each do |word|
    $dictionary[word.downcase.chomp] = true
  end
  STDERR.puts " done."
end

def main
  options = {
    :nums => true,
    :hyphens => true,
    :extension => [],
    :min_len => nil,
    :max_len => nil,
    :keyword => nil,
    :dictionary => "2+2lemma.txt",
    :min_words => nil,
    :max_words => nil,
    :refresh => should_refresh_list?,
    :date => false,
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: purgatory.rb [options]"

    # Defaults
    options[:nums] =    false
    options[:hyphens] = false
    options[:extension] = ["com"]

    # Parameter Processing
    opts.on("-x", "--ext com,net,org", Array, "Desired extensions") do |o|
      options[:extension] = o
    end
    opts.on("-n", "--[no-]nums", "Include/exclude nums") do |o|
      options[:nums] = o
    end
    opts.on("-h", "--[no-]hyphens", "Include/exclude hyphens") do |o|
      options[:hyphens] = o
    end
    opts.on("-l 2,8", Array, "Min, max length of domain, * for no upper/lower limit") do |o|
      min_len_match = /[0-9]+/.match(o[0])
      options[:min_len] = min_len_match ? min_len_match[0].to_i : 1
      max_len_match = /[0-9]+/.match(o[1])
      options[:max_len] = max_len_match ? max_len_match[0].to_i : Infinity
      options[:max_len] = options[:min_len] if o.size == 1
    end
    opts.on("-i", "--include keyword", "Ensure keyword appears in domain") do |o|
      options[:keyword] = o
    end
    opts.on("-s", "--start keyword", "Starts with keyword") do |o|
      options[:start] = o
    end
    opts.on("-e", "--end keyword", "Ends with keyword") do |o|
      options[:end] = o
    end
    opts.on("-f lncv-", "Specify a format with [l]etter, [n]umbers, [c]onsonants, [v]owels, and hyphens") do |o|
      options[:format] = /^#{o.gsub(/l/, "[a-z]").gsub(/n/, "[0-9]").gsub(/v/, "[aeiou]").gsub(/c/, "[bcdfghjklmnpqrstvwxyz]")}$/i
    end
    opts.on("-d", "--dictionary", "Dictionary for word matching") do |o|
      options[:dictionary] = o
    end
    opts.on("-w 1,3", Array, "Min, max number of dictionary words in domain, * for no upper/lower limit") do |o|
      min_len_match = /[0-9]+/.match(o[0])
      options[:min_words] = min_len_match ? min_len_match[0].to_i : 1
      max_len_match = /[0-9]+/.match(o[1])
      options[:max_words] = max_len_match ? max_len_match[0].to_i : Infinity
      options[:max_words] = options[:min_words] if o.size == 1
    end
    opts.on("--[no-]fetch", "Forces the script to refresh the working list of expiring domains") do |o|
      options[:refresh] = o
    end
    opts.on("-v", "--version", "Shows version number") do |o|
      STDERR.puts "Purgatory v#{PURGATORY_VERSION} - Copyright (c) 2012 Mike Jarema"
      exit
    end
    opts.on("--[no-]date", "Shows the drop date of matching domains") do |o|
      options[:date] = o
    end
    opts.on("--add-words example,words", Array, "Treats the supplied words as dictionary words for the purposes of the current lookup") do |o|
      options[:additional_words] = o
    end
  end.parse!

  refresh_list if options[:refresh]
    
  if options[:min_words] && options[:max_words]
    load_dictionary(options[:dictionary], options[:additional_words])
  end
  
  dir = File.dirname(__FILE__)
  Dir.open(dir).each do |file|
    if file =~ /pool.*\.txt/i
      CSV.foreach("#{dir}/#{file}") do |row|
        puts row[0] + (options[:date] ? "\t(#{row[1]})" : "") if match?(row, options)
      end
    end
  end
end

def refresh_list
  # Assumes expiring domain list is found in PoolDeletingDomainsList.txt
  STDERR.print "Downloading expiring domain list from pool.com..."
  temp_zip = Time.now.to_i.to_s + "_" + rand(Time.now.to_i).to_s + ".zip"
  `curl "http://www.pool.com/Downloads/PoolDeletingDomainsList.zip" > #{temp_zip} 2> /dev/null`
  `unzip -o #{temp_zip}`
  `rm #{temp_zip}`
  `touch PoolDeletingDomainsList.txt`
  STDERR.puts " done."
end

def should_refresh_list?
  !File.exist?("PoolDeletingDomainsList.txt") ||
  File.mtime("PoolDeletingDomainsList.txt") < Time.now - 3600 # older than 1 hour
end

main

