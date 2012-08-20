# Debugging Data

Your software consistently provides impressive music recommendations
by combining cultural and audio data. Customers are happy.
However, things aren't always perfect. Sometimes that Beyoncé track is
attributed to Beyonce. The artist for the Béla Fleck solo album shows up as
Béla Fleck and the Flecktones. Worse, the ボリス biography
has the artist name listed as ???. Where did things go wrong?
Did one of your customers provide you with data in an incorrect
character encoding? Did one of the web-crawlers have a bug? Perhaps
the name resolution code was incorrectly combining a solo artist
with his band?

One of the most important tricks for dealing with
multi-provenance data is traceability and debuggability.
In this chapter, we'll explore ways of keeping track of
the source of our data, techniques for backing out
bad data, and the business value of adopting such
ability.

## Why?

The ability to trace a datum back to its origin is important
for several reasons. It helps us to back-out or reprocess bad data,
and conversely, it allows us to reward and boost good data
sources and processing techniques. Furthermore, local privacy
laws can mandate things like auditability, data transfer
restrictions and more (TODO: citation).

////
qem 2012/07/04: also helps when local custom or even law requires
 you be able to track sources, such as California's "Shine The Light"
 law on data privacy.  I plan to mention this elsewhere in the book
 but it's also helpful/relevant here.
   http://www.leginfo.ca.gov/cgi-bin/displaycode?section=civ&group=01001-02000&file=1798.80-1798.84
   (Civil Code section 1798.83)]
////

We'll also see later how data traceability can provide further
business value by allowing us to provide stronger measurements
on the "worth" of a particular source, realize where to
focus our development effort, and even manage blame.

## Software Analogy

In order to develop a repertoire for debugging data, we'll lean
heavily on debugging techniques borrowed from software development.
In particular, we'll take advantage of data immutability, a
technique popular in functional programming, that allows us to
model change, while still preserving a view toward the past.

## A Brief Functional Programming Tangent

In popular imperative languages, data tends to be mutable.
For example, if I want to sort a list, I might call
`myList.sort()`. This will sort the in-place. Consequently, all
references to `myList` will be changed. If we want to get a view
back to `myList` before it was sorted, we'd have to explicitly
make a copy. Functional languages, on the other hand, tend to treat
data as immutable. Our list sorting example becomes something closer
to `myNewSortedList = sort(myList)`. This retains the unsorted
list `myList`. One of the advantages of this is that many functions
become simply the result of processing the values passed in. This means
given a stack trace, we can often reproduce bugs immediately. With mutable
data, there is no guarantee that the value of a particular variable
remains the same throughout the execution of the function. Because of this,
we can't necessarily rely on a stack trace to reproduce bugs. You'll see
that one of the ways we take advantage of immutability is by persisting
our data not only under it's normal identifier, but with a compound
identifier + timestamp. This will help aid us find the exact inputs to
any of our data processing steps, should we need to go back and debug
them.

## Personal Experience

I previously worked as the data ingestion team lead at
a music data company. We provided artist and song recommendations,
artist biographies, news, and detailed audio analysis of digital
music. The data is exposed via a web service, along with
data dumps. Many of the data feeds are composed of many sources
of data which are cleaned, transformed, and put through
machine learning algorithms. One of the first issues we ran
into was learning how to trace a particular result back to its
constituent parts. If a particular artist recommendation
was poor, was it because of our machine learning algorithm?
Did we simply not have enough data for that artist? Was there
some obviously wrong data from one of our sources?
Being able to debug our product became a business necessity.

We developed several mechanisms for being able to debug our data woes.
I'll explore several specific examples here.

1. Snapshotting

Many of the data sources were updated frequently. Web pages,
for example, which were crawled for news, reviews, biography
information and similarity, are updated inconsistently,
and without notice. This means that even if we are able to trace
a particular datum back to a source, the source may be
drastically different than the time that we crawled or processed
the data. This meant that we needed to not only capture the
source of our data, but the time, and exact copy of the source.
Our database columns or keys would then have an extra field for
a time-stamp. Keeping track of the time, and the original data
also allows you to track changes from that source. You get closer
to answering the question, "why were my recommendations for
The Sea and Cake great last week, but terrible today?".

2. Saving the source

Our data was stored in several different databases, including
relational and key-value. However, nearly every schema had
a source field. This field would contain one or more values.
For original sources there would be a single source listed,
but as data was processed and transformed into roll-ups or
learned-data, we would preserve the list of sources that went
into creating that new piece of data. This allowed us to take
even something like the final data product and figure out where
the constituent parts came.

3. Weighting sources.

