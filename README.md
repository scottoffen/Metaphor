Metaphor
========

Metaphor is a collection of Perl modules that supports the development and maintenance of a [resource-oriented architecture](http://en.wikipedia.org/wiki/Resource-oriented_architecture) (ROA) via [RESTful interfaces](http://en.wikipedia.org/wiki/Representational_state_transfer), initially inspired by - but extensively expanded upon - [Andrew Sterling Hanenkamp](http://www.onlamp.com/pub/au/3067)'s 2008 article *[Developing RESTful Web Services in Perl](http://www.onlamp.com/pub/a/onlamp/2008/02/19/developing-restful-web-services-in-perl.html)*.

Metaphor encourages the [separation of concerns](http://en.wikipedia.org/wiki/Separation_of_concerns) by providing:

- Patterns for encapsulating data access business logic in Perl modules
- Patterns for exposing resources (i.e. the data) externally via web services

## Sample Web Service ##

A simple web service using Metaphor follows the following pattern, assuming we have downloaded the included modules into the folders `/Metaphor` and `/Mail` at the path `/home/username/modules`.

**SampleService.pl**

```perl
#!/usr/bin/perl -T
use strict;
use warnings;
use CGI qw(:standard);
use CGI::Carp qw(fatalsToBrowser);


#----------------------------------------------------------------------------------#
# Initialization                                                                   #
# This allows us to access to the Metaphor and Mail modules.                       #
#----------------------------------------------------------------------------------#
BEGIN
{
	$| = 1;
	unshift(@INC, '/home/username/modules');
}
#----------------------------------------------------------------------------------#


#----------------------------------------------------------------------------------#
# External Dependencies                                                            #
#----------------------------------------------------------------------------------#
	use Metaphor::Logging;
	use Metaphor::Mailer; # Only if you want to send emails from your REST service
	use Metaphor::REST;

	Metaphor::Logging->StartLog();
#----------------------------------------------------------------------------------#


#########################################||#########################################
eval
{
	#----------------------------------------------------------------------------------#
	# A simple GET route                                                               #
	#----------------------------------------------------------------------------------#
	Route { REQUEST_METHOD => [ qr{^get$}i, qr{^head$}i ], PATH_INFO => qr{^/user/(\d+)$} } =>
	sub
	{
		my ($request, $content) = @_;

		SetContent({ 'result' => 'No users found' });
	};
	#----------------------------------------------------------------------------------#
}
#########################################||#########################################
```

### BEGIN ###

The begin block gives us access to the `Metaphor` and `Mail` modules - the latter of which is only needed if we are including `Metaphor::Mailer` to send emails or text messages.

If you have followed the patters described in the wiki to create additional modules for data access, I would recommend you place the folder for your namespace in the same parent folder as `Metaphor`, in which case the single addition to `@INC` gives you access to your custom modules as well. If you chose not to, you will need to add that path to [`@INC`](http://perldoc.perl.org/lib.html#Adding-directories-to-%40INC) here as well.

### External Dependencies ###

In most cases, you will only need to reference the Metaphor modules listed.  The other modules included in Metaphor are intended for use in your data access modules, and shouldn't be needed here.

### eval ###

By wrapping the rest of our code in an `eval` block, we can trap any and all errors thrown and return suitable REST responses for them. Included in this section is a set of `Route` calls. Each call will be evaluated in the order it is listed. The first matching call has it's code block executed. If an error is encountered (or intentionally thrown), it will be caught and a REST response will be returned that includes information about the error.

### Route ###

You should include a Route declaration for each type of request you want to respond to. `Route` takes two parameters. It is recommended to use the syntax notation in the example to pass these parameters. 

```perl
Route { REQUEST_METHOD => [ qr{^get$}i, qr{^head$}i ], PATH_INFO => qr{^/user/(\d+)$} } => sub {};
```

The **first parameter** is a [hashref](http://perldoc.perl.org/perlref.html) where each key is a key expected to be in [`%ENV`](http://perldoc.perl.org/Env.html). The value of each pair should be a regular expression (or an [arrayref](http://perldoc.perl.org/perlref.html) of expressions) that should match that environment variable value. Only the specified keys are matched, and it's only considered a match if every key specified has a regular expression that it matches.

>If you don't know what to expect in [`%ENV`](http://perldoc.perl.org/Env.html), use the Perl Environment section of my [Perl Development Resource](https://github.com/scottoffen/Perl-Development-Resource) script to help you explore these key/value pairs.
>
>It is important to note that routes will be attempted in the order they are included in the script, and regular expressions will be tested in the order they are listed in the array. The first matching route gets executed.

The **second parameter** is an anonymous code block that should be executed when a match is found. After the matching code block is executed, the script automatically exits, so you do not need to include anything to prevent further routes from being attempted.

When executed, two things get passed into the code block.

```perl
my ($request, $content) = @_;
```

The first value, `$request`, is a [hashref](http://perldoc.perl.org/perlref.html) whose keys match the keys of the first parameter sent into `Route`, and whose values contain whatever was matched. In our example above, has we sent a GET request to `SampleService.pl/users/1234` , the `$request` hash would look like this (expressed as [JSON](http://www.json.org/))

```javascript
{
	"REQUEST_METHOD" :  "GET",
	"PATH_INFO" : 1234
}
```

The second value, `$content`, contains a [hashref](http://perldoc.perl.org/perlref.html) of the data sent in the payload of the request. Using the `Content-type` HTTP header as a guide, it will attempt to parse out form data, JSON, XML and YAML into a perl-ready data structure.

### SetContent ###

After your script does it's thing, you will want to return *something* to the requesting agent. You can do this by calling `SetContent()`. Only one parameter is required, and that is the data to send in the response - usually in the form of a [hashref](http://perldoc.perl.org/perlref.html).

Optional second and third parameters will set the `Content-type` header - with JSON (`application/json`) being the default - and the `charset` option on the `Content-type` header.

## Data Access Module ##

See the (forthcoming) wiki for more information on how to use Metaphor to construct data access modules.

## License ##

Copyright 2011-2014 Scott Offen

Licensed under the Apache License, Version 2.0 (the "License"); you may not use these files except in compliance with the License. You may obtain a copy of the License at [apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
