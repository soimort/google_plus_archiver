# google_plus_archiver

[![Build Status](https://api.travis-ci.org/soimort/google_plus_archiver.png)](http://travis-ci.org/soimort/google_plus_archiver)
[![Dependencies Status](https://gemnasium.com/soimort/google_plus_archiver.png)](https://gemnasium.com/soimort/google_plus_archiver)

__google_plus_archiver__ is a simple command-line tool to archive Google+ profiles and public streams.

## Installation

    $ gem install google_plus_archiver

## Getting Started

You need to acquire your own Google API key [here](https://code.google.com/apis/console#access) (if you do not have one).

## Examples

Replace asterisks with your API key:

    $ gplus-get -a *************************************** -u 113075529629418110825

## Options

    $ gplus-get -a [API_KEY] -u [USER_ID]

        --api-key [API_KEY]          Specify the Google API key
        --user-id [USER_ID]          Specify the ID of the user to be archived
        --delay [SECONDS]            Delay (in seconds) between two requests (0.2 by default, since Google set a 5 requests/second/user limit)
        --output-path [OUTPUT_PATH]  Output path (the current directory by default)
        --quiet                      Silent mode
        --exclude-posts              Don't archive posts
        --exclude-attachments        Don't archive attachments
        --exclude-replies            Don't archive replies
        --exclude-plusoners          Don't archive plusoners
        --exclude-resharers          Don't archive resharers
        --version                    Display current version

## Licensing

__google_plus_archiver__ is released under the [MIT license](http://www.opensource.org/licenses/mit-license.php). See the `LICENSE` file for details.

_Last Revision: 2012-12-18, by [Mort Yao](http://www.soimort.org/)_