One of the most important things we did from data we collected
was learn about new artists, albums and songs. However,
we didn't always want to create a new entity that would end up in
our final data product whenever we heard about a new name
we had never heard. For example, certain data sources were
more likely to have errors, misspellings and other inaccuracies
that we wanted to be vetted before they would reach our final
product. Furthermore, we wanted to be able to give priority
processing to certain sources that either had higher information
value or were for a particular customer. For applications
like learning about new artists, we'd assign a trust-score to each
source, that would, amongst other things, determine whether a new
artist was created that would make its way into our final product,
or would add weight to that artist being created if we ever heard
of them again. In this way, several lower-weighted sources act
additively to the artist creation application.

4. Backing out data

Sometimes our data was bad. When this happened, we'd need to do
several things. First, we'd want to take the data out of our
production data product. Next, we'd want to figure out the potential source(s)
of the offending data, and reprocess the product without that source.
Sometimes the transformations that the data would go through were complicated
enough that it was easier to simply reprocess the final data with all
permutations of sources to spot the source of the bad data.
This only possible since we had kept track of the sources that went into
the final product.

Because of this observation, we had to make it easy to redo any
stage of the data transformation with an altered source list. Many
of our data processing steps would therefore have the source list
parameterizable in a way that it was easy to exclude a particular
source, or explicitly declare the sources that were allowed to
affect this particular processing stage.

5. Separating phases (and keeping them pure)

Many times our data processing would be divided into several stages.
It's important to identify the state barriers in your application,
as this allows you to both write better code, and create more efficient
infrastructure. From a code perspective, keeping each of our stages
separate allows us to reduce side effects (I/O, etc.), which makes our
code easier to test, partly because we don't have to set up mocks for
half of our side-effecting infrastructure. From an infrastructure
perspective, keeping things separate allows us to make isolated
decisions about the compute power, parallelism, memory constraints, etc.
of a given stage of the problem.

5. Deflecting blame

As much as the engineer in you wants to be able to always take
responsibility for what you produce, sometimes it's useful to be able
to rightfully point blame at one of your data sources. For instance,
if a particular customer is having a data quality issue, it might
be helpful to know whether or not the origin of the issue was from
data they gave you, or from your processing of the data they gave you.
If it's the former, there is a real business value in being able to
go back to the customer armed with the exact source of the issue
and a proposed solution, or an already implemented solution.

6. Finding areas for improvement

Related to blame is the ability to find places in your own processing
and infrastructure that can be improved. For this reason, another
"source" for data are your own processing stages. It's useful to know,
for instance, when a certain piece of derived data was calculated. If there
is an issue with it, it allows you to focus immediately on the place
it was created. Conversely, if a particular processing stage is
tending to produce excellent results, it is helpful to be able to
find out why it is doing so well, and ideally replicate this into
more parts of your system. Organizationally, this type of knowledge
also allows you to help figure out where to focus more of your teams
effort, and even reorganize your team structure. For example, you might
want to place a new member of the team on one of the infrastructure pieces that
is doing well, and should be a model for other pieces first, as to give them
a good starting place for learning the system. A more senior team member
may be more effective on pieces of the infrastructure that are struggling.

## An Example

Here we'll go on a guided example. Let's imagine we're building
a news aggregation site. The homepage will display the top
stories of the day, with the ability to drill down by topic.
Each story will also have a link to display coverage of the same
event from other sources.

We'll need to be able to do several things:

1. Crawl the web for news stories
1. Determine story popularity/timeliness via shares on social media,
and perhaps source (we assume a story on the New York Times homepage
is important/popular).
1. Cluster stories about the same event together.
1. Determine event popularity (maybe this will be aggregate popularity
of the individual stories?).

### Crawlers

We'll seed our crawlers with a number of known news sites. Every so
often (perhaps 10 times a day for heavily updated pages, and once a
day for lesser updated pages) we'll download the contents of the page
and store it under a composite key with URL, source and timestamp,
or a relational database row with those atributes.

From each of these home pages we crawl, we'll download the individual
linked stories. The stories will also be saved with URL, source
and timestamp attributes. Additionally, we'll store the composite
ID of the homepage where we were linked to this story. That way,
if, for example, later we suspect we have a bug with the way
we assign story popularity based on home page placement, we can
go look at the home page as it was retrieved at a particular point
in time. Ideally we should be able to trace data from our
own homepage all the way back to the original HTML that
our first crawler downloaded.

In order to help determine popularity, and to further feed
our news crawlers, we'll also be crawling social media
sites. Just like with the news crawlers, we'll want
to keep a timestamped record of the HTML and other assets
we crawl. Again, this will let us go back later and debug
our code, if for example we suspect we are incorrectly
counting links from shares of a particular article
(was our regular expression mistaken, or was there a bug
in our shortened-url -> full-url code?)

## Change

Keeping previous versions of the sites we crawl allows for some
interesting analytics in the future. How many articles does the
Boston Globe usually link to on their home page? Is there a bigger
variety of news articles in the summer? We can start running
new analytics without having to only use data since we turned
the analytics on. We have a clear view of the past.

