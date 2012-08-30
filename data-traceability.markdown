# Data Traceability

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

How do we solve this problem?
We'd like to be able to trace data back to it's origin, following
each transformation. This is reified as data provenenace.
In this chapter, we'll explore ways of keeping track of
the source of our data, techniques for backing out
bad data, and the business value of adopting such
ability.

## Why?

The ability to trace a datum back to its origin is important
for several reasons. It helps us to back-out or reprocess bad data,
and conversely, it allows us to reward and boost good data
sources and processing techniques. Furthermore, local privacy
laws can mandate things like audit-ability, data transfer
restrictions and more. For example, California's Shine the Light
Law requires businesses disclose the personal information that has
been shared with third-parties, should a resident request. Europe's
Data Protection Directive provides even more stringent regulation
to businesses collecting data about residents.

We'll also later see how data traceability can provide further
business value by allowing us to provide stronger measurements
on the worth of a particular source, realize where to
focus our development effort, and even manage blame.

## Personal Experience

I previously worked in the data ingestion team at
a music data company. We provided artist and song recommendations,
artist biographies, news, and detailed audio analysis of digital
music. The data was exposed via a web service, along with
data dumps. Many of the data feeds were composed of many sources
of data which were cleaned, transformed, and put through
machine learning algorithms. One of the first issues we ran
into was learning how to trace a particular result back to its
constituent parts. If a particular artist recommendation
was poor, was it because of our machine learning algorithm?
Did we simply not have enough data for that artist? Was there
some obviously wrong data from one of our sources?
Being able to debug our product became a business necessity.

We developed several mechanisms for being able to debug our data woes.
I'll explore several specific examples here.

### 1. Snapshotting

Many of the data sources were updated frequently. Web pages,
for example, which were crawled for news, reviews, biography
information and similarity, are updated inconsistently,
and without notice. This means that even if we were able to trace
a particular datum back to a source, the source may have been
drastically different than the time that we crawled or processed
the data. This meant that we needed to not only capture the
source of our data, but the time, and exact copy of the source.
Our database columns or keys would then have an extra field for
a time-stamp. Keeping track of the time, and the original data
also allows you to track changes from that source. You get closer
to answering the question, "why were my recommendations for
The Sea and Cake great last week, but terrible today?".
This process of writing data once and never changing it is called
immutability.

### 2. Saving the source

Our data was stored in several different types of databases, including
relational and key-value. However, nearly every schema had
a source field. This field would contain one or more values.
For original sources there would be a single source listed,
but as data was processed and transformed into roll-ups or
learned-data, we would preserve the list of sources that went
into creating that new piece of data. This allowed us to take
even something like the final data product and figure out where
the constituent parts came from.

### 3. Weighting sources.

One of the most important things we did from data we collected
was learn about new artists, albums and songs. However,
we didn't always want to create a new entity that would end up in
our final data product. Certain data sources were
more likely to have errors, misspellings and other inaccuracies.
We wanted them to be vetted before they would progress through our system.
Furthermore, we wanted to be able to give priority
processing to certain sources that either had higher information
value or were for a particular customer. For applications
like learning about new artists, we'd assign a trust-score to each
source, that would, amongst other things, determine whether a new
artist was created,
or would add weight to that artist being created if we ever heard
of them again. In this way, several lower-weighted sources could act
additively to the artist creation application.

### 4. Backing out data

Sometimes our data was bad. When this happened, we'd need to do
several things. First, we'd want to take the data out of our
production data product. Next, we'd want to figure out the potential sources
of the offending data, and reprocess the product without that source.
Sometimes the transformations that the data would go through were complicated
enough that it was easier to simply reprocess the final data with all
permutations of sources to spot the source of the bad data.
This is only possible since we had kept track of the sources that went into
the final product.

Because of this observation, we had to make it easy to redo any
stage of the data transformation with an altered source list. Many
of our data processing steps would therefore have the source list
parameterizable in a way that it was easy to exclude a particular
source, or explicitly declare the sources that were allowed to
affect this particular processing stage.

### 5. Separating phases (and keeping them pure)

Many times our data processing would be divided into several stages.
It's important to identify the state barriers in your application,
as this allowed us to both write better code, and create more efficient
infrastructure. From a code perspective, keeping each of our stages
separate allowed us to reduce side effects (I/O, etc.), which made our
code easier to test, partly because we didn't have to set up mocks for
half of our side-effecting infrastructure. From an infrastructure
perspective, keeping things separate allowed us to make isolated
decisions about the compute power, parallelism, memory constraints, etc.
of a given stage of the problem.

### 6. Identifying the root cause

