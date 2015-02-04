Metaphor
========

Metaphor is a collection of Perl modules that supports the development and maintenance of a [resource-oriented architecture](http://en.wikipedia.org/wiki/Resource-oriented_architecture) (ROA) via [RESTful interfaces](http://en.wikipedia.org/wiki/Representational_state_transfer).

Initially inspired by [Andrew Sterling Hanenkamp](http://www.onlamp.com/pub/au/3067)'s 2008 article *[Developing RESTful Web Services in Perl](http://www.onlamp.com/pub/a/onlamp/2008/02/19/developing-restful-web-services-in-perl.html)*, Metaphor not only makes it simple to route incoming requests to specific blocks of code, it also provides patterns for encapsulating data access business logic in Perl modules, common configuration and logging functionality, and utilities for some of the most common things your web applications would want to do (working with the file system, connecting to databases, and even sending multimedia emails!).

## Pattern Overview ##

```
      RDBMS        |         Perl Modules and Services
+--------------+   |   +--------------+       +--------------+
|   Database   | <-|-> | Data Modules | <---> | Web Services |
+--------------+   |   +--------------+       +--------------+
                   |
```

## Intended Audience ##

While there is no [litmus test](http://en.wikipedia.org/wiki/Litmus_test_%28politics%29) for those who might find Metaphor useful, the [documentation and reference material](https://github.com/scottoffen/Metaphor/wiki) is geared toward those who meet a few qualifications.

- You should be familiar with the [Perl programming language](http://www.perl.org) at an intermediate level (or a beginner who is very adept at looking up things that they don't understand).<br>
<a href="http://xkcd.com/519/" target="_blank" title="I'm pretty sure I was between girlfriends at the time..."><img src="http://imgs.xkcd.com/comics/11th_grade.png"></a><br><br>

- You should be familiar enough with [MySQL](http://www.mysql.com) to authenticate to a schema, create a table and, minimally, use `select`, `insert`, `update` and `delete` statements.<br>
<a href="http://xkcd.com/327/" target="_blank" title="Experience with DROP not required, and we'll be handling the input sanitation for you."><img src="http://imgs.xkcd.com/comics/exploits_of_a_mom.png"></a><br><br>

- You should be familiar with the principles of [ROA](http://en.wikipedia.org/wiki/Resource-oriented_architecture) and making `REST` requests.<br>
<a href="http://xkcd.com/974/" target="_blank" title="Trust me, it's worth the wait!"><img src="http://imgs.xkcd.com/comics/the_general_problem.png"></a><br><br>

- You should be familiar with the [JSON](http://www.json.org/) data-interchange format.<br>
<a href="http://xkcd.com/927/" target="_blank" title="I said you need to be familiar, not an expert."><img src="http://imgs.xkcd.com/comics/standards.png"></a><br><br>

- Finally, some of the material provided addresses better integration with the [Apache HTTPD server](http://httpd.apache.org/). As this is completely optional, familiarity with it is not required for using Metaphor. But if you don't know Apache, these sections will be of little to no use to you.<br>
<a href="http://xkcd.com/278/" target="_blank" title="I said you need to be familiar, not an expert."><img src="http://imgs.xkcd.com/comics/black_hat_support.png"></a><br><br>

## License ##

Copyright 2011-2014 Scott Offen

Licensed under the Apache License, Version 2.0 (the "License"); you may not use these files except in compliance with the License. You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
