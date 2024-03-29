# NAME

HealthCheck::Diagnostic::WebRequest - Make HTTP/HTTPS requests to web servers to check connectivity

# VERSION

version v1.4.2

# SYNOPSIS

    # site:    https://foo.com
    # content: <html><head></head><body>This is my content</body></html>

    use HealthCheck::Diagnostic::WebRequest;

    # Look for a 200 status code and pass.
    my $diagnostic = HealthCheck::Diagnostic::WebRequest->new(
        url => 'https://foo.com',
    );
    my $result = $diagnostic->check;
    print $result->{status}; # OK

    # Look for a 401 status code and fail.
    $diagnostic = HealthCheck::Diagnostic::WebRequest->new(
        url         => 'https://foo.com',
        status_code => 401,
    );
    $result = $diagnostic->check;
    print $result->{status}; # CRITICAL

    # Look for any status code less than 500.
    $diagnostic = HealthCheck::Diagnostic::WebRequest->new(
        url         => 'https://foo.com',
        status_code => '<500',
    );
    $result = $diagnostic->check;
    print $result->{status}; # CRITICAL

    # Look for any 403, 405, or any 2xx range code
    $diagnostic = HealthCheck::Diagnostic::WebRequest->new(
        url         => 'https://foo.com',
        status_code => '403, 405, >=200, <300',
    );
    $result = $diagnostic->check;
    print $result->{status}; # CRITICAL

    # Look for a 200 status code and content matching the string regex.
    $diagnostic = HealthCheck::Diagnostic::WebRequest->new(
        url           => 'https://foo.com',
        content_regex => 'is my',
    );
    $result = $diagnostic->check;
    print $result->{status}; # OK

    # Use a regex as the content_regex.
    $diagnostic = HealthCheck::Diagnostic::WebRequest->new(
        url           => 'https://foo.com',
        content_regex => qr/is my/,
    );
    $result = $diagnostic->check;
    print $result->{status}; # OK

    # POST Method: Look for a 200 status code and content matching the string.
    my $data = {
        foo => 'tell me something',
    };

    my $encoded_data = encode_utf8(encode_json($data));
    my $header = [ 'Content-Type' => 'application/json; charset=UTF-8' ];
    my $url = 'https://dev.payment-express.net/dev/env_test';

    my $request = HTTP::Request->new('POST', $url, $header, $encoded_data);
    $diagnostic = HealthCheck::Diagnostic::WebRequest->new(
        request     => $request,
        status_code => 200,
        content_regex => "tell me something",
    );

    $result = $diagnostic->check;
    print $result->{status}; # OK

# DESCRIPTION

Determines if a web request to a `url` or `request` is achievable.
Also has the ability to check if the HTTP response contains the
right content, specified by `content_regex`. Sets the `status` to "OK"
or "CRITICAL" based on the success of the checks.

# ATTRIBUTES

## url

The site that is checked during the HealthCheck. It can be any HTTP/S link.
By default, it will send GET requests. Use ["request"](#request) if you want a more
complicated HTTP request.

Either this option or ["request"](#request) are required, and are mutually exclusive.

## request

Allows passing in [HTTP::Request](https://metacpan.org/pod/HTTP%3A%3ARequest) object in order to use other HTTP request
methods and form data during the HealthCheck.

Either this option or ["url"](#url) are required, and are mutually exclusive.

## status\_code

The expected HTTP response status code, or a string of status code conditions.

Conditions are comma-delimited, and can optionally have an operator prefix. Any
condition without a prefix goes into an `OR` set, while the prefixed ones go
into an `AND` set. As such, `==` is not allowed as a prefix, because it's less
confusing to not use a prefix here, and more than one condition while a `==`
condition exists would not make sense.

Some examples:

    !500              # Anything besides 500
    200, 202          # 200 or 202
    200, >=300, <400  # 200 or any 3xx code
    <400, 405, !202   # Any code below 400 except 202, or 405,
                      # ie: (<400 && !202) || 405

The default value for this is '200', which means that we expect a successful request.

## content\_regex

The content regex to test for in the HTTP response.
This is an optional field and is only checked if the status
code check passes.
This can either be a _string_ or a _regex_.

## no\_follow\_redirects

Setting this variable prevents the healthcheck from following redirects.

## options

See [LWP::UserAgent](https://metacpan.org/pod/LWP%3A%3AUserAgent) for available options. Takes a hash reference of key/value
pairs in order to configure things like ssl\_opts, timeout, etc.

It is optional.

By default provides a custom `agent` string and a default `timeout` of 7.

# DEPENDENCIES

[HealthCheck::Diagnostic](https://metacpan.org/pod/HealthCheck%3A%3ADiagnostic)
[LWP::UserAgent](https://metacpan.org/pod/LWP%3A%3AUserAgent)

# CONFIGURATION AND ENVIRONMENT

None

# AUTHOR

Grant Street Group <developers@grantstreet.com>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2018 - 2021 by Grant Street Group.

This is free software, licensed under:

    The Artistic License 2.0 (GPL Compatible)