Identifying the root cause of data issues is important to being able
to fix them, and control customer relationships. For instance,
if a particular customer is having a data quality issue, it
is helpful to know whether the origin of the issue was from
data they gave you, or from your processing of the data they gave you.
If it's the former, there is a real business value in being able to
go back to the customer armed with the exact source of the issue
and a proposed solution, or an already implemented solution.

### 7. Finding areas for improvement

Related to blame is the ability to find places in your own processing
and infrastructure that can be improved. For this reason, another
source for data are your own processing stages. It's useful to know,
for instance, when a certain piece of derived data was calculated. If there
is an issue with it, it allows you to focus immediately on the place
it was created. Conversely, if a particular processing stage is
tending to produce excellent results, it is helpful to be able to
find out why it is doing so well, and ideally replicate this into
other parts of your system. Organizationally, this type of knowledge
also allows you to help figure out where to focus more of your teams'
effort, and even reorganize your team structure. For example, you might
want to place a new member of the team on one of the infrastructure pieces that
is doing well, and should be a model for other pieces, as to give them
a good starting place for learning the system. A more senior team member
may be more effective on pieces of the infrastructure that are struggling.

## Software Analogy

In order to develop a repertoire for debugging data, we'll lean
heavily on debugging techniques borrowed from software development.
In particular, we'll take advantage of immutable data, a
technique popular in functional programming that allows us to
model change, while still preserving a view toward the past.

### A Brief Functional Programming Tangent

In imperative languages like C, Java and Python, data tends to be mutable.
For example, if we want to sort a list, we might call
`myList.sort()`. This will sort the list in-place. Consequently, all
references to `myList` will be changed. If we want to get a view
back to `myList` before it was sorted, we'd have to explicitly
make a copy. Functional languages like Haskell, Clojure and Erlang,
on the other hand, tend to treat
data as immutable. Our list sorting example becomes something closer
to `myNewSortedList = sort(myList)`. This retains the unsorted
list `myList`. One of the advantages of this is that many functions
become simply the result of processing the values passed in. This means that
given a stack trace, we can often reproduce bugs immediately. With mutable
data, there is no guarantee that the value of a particular variable
remains the same throughout the execution of the function. Because of this,
we can't necessarily rely on a stack trace to reproduce bugs. You'll see
that one of the ways we take advantage of immutability is by persisting
our data not only under it's normal identifier, but with a compound key of
identifier and time-stamp. This will aid us finding the exact inputs to
any of our data processing steps, should we need to go back and debug
them.

## An Example

Imagine we're building a news aggregation site.
The homepage will display the top
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
or a relational database row with these attributes.

From each of these home pages we crawl, we'll download the individual
linked stories. The stories will also be saved with URL, source
and timestamp attributes. Additionally, we'll store the composite
ID of the homepage where we were linked to this story. That way if,
for example, later we suspect we have a bug with the way
we assign story popularity based on home page placement, we can
go look at the home page as it was retrieved at a particular point
in time. Ideally we should be able to trace data from our
own homepage all the way back to the original HTML that
our crawler downloaded.

In order to help determine popularity, and to further feed
our news crawlers, we'll also be crawling social media
sites. Just like with the news crawlers, we'll want
to keep a timestamped record of the HTML and other assets
we crawl. Again, this will let us go back later and debug
our code, if for example we suspect we are incorrectly
counting links from shares of a particular article
(was our regular expression mistaken, or was there a bug
in our shortened-url -> full-url code?)

### Change

Keeping previous versions of the sites we crawl allows for some
interesting analytics. Historically, how many articles does the
Boston Globe usually link to on their home page? Is there a larger
variety of news articles in the summer? Another useful byproduct of this
is that we can run new analytics on past data. We're not confined to the
data since we turned the new analytics on.

### Clustering

Clustering data is a difficult problem, as outlying or mislabeled data
can completely change our clusters. For this reason, it is important to
be able to cheaply (in human and compute time) be able to experiment with
rerunning our clustering with altered inputs. The inputs we alter may
be removing data from a particular source, or adding a new topic modelling
stage between crawling and clustering. In order to achieve this, our
infrastructure must be loosely coupled enough that we can just as easily
provide inputs to our clustering system for testing as we do in production.

### Popularity

Calculating story popularity shares many of the same issues as clustering
stories. As we're experimenting, or debugging an issue, we want to quickly
be able to test our changes and see the result. We also want to be able to
see the most popular story on our own page and dive all the way back through
our own processing to the origin site we crawled. If we find out we've ranked
a story as more popular that we would've liked, we can trace it back to our
origin crawl to see if perhaps, we had put too much weight in it's position
on it's source site.

## Conclusion

Data processing code and infrastructure will need to be
debugged, just like normal code. With a bit of foresight, you can
dramatically improve your ability to reason about your system, and quickly
adapt it to do new things. Furthermore, we can draw from decades of experience
in software design to influence our data processing and infrastructure
decisions.
